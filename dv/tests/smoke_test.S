# Smoke test for ArchGen RV32I cores
# Tests basic ALU, load/store, and branch operations
# Expected to terminate via ECALL

    .section .text.init
    .globl _start

_start:
    # ---- Register initialization ----
    li   x1, 0            # x1 = 0
    li   x2, 0            # x2 = 0

    # ---- Arithmetic tests ----
    li   x1, 5            # x1 = 5
    li   x2, 10           # x2 = 10
    add  x3, x1, x2      # x3 = 15
    sub  x4, x2, x1      # x4 = 5
    and  x5, x1, x2      # x5 = 5 & 10 = 0
    or   x6, x1, x2      # x6 = 5 | 10 = 15
    xor  x7, x1, x2      # x7 = 5 ^ 10 = 15
    slt  x8, x1, x2      # x8 = 1 (5 < 10)
    sltu x9, x2, x1      # x9 = 0 (10 !< 5 unsigned)

    # ---- Immediate tests ----
    addi x10, x0, 100     # x10 = 100
    andi x11, x10, 0xF    # x11 = 4 (100 & 15)
    ori  x12, x0, 0xFF    # x12 = 255
    xori x13, x10, 0xFF   # x13 = 100 ^ 255 = 155
    slli x14, x1, 3       # x14 = 5 << 3 = 40
    srli x15, x10, 2      # x15 = 100 >> 2 = 25
    srai x16, x10, 2      # x16 = 100 >>> 2 = 25

    # ---- Upper immediate tests ----
    lui  x17, 0x12345     # x17 = 0x12345000
    auipc x18, 0          # x18 = current PC

    # ---- Load/Store tests ----
    # Use stack area for load/store (end of memory)
    la   x20, _test_data
    li   x21, 0xDEADBEEF
    sw   x21, 0(x20)      # Store word
    lw   x22, 0(x20)      # Load word -> x22 = 0xDEADBEEF
    sh   x21, 4(x20)      # Store halfword (0xBEEF)
    lhu  x23, 4(x20)      # Load halfword unsigned -> x23 = 0xBEEF
    sb   x21, 8(x20)      # Store byte (0xEF)
    lbu  x24, 8(x20)      # Load byte unsigned -> x24 = 0xEF
    lh   x25, 4(x20)      # Load halfword signed -> x25 = 0xFFFFBEEF
    lb   x26, 8(x20)      # Load byte signed -> x26 = 0xFFFFFFEF

    # ---- Branch tests ----
    li   x27, 42
    li   x28, 42
    beq  x27, x28, branch_eq_pass
    li   x29, 0xBAD       # Should not reach here
    j    branch_test_done
branch_eq_pass:
    li   x29, 0x600D      # x29 = 0x600D (branch taken)

branch_test_done:
    li   x27, 1
    li   x28, 2
    bne  x27, x28, branch_ne_pass
    li   x30, 0xBAD
    j    branch_ne_done
branch_ne_pass:
    li   x30, 0x600D      # x30 = 0x600D

branch_ne_done:
    blt  x27, x28, branch_lt_pass
    li   x31, 0xBAD
    j    test_jal
branch_lt_pass:
    li   x31, 0x600D      # x31 = 0x600D

    # ---- JAL/JALR tests ----
test_jal:
    jal  x1, jal_target   # x1 = PC+4, jump to jal_target
    j    test_done         # Should not reach here until after jal_target returns

jal_target:
    addi x2, x0, 0x7A1    # x2 = 0x7A1 (marker: we reached JAL target)
    jalr x0, x1, 0        # Return to caller (x1)

test_done:
    # ---- Test complete: write tohost=1 for Spike, then ECALL for RTL ----
    la   x1, tohost
    li   x2, 1
    sw   x2, 0(x1)           # Signal Spike to terminate
    ecall                     # Terminate RTL simulation
    # Spin loop if ECALL doesn't halt (shouldn't reach here in RTL)
1:  j    1b

    .section .data
    .align 4
_test_data:
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:
    .word 0
    .align 6
    .globl fromhost
fromhost:
    .word 0
