#!/usr/bin/env python3
"""Convert ELF to hex files for $readmemh loading.

Generates word-addressed hex files compatible with SystemVerilog $readmemh
for 32-bit wide memory arrays.

Usage:
    elf_to_hex.py --elf test.elf --text text.hex --data data.hex --base 0x00400000
"""

import argparse
import struct
import subprocess
import tempfile
import os
import sys


def elf_to_binary(elf_path, objcopy='riscv64-unknown-elf-objcopy'):
    """Extract raw binary from ELF using objcopy."""
    with tempfile.NamedTemporaryFile(suffix='.bin', delete=False) as tmp:
        tmp_path = tmp.name

    try:
        subprocess.run(
            [objcopy, '-O', 'binary', elf_path, tmp_path],
            check=True, capture_output=True, text=True
        )
        with open(tmp_path, 'rb') as f:
            return f.read()
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def get_entry_point(elf_path, objdump='riscv64-unknown-elf-objdump'):
    """Get the lowest load address from ELF headers."""
    result = subprocess.run(
        [objdump, '-h', elf_path],
        check=True, capture_output=True, text=True
    )
    min_vma = None
    for line in result.stdout.split('\n'):
        parts = line.split()
        if len(parts) >= 6 and parts[1] in ('.text', '.text.init', '.data'):
            vma = int(parts[3], 16)
            if min_vma is None or vma < min_vma:
                min_vma = vma
    return min_vma if min_vma is not None else 0


def binary_to_hex(data, base_addr, mem_base, output_path):
    """Convert binary data to $readmemh format.

    Each line is a 32-bit hex word. Words are addressed starting from
    (base_addr - mem_base) / 4 in the memory array.
    """
    start_index = (base_addr - mem_base) // 4

    with open(output_path, 'w') as f:
        # Write address marker if not starting at 0
        if start_index > 0:
            f.write(f'@{start_index:08x}\n')

        # Convert bytes to 32-bit words (little-endian)
        for i in range(0, len(data), 4):
            chunk = data[i:i+4]
            if len(chunk) < 4:
                chunk = chunk + b'\x00' * (4 - len(chunk))
            word = struct.unpack('<I', chunk)[0]
            f.write(f'{word:08x}\n')


def main():
    parser = argparse.ArgumentParser(
        description='Convert ELF to hex files for $readmemh')
    parser.add_argument('--elf', required=True, help='Input ELF file')
    parser.add_argument('--text', required=True, help='Output text hex file')
    parser.add_argument('--data', help='Output data hex file (copy of text)')
    parser.add_argument('--base', default='0x00400000',
                        help='Memory base address (default: 0x00400000)')
    parser.add_argument('--objcopy', default='riscv64-unknown-elf-objcopy',
                        help='Path to objcopy')
    parser.add_argument('--objdump', default='riscv64-unknown-elf-objdump',
                        help='Path to objdump')
    args = parser.parse_args()

    mem_base = int(args.base, 0)

    # Get load address
    load_addr = get_entry_point(args.elf, args.objdump)
    if load_addr is None:
        load_addr = mem_base

    # Extract binary
    binary_data = elf_to_binary(args.elf, args.objcopy)

    if len(binary_data) == 0:
        print(f"ERROR: No data extracted from {args.elf}", file=sys.stderr)
        sys.exit(1)

    # Generate hex
    binary_to_hex(binary_data, load_addr, mem_base, args.text)
    word_count = (len(binary_data) + 3) // 4
    print(f"[elf_to_hex] Generated {args.text}: {word_count} words "
          f"(base=0x{mem_base:08x}, load=0x{load_addr:08x})")

    # Copy to data hex if requested
    if args.data:
        import shutil
        shutil.copy2(args.text, args.data)
        print(f"[elf_to_hex] Copied to {args.data}")


if __name__ == '__main__':
    main()
