/* Linker script for ArchGen RV32I cores
 * TEXT_BEGIN = DATA_BEGIN = 0x00400000
 * Harvard architecture: InstMem uses PC[15:2], DataMem uses addr[16:2]
 */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    /* 128KB region starting at 0x00400000 (to fit text + data + tohost) */
    RAM (rwx) : ORIGIN = 0x00400000, LENGTH = 0x20000
}

SECTIONS
{
    . = 0x00400000;

    .text : {
        *(.text.init)
        *(.text)
        *(.text.*)
    } > RAM

    . = ALIGN(4);

    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > RAM

    . = ALIGN(4);

    .bss : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        __bss_end = .;
    } > RAM

    . = ALIGN(4);

    /* tohost/fromhost for Spike test termination */
    .tohost ALIGN(0x1000) : {
        PROVIDE(tohost = .);
        *(.tohost)
        . += 0x40;
        PROVIDE(fromhost = .);
        *(.fromhost)
        . += 0x40;
    } > RAM

    _end = .;
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
