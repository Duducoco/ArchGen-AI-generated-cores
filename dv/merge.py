#!/usr/bin/env python3
"""Merge selected pairs of VCS coverage databases under dv/out/single."""

from __future__ import annotations

import argparse
import hashlib
import os
import shlex
import shutil
import subprocess
import sys
from concurrent.futures import FIRST_COMPLETED, ProcessPoolExecutor, wait
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


DEFAULT_SAME_GROUP_COUNT = 1
DEFAULT_OTHER_GROUP_COUNT = 2
DEFAULT_JOBS = min(10, os.cpu_count() or 1)
SEED_SUFFIX = "_seed"


@dataclass(frozen=True)
class TestRun:
    name: str
    group: str
    run_dir: Path
    cov_vdb: Path


def non_negative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("value must be >= 0")
    return parsed


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be > 0")
    return parsed


def group_from_run_name(run_name: str) -> str:
    prefix, sep, seed = run_name.rpartition(SEED_SUFFIX)
    if sep and prefix and seed.isdigit():
        return prefix
    return run_name


def discover_runs(runs_dir: Path, cov_db_name: str) -> Tuple[List[TestRun], int]:
    runs = []
    missing_cov = 0

    for run_dir in sorted(p for p in runs_dir.iterdir() if p.is_dir()):
        cov_vdb = run_dir / "coverage" / cov_db_name
        if not cov_vdb.is_dir():
            missing_cov += 1
            continue

        runs.append(
            TestRun(
                name=run_dir.name,
                group=group_from_run_name(run_dir.name),
                run_dir=run_dir,
                cov_vdb=cov_vdb,
            )
        )

    return runs, missing_cov


def group_runs(runs: Iterable[TestRun]) -> Dict[str, List[TestRun]]:
    groups: Dict[str, List[TestRun]] = {}
    for run in runs:
        groups.setdefault(run.group, []).append(run)

    for grouped_runs in groups.values():
        grouped_runs.sort(key=lambda run: run.name)
    return groups


def choose_window(
    candidates: Sequence[TestRun],
    count: int,
    start_idx: int,
    exclude_name: Optional[str] = None,
) -> List[TestRun]:
    if count <= 0 or not candidates:
        return []

    chosen = []
    candidate_count = len(candidates)
    for offset in range(candidate_count):
        candidate = candidates[(start_idx + offset) % candidate_count]
        if candidate.name == exclude_name:
            continue
        chosen.append(candidate)
        if len(chosen) == count:
            break
    return chosen


def stable_start_idx(parts: Sequence[str], candidate_count: int) -> int:
    digest = hashlib.sha256("\0".join(parts).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], byteorder="big") % candidate_count


def add_pair(
    pairs: Dict[Tuple[str, str], Tuple[TestRun, TestRun]],
    first: TestRun,
    second: TestRun,
) -> None:
    if first.name == second.name:
        return

    left, right = (first, second) if first.name < second.name else (second, first)
    pairs.setdefault((left.name, right.name), (left, right))


def generate_pairs(
    groups: Dict[str, List[TestRun]],
    same_group_count: int,
    other_group_count: int,
    selection_seed: str,
) -> List[Tuple[TestRun, TestRun]]:
    pairs: Dict[Tuple[str, str], Tuple[TestRun, TestRun]] = {}
    group_names = sorted(groups)

    for group_name in group_names:
        same_group_runs = groups[group_name]
        for run_idx, run in enumerate(same_group_runs):
            for same_group_run in choose_window(
                same_group_runs,
                same_group_count,
                run_idx + 1,
                exclude_name=run.name,
            ):
                add_pair(pairs, run, same_group_run)

            for other_group_name in group_names:
                if other_group_name == group_name:
                    continue

                other_group_runs = groups[other_group_name]
                start_idx = stable_start_idx(
                    [selection_seed, run.name, other_group_name],
                    len(other_group_runs),
                )
                for other_group_run in choose_window(
                    other_group_runs,
                    other_group_count,
                    start_idx,
                ):
                    add_pair(pairs, run, other_group_run)

    return [pairs[key] for key in sorted(pairs)]


def build_urg_cmd(
    urg_bin: str,
    input_cov_dirs: Sequence[Path],
    db_out: Path,
    report_out: Path,
    log_out: Path,
    report_format: str,
) -> List[str]:
    return [
        urg_bin,
        "-full64",
        "-format",
        report_format,
        "-dbname",
        str(db_out),
        "-report",
        str(report_out),
        "-log",
        str(log_out),
        "-dir",
    ] + [str(path) for path in input_cov_dirs]


def pair_output_dir(out_dir: Path, first: TestRun, second: TestRun) -> Path:
    return out_dir / f"{first.name}__{second.name}"


def merge_pair(
    args: argparse.Namespace,
    first: TestRun,
    second: TestRun,
    pair_idx: int,
    pair_count: int,
) -> bool:
    pair_dir = pair_output_dir(args.out_dir, first, second)
    coverage_dir = pair_dir / "coverage"
    db_out = pair_dir / "coverage.vdb"
    report_out = coverage_dir / "report"
    log_out = coverage_dir / "merge.log"
    stdout_log = coverage_dir / "merge.stdout.log"
    cmd = build_urg_cmd(
        args.urg_bin,
        [first.cov_vdb, second.cov_vdb],
        db_out,
        report_out,
        log_out,
        args.report_format,
    )

    prefix = f"[{pair_idx}/{pair_count}] {first.name} + {second.name}"
    if args.dry_run:
        print(prefix)
        print(f"  db:     {db_out}")
        print(f"  report: {report_out}")
        if args.verbose:
            print(f"  cmd:    {shlex.join(cmd)}")
        return True

    if db_out.exists() and not args.force:
        print(f"{prefix} -> skip, {db_out} already exists")
        return True

    if args.force and pair_dir.exists():
        shutil.rmtree(pair_dir)

    coverage_dir.mkdir(parents=True, exist_ok=True)
    print(f"{prefix} -> merge")
    try:
        with stdout_log.open("wb") as stdout_fd:
            result = subprocess.run(
                cmd,
                stdout=stdout_fd,
                stderr=subprocess.STDOUT,
                check=False,
            )
    except FileNotFoundError:
        print(f"ERROR: unable to execute {args.urg_bin!r}; is urg in PATH?")
        return False

    if result.returncode != 0:
        print(f"ERROR: urg failed for {first.name} + {second.name}")
        print(f"       stdout/stderr: {stdout_log}")
        print(f"       urg log:       {log_out}")
        return False

    print(f"  db:     {db_out}")
    print(f"  report: {report_out}")
    return True


def merge_pair_task(
    task: Tuple[argparse.Namespace, TestRun, TestRun, int, int],
) -> bool:
    args, first, second, pair_idx, pair_count = task
    return merge_pair(args, first, second, pair_idx, pair_count)


def run_pairs_serial(
    args: argparse.Namespace,
    pairs: Sequence[Tuple[TestRun, TestRun]],
) -> List[Tuple[str, str]]:
    failed = []
    for idx, (first, second) in enumerate(pairs, start=1):
        ok = merge_pair(args, first, second, idx, len(pairs))
        if not ok:
            failed.append((first.name, second.name))
            if not args.keep_going:
                break
    return failed


def run_pairs_parallel(
    args: argparse.Namespace,
    pairs: Sequence[Tuple[TestRun, TestRun]],
) -> List[Tuple[str, str]]:
    pair_count = len(pairs)
    job_count = min(args.jobs, pair_count)
    print(f"Parallel jobs: {job_count}")

    failed = []
    next_pair_idx = 0

    def submit_next(executor: ProcessPoolExecutor, running: dict) -> bool:
        nonlocal next_pair_idx
        if next_pair_idx >= pair_count:
            return False
        first, second = pairs[next_pair_idx]
        pair_idx = next_pair_idx + 1
        task = (args, first, second, pair_idx, pair_count)
        future = executor.submit(merge_pair_task, task)
        running[future] = (first.name, second.name)
        next_pair_idx += 1
        return True

    with ProcessPoolExecutor(max_workers=job_count) as executor:
        running = {}
        for _ in range(job_count):
            submit_next(executor, running)

        while running:
            done, _ = wait(running, return_when=FIRST_COMPLETED)
            for future in done:
                pair_names = running.pop(future)
                try:
                    ok = future.result()
                except Exception as err:  # pragma: no cover
                    ok = False
                    print(
                        f"ERROR: worker failed for {pair_names[0]} + {pair_names[1]}: {err}",
                        file=sys.stderr,
                    )

                if not ok:
                    failed.append(pair_names)
                    if not args.keep_going:
                        for pending in running:
                            pending.cancel()
                        return failed

                submit_next(executor, running)

    return failed


def parse_args(argv: Optional[Sequence[str]]) -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent

    parser = argparse.ArgumentParser(
        description="Merge selected pairwise VCS coverage reports under dv/out/single.",
    )
    parser.add_argument(
        "--runs-dir",
        type=Path,
        default=script_dir / "out" / "single",
        help="Directory containing per-test outputs. Default: %(default)s",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=script_dir / "merge_out" / "single",
        help="Directory for merged pair outputs. Default: %(default)s",
    )
    parser.add_argument(
        "--cov-db-name",
        default="cov.vdb",
        help="Coverage database directory name under each test's coverage directory.",
    )
    parser.add_argument(
        "--same-group-count",
        type=non_negative_int,
        default=DEFAULT_SAME_GROUP_COUNT,
        help="Number of tests to select from the same group for each test.",
    )
    parser.add_argument(
        "--other-group-count",
        type=non_negative_int,
        default=DEFAULT_OTHER_GROUP_COUNT,
        help="Number of tests to select from each different group for each test.",
    )
    parser.add_argument(
        "--selection-seed",
        default="",
        help="Optional string to vary deterministic cross-group selections.",
    )
    parser.add_argument(
        "--urg-bin",
        default="urg",
        help="URG executable to run. Default: %(default)s",
    )
    parser.add_argument(
        "--report-format",
        default="both",
        choices=("both", "html", "text"),
        help="URG report format. Default: %(default)s",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Remove an existing pair output directory before rerunning it.",
    )
    parser.add_argument(
        "--keep-going",
        action="store_true",
        help="Continue with later pairs if one urg invocation fails.",
    )
    parser.add_argument(
        "--jobs",
        type=positive_int,
        default=DEFAULT_JOBS,
        help=(
            "Number of parallel urg merge processes to run. "
            "Use --jobs 1 for serial execution. Default: %(default)s"
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print selected pairs without running urg.",
    )
    parser.add_argument(
        "--limit-pairs",
        type=positive_int,
        help="Only process the first N generated pairs.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="With --dry-run, also print the full urg command for each pair.",
    )

    args = parser.parse_args(argv)
    args.runs_dir = args.runs_dir.resolve()
    args.out_dir = args.out_dir.resolve()
    return args


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)

    if not args.runs_dir.is_dir():
        print(f"ERROR: runs directory not found: {args.runs_dir}", file=sys.stderr)
        return 1

    runs, missing_cov = discover_runs(args.runs_dir, args.cov_db_name)
    groups = group_runs(runs)
    pairs = generate_pairs(
        groups,
        args.same_group_count,
        args.other_group_count,
        args.selection_seed,
    )
    if args.limit_pairs is not None:
        pairs = pairs[: args.limit_pairs]

    print(f"Runs: {len(runs)} with coverage/{args.cov_db_name}")
    print(f"Groups: {len(groups)}")
    if missing_cov:
        print(
            f"Skipped test directories without coverage/{args.cov_db_name}: "
            f"{missing_cov}"
        )
    print(f"Unique pairs: {len(pairs)}")

    if not pairs:
        return 0

    if args.dry_run or args.jobs == 1:
        failed = run_pairs_serial(args, pairs)
    else:
        failed = run_pairs_parallel(args, pairs)

    if failed:
        print(f"Failed pairs: {len(failed)}", file=sys.stderr)
        for first_name, second_name in failed:
            print(f"  {first_name}__{second_name}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
