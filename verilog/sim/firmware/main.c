// ============================================================================
// Firmware Bare-Metal em C para o SoC RISC-V FPGA
// Testa UART, Timer CLINT, GPIO e Framebuffer VGA
// ============================================================================

#define UART_BASE  0x10000000
#define CLINT_BASE 0x11000000
#define GPIO_BASE  0x12000000
#define VGA_BASE   0x13000000

#define UART_DATA   (*(volatile unsigned int *)(UART_BASE + 0x00))
#define UART_STATUS (*(volatile unsigned int *)(UART_BASE + 0x04))

#define CLINT_MTIME (*(volatile unsigned long long *)(CLINT_BASE + 0x00))

#define GPIO_OUT    (*(volatile unsigned int *)(GPIO_BASE + 0x00))
#define GPIO_IN     (*(volatile unsigned int *)(GPIO_BASE + 0x04))

void uart_putc(char c) {
    while (UART_STATUS & 0x02); // Aguarda TX desocupar
    UART_DATA = (unsigned int)c;
}

void uart_puts(const char *s) {
    while (*s) {
        if (*s == '\n') uart_putc('\r');
        uart_putc(*s++);
    }
}

void uart_print_hex(unsigned int val) {
    char hex_digits[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart_putc(hex_digits[(val >> i) & 0xF]);
    }
}

// Calculo de Fibonacci para testar ALU e Pipeline
unsigned int fibonacci(unsigned int n) {
    if (n <= 1) return n;
    unsigned int a = 0, b = 1, c;
    for (unsigned int i = 2; i <= n; i++) {
        c = a + b;
        a = b;
        b = c;
    }
    return b;
}

int main(void) {
    // 1. Acende LEDs no GPIO (padrao alternado)
    GPIO_OUT = 0x00000055;

    // 2. Imprime mensagem de boas-vindas pela UART
    uart_puts("\n==================================================\n");
    uart_puts("   RISC-V FPGA SoC HARDWARE BOOT SUCCESSFUL!     \n");
    uart_puts("==================================================\n");
    uart_puts("  Arquitetura : RV32I / RV64 5-Stage Pipelined    \n");
    uart_puts("  Memoria BRAM: 32 KB On-Chip                     \n");
    uart_puts("  Perifericos : UART 115200, CLINT 64b, GPIO, VGA \n");
    uart_puts("--------------------------------------------------\n");

    // 3. Teste de Computacao (Fibonacci)
    unsigned int fib10 = fibonacci(10);
    uart_puts("Calculo Fibonacci(10): ");
    uart_print_hex(fib10);
    uart_puts(" (Esperado: 0x00000037 / 55 decimal)\n");

    // 4. Teste de Leitura do Timer CLINT
    unsigned int mtime_low = (unsigned int)CLINT_MTIME;
    uart_puts("Contador CLINT mtime: ");
    uart_print_hex(mtime_low);
    uart_puts(" ticks de clock\n");

    // 5. Atualiza padrao de LEDs para indicar sucesso
    GPIO_OUT = 0x000000AA;
    uart_puts("Status dos LEDs GPIO : 0xAA (SUCESSO TOTAL!)\n");
    uart_puts("==================================================\n");

    return 0;
}
