#!/usr/bin/env python3
"""Convert RTL trace log to RISCV-DV compatible CSV format.

Input format (from testbench):
  pc=00400000 binary=00500093 gpr=x1:00000005
  pc=00400004 binary=00a00113

Output CSV format (RISCV-DV compatible):
  pc,instr,gpr,csr,binary,mode,instr_str,operand,pad
  00400000,,ra:00000005,,00500093,3,,,
  00400004,,,,00a00113,3,,,
"""

import argparse
import csv
import re
import sys

# x-register to ABI name mapping
REG_ABI_MAP = {
    'x0': 'zero', 'x1': 'ra', 'x2': 'sp', 'x3': 'gp',
    'x4': 'tp', 'x5': 't0', 'x6': 't1', 'x7': 't2',
    'x8': 's0', 'x9': 's1', 'x10': 'a0', 'x11': 'a1',
    'x12': 'a2', 'x13': 'a3', 'x14': 'a4', 'x15': 'a5',
    'x16': 'a6', 'x17': 'a7', 'x18': 's2', 'x19': 's3',
    'x20': 's4', 'x21': 's5', 'x22': 's6', 'x23': 's7',
    'x24': 's8', 'x25': 's9', 'x26': 's10', 'x27': 's11',
    'x28': 't3', 'x29': 't4', 'x30': 't5', 'x31': 't6',
}


def convert_gpr_to_abi(gpr_str):
    """Convert 'x1:00000005' to 'ra:00000005'."""
    if not gpr_str:
        return ''
    m = re.match(r'(x\d+):([0-9a-fA-F]+)', gpr_str)
    if m:
        xreg = m.group(1)
        val = m.group(2)
        abi_name = REG_ABI_MAP.get(xreg, xreg)
        return f'{abi_name}:{val}'
    return gpr_str


def parse_trace_line(line):
    """Parse a single trace log line."""
    line = line.strip()
    if not line or line.startswith('#'):
        return None

    pc_match = re.search(r'pc=([0-9a-fA-F]+)', line)
    bin_match = re.search(r'binary=([0-9a-fA-F]+)', line)
    gpr_match = re.search(r'gpr=(x\d+:[0-9a-fA-F]+)', line)

    if not pc_match or not bin_match:
        return None

    pc = pc_match.group(1)
    binary = bin_match.group(1)
    gpr = convert_gpr_to_abi(gpr_match.group(1)) if gpr_match else ''

    return (pc, binary, gpr)


def convert_trace(input_file, output_file):
    """Convert RTL trace log to RISCV-DV CSV format."""
    entries = []

    with open(input_file, 'r') as f:
        for line in f:
            result = parse_trace_line(line)
            if result is not None:
                entries.append(result)

    with open(output_file, 'w', newline='') as f:
        writer = csv.writer(f)
        # RISCV-DV CSV header (must match expected columns)
        writer.writerow(['pc', 'instr', 'gpr', 'csr', 'binary', 'mode',
                         'instr_str', 'operand', 'pad'])
        for pc, binary, gpr in entries:
            # instr: empty (no disassembly from RTL)
            # csr: empty (no CSR in these cores)
            # mode: 3 (machine mode)
            writer.writerow([pc, '', gpr, '', binary, '3', '', '', ''])

    print(f"[rtl_trace_to_csv] Converted {len(entries)} entries: "
          f"{input_file} -> {output_file}")
    return len(entries)


def main():
    parser = argparse.ArgumentParser(
        description='Convert RTL trace log to RISCV-DV CSV format')
    parser.add_argument('--input', '-i', required=True,
                        help='Input RTL trace log file')
    parser.add_argument('--output', '-o', required=True,
                        help='Output CSV file')
    args = parser.parse_args()

    count = convert_trace(args.input, args.output)
    if count == 0:
        print("[rtl_trace_to_csv] WARNING: No trace entries found!",
              file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
