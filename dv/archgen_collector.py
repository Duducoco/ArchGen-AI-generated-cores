#!/usr/bin/env python3
"""ArchGen dataset collector.

Usage:
    python dv/archgen_collector.py [--core {single,5pipe-stall,both}]
                                    [--modules MOD1 MOD2 ...]
                                    [--flist PATH]
                                    [--rtlil-dir PATH]
                                    [--asm-name PATTERN]
                                    [--coverage-report-rel PATH]
                                    [--output-dir PATH]
                                    [--only-passed]
                                    [--limit N]
                                    [--verbose]

Prerequisites:
    YOSYS_HOME=/path/to/oss-cad-suite  (required for RTLIL extraction)
"""

import argparse
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
DV_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = DV_ROOT.parent
EXTRACTOR_DIR = DV_ROOT / "coverage-report-extractor"

sys.path.insert(0, str(EXTRACTOR_DIR))

from collectors import DatasetCollector  # noqa: E402

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DEFAULT_MODULES: dict[str, list[str]] = {
    "single": [
        "ALU", "Controller", "Decoder", "ImmGen", "RegFile",
        "NextPC_Decision_Unit", "JALR_Adjust", "DataMem_interface_Unit",
        "Mux_NextPC", "Mux_ALUSrc1", "Mux_ALUSrc2", "Mux_RegWriteData",
    ],
    "5pipe-stall": [
        "ALU", "Controller", "Decoder", "ImmGen", "RegFile",
        "NextPC_Decision_Unit", "JALR_Adjust", "DataMem_interface_Unit",
        "Mux_NextPC", "Mux_ALUSrc1", "Mux_ALUSrc2", "Mux_RegWriteData",
        "Hazard_Control_Unit", "IF_ID_Reg", "ID_EX_Reg", "EX_Mem_Reg", "Mem_WB_Reg",
    ],
}

_DEFAULT_FLISTS: dict[str, Path] = {
    "single": DV_ROOT / "single" / "files.f",
    "5pipe-stall": DV_ROOT / "5pipe-stall" / "files.f",
}

DEFAULT_COVERAGE_REPORT_REL = Path("coverage") / "report"
DEFAULT_ASM_NAME = "{test_name}.S"


# ---------------------------------------------------------------------------
# ArchGen-specific collector
# ---------------------------------------------------------------------------

class ArchGenDatasetCollector(DatasetCollector):
    """DatasetCollector specialised for the ArchGen VCS verification flow."""

    def __init__(self, asm_name: str = DEFAULT_ASM_NAME) -> None:
        super().__init__(
            project_root=PROJECT_ROOT,
            flist_root=PROJECT_ROOT,
            excluded_files=frozenset({"tb_top.sv"}),
        )
        self.asm_name = asm_name

    def resolve_asm_file(self, test_dir: Path) -> Path | None:
        name = self.asm_name.format(test_name=test_dir.name)
        p = test_dir / name
        return p if p.exists() else None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Collect training dataset from ArchGen DV coverage artifacts.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Example:\n"
               "  YOSYS_HOME=/opt/oss-cad-suite \\\n"
               "  python dv/archgen_collector.py --core single --limit 1 --verbose",
    )
    parser.add_argument(
        "--core", choices=["single", "5pipe-stall", "both"], default="both",
        help="Which core(s) to process (default: both)",
    )
    parser.add_argument(
        "--modules", nargs="+", metavar="MODULE",
        help="Override module list (applies to all selected cores)",
    )
    parser.add_argument(
        "--flist", type=Path, default=None, metavar="PATH",
        help="Override files.f path. Only valid with --core single or --core 5pipe-stall.",
    )
    parser.add_argument(
        "--test-dir", type=Path, default=None, metavar="PATH",
        help=(
            "Root directory containing test subdirectories to scan. "
            "Overrides the default dv/out/<core>/ path. "
            "Only valid with --core single or --core 5pipe-stall."
        ),
    )
    parser.add_argument(
        "--asm-name", default=DEFAULT_ASM_NAME, metavar="PATTERN",
        help=(
            "Assembly filename pattern inside each test dir. "
            "Use {test_name} for the directory name, or a literal filename. "
            f"Default: '{DEFAULT_ASM_NAME}'"
        ),
    )
    parser.add_argument(
        "--coverage-report-rel", type=Path, default=DEFAULT_COVERAGE_REPORT_REL, metavar="PATH",
        help=(
            "Relative path from test dir to coverage HTML report directory. "
            f"Default: '{DEFAULT_COVERAGE_REPORT_REL}'"
        ),
    )
    parser.add_argument(
        "--output-dir", type=Path, default=DV_ROOT / "out" / "dataset",
        help="Output directory for RTLIL JSONs and manifest (default: dv/out/dataset/)",
    )
    parser.add_argument(
        "--limit", type=int, default=None,
        help="Max test dirs to process per core",
    )
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    cores = ["single", "5pipe-stall"] if args.core == "both" else [args.core]

    if args.flist and args.core == "both":
        parser.error("--flist cannot be used with --core both; run once per core instead.")
    if args.test_dir and args.core == "both":
        parser.error("--test-dir cannot be used with --core both; run once per core instead.")

    output_dir = args.output_dir.resolve()
    collector = ArchGenDatasetCollector(asm_name=args.asm_name)

    for core in cores:
        flist = args.flist.resolve() if args.flist else _DEFAULT_FLISTS[core]
        test_root = args.test_dir.resolve() if args.test_dir else DV_ROOT / "out" / core

        collector.collect(
            module_names=args.modules if args.modules else DEFAULT_MODULES[core],
            flist=flist,
            test_root=test_root,
            coverage_report_rel=args.coverage_report_rel,
            output_dir=output_dir,
            dataset_name=core,
            limit=args.limit,
            verbose=args.verbose,
        )


if __name__ == "__main__":
    main()
