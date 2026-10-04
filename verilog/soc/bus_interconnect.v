`timescale 1ns / 1ps

// ============================================================================
// Interconector de Barramento de Memoria (Bus Crossbar & Address Decoder)
// Roteia requisicoes de leitura e escrita do processador RISC-V para a RAM
// interna e perifericos mapeados em memoria (Memory-Mapped I/O)
//
// Mapa de Memoria:
//   0x00000000 - 0x00007FFF : Memoria RAM Principal (32 KB BRAM)
//   0x10000000 - 0x100000FF : Serial UART (Console)
//   0x11000000 - 0x110000FF : Temporizador CLINT (mtime / mtimecmp)
//   0x12000000 - 0x120000FF : GPIO (LEDs / Chaves)
//   0x13000000 - 0x1300FFFF : Framebuffer de Video VGA
// ============================================================================
module bus_interconnect (
    // Conexao com a CPU (Master)
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    output reg  [31:0] cpu_rdata,
    input  wire        cpu_read,
    input  wire        cpu_write,
    input  wire [3:0]  cpu_wstrb,
    
    // Conexao com a Memoria RAM (Slave 0)
    output wire [14:0] ram_addr,
    output wire [31:0] ram_wdata,
    input  wire [31:0] ram_rdata,
    output wire        ram_we,
    output wire [3:0]  ram_wstrb,
    
    // Conexao com a UART (Slave 1)
    output wire [3:0]  uart_addr,
    output wire [31:0] uart_wdata,
    input  wire [31:0] uart_rdata,
    output wire        uart_we,
    output wire        uart_re,
    
    // Conexao com o Temporizador CLINT (Slave 2)
    output wire [3:0]  clint_addr,
    output wire [31:0] clint_wdata,
    input  wire [31:0] clint_rdata,
    output wire        clint_we,
    
    // Conexao com o GPIO (Slave 3)
    output wire [3:0]  gpio_addr,
    output wire [31:0] gpio_wdata,
    input  wire [31:0] gpio_rdata,
    output wire        gpio_we,
    
    // Conexao com o Controlador VGA (Slave 4)
    output wire [13:0] vga_addr,
    output wire [31:0] vga_wdata,
    input  wire [31:0] vga_rdata,
    output wire        vga_we
);

    // Decodificacao de Enderecos
    wire sel_ram   = (cpu_addr >= 32'h00000000) && (cpu_addr < 32'h00008000);
    wire sel_uart  = (cpu_addr >= 32'h10000000) && (cpu_addr < 32'h10000100);
    wire sel_clint = (cpu_addr >= 32'h11000000) && (cpu_addr < 32'h11000100);
    wire sel_gpio  = (cpu_addr >= 32'h12000000) && (cpu_addr < 32'h12000100);
    wire sel_vga   = (cpu_addr >= 32'h13000000) && (cpu_addr < 32'h13010000);

    // Roteamento para a RAM
    assign ram_addr  = cpu_addr[16:2]; // Alinhamento por palavra de 32 bits
    assign ram_wdata = cpu_wdata;
    assign ram_we    = sel_ram && cpu_write;
    assign ram_wstrb = cpu_wstrb;

    // Roteamento para a UART
    assign uart_addr  = cpu_addr[3:0];
    assign uart_wdata = cpu_wdata;
    assign uart_we    = sel_uart && cpu_write;
    assign uart_re    = sel_uart && cpu_read;

    // Roteamento para o CLINT
    assign clint_addr  = cpu_addr[3:0];
    assign clint_wdata = cpu_wdata;
    assign clint_we    = sel_clint && cpu_write;

    // Roteamento para o GPIO
    assign gpio_addr  = cpu_addr[3:0];
    assign gpio_wdata = cpu_wdata;
    assign gpio_we    = sel_gpio && cpu_write;

    // Roteamento para o VGA
    assign vga_addr  = cpu_addr[15:2];
    assign vga_wdata = cpu_wdata;
    assign vga_we    = sel_vga && cpu_write;

    // Multiplexador de Leitura de Dados para a CPU
    always @(*) begin
        if (sel_ram)        cpu_rdata = ram_rdata;
        else if (sel_uart)  cpu_rdata = uart_rdata;
        else if (sel_clint) cpu_rdata = clint_rdata;
        else if (sel_gpio)  cpu_rdata = gpio_rdata;
        else if (sel_vga)   cpu_rdata = vga_rdata;
        else                cpu_rdata = 32'h00000000;
    end

endmodule
