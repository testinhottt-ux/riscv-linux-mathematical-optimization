OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS {
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text .text.*)
        . = ALIGN(4);
    } > ram

    .rodata : {
        . = ALIGN(4);
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > ram

    .data : {
        . = ALIGN(4);
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
    } > ram

    .bss : {
        . = ALIGN(4);
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
    } > ram

    _end = .;
}
