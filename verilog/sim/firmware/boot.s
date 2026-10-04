.section .text.init
.global _start

_start:
    # Desativa interrupcoes no inicio
    csrw mstatus, zero
    
    # Inicializa o ponteiro de pilha (Stack Pointer no topo dos 32 KB de RAM)
    lui sp, 0x8         # 0x00008000
    
    # Inicializa vetor de interrupcao (mtvec)
    la t0, trap_handler
    csrw mtvec, t0
    
    # Salta para a funcao main em C
    call main

    # Loop infinito ao terminar
_halt:
    wfi
    j _halt

.global trap_handler
.align 4
trap_handler:
    # Tratador de interrupcao e excecao basico
    mret
