// Core settings for ArchGen RV32I cores

// XLEN
parameter int XLEN = 32;

// SATP mode (no address translation)
parameter satp_mode_t SATP_MODE = BARE;

// Supported privileged mode
privileged_mode_t supported_privileged_mode[] = {MACHINE_MODE};

// Unsupported instructions
riscv_instr_name_t unsupported_instr[];

// ISA supported (RV32I only)
riscv_instr_group_t supported_isa[$] = {RV32I};

// Interrupt mode support
mtvec_mode_t supported_interrupt_mode[$] = {DIRECT};

// Interrupt vectors
int max_interrupt_vector_num = 16;

// Features
bit support_pmp = 0;
bit support_epmp = 0;
bit support_debug_mode = 0;
bit support_umode_trap = 0;
bit support_sfence = 0;
bit support_unaligned_load_store = 0;

// GPR setting
parameter int NUM_FLOAT_GPR = 32;
parameter int NUM_GPR = 32;
parameter int NUM_VEC_GPR = 32;

// Vector extension
parameter int VECTOR_EXTENSION_ENABLE = 0;
parameter int VLEN = 512;
parameter int ELEN = 32;
parameter int SELEN = 8;
parameter int VELEN = int'($ln(ELEN)/$ln(2)) - 3;
parameter int MAX_LMUL = 8;

// Multi-harts
parameter int NUM_HARTS = 1;

// Implemented CSRs (minimal set, no actual CSR in core)
const privileged_reg_t implemented_csr[] = {
    MHARTID
};

// Custom CSRs
bit [11:0] custom_csr[] = {};

// Implemented interrupts
const interrupt_cause_t implemented_interrupt[] = {
    M_SOFTWARE_INTR,
    M_TIMER_INTR,
    M_EXTERNAL_INTR
};

// Implemented exceptions
const exception_cause_t implemented_exception[] = {
    INSTRUCTION_ACCESS_FAULT,
    ILLEGAL_INSTRUCTION,
    BREAKPOINT,
    LOAD_ADDRESS_MISALIGNED,
    LOAD_ACCESS_FAULT,
    STORE_AMO_ADDRESS_MISALIGNED,
    STORE_AMO_ACCESS_FAULT,
    ECALL_MMODE
};
