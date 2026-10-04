`timescale 1ns / 1ps

// ============================================================================
// SoC RISC-V Completo Sintetizavel para FPGA (Artix-7 / Spartan / Cyclone / Gowin)
// Integra:
//   - Processador RISC-V RV32I / RV64 Pipelined 5 Estagios
//   - Memoria RAM Dual-Port de 32 KB (BRAM on-chip)
//   - Controlador Serial UART 8N1 (115200 baud)
//   - Temporizador de Sistema CLINT de 64 bits (mtime / mtimecmp)
//   - Controlador GPIO de 32 bits (LEDs, Botoes, Chaves)
//   - Controlador de Video VGA 640x480 @ 60Hz com Framebuffer
//   - Barramento Interconnect com Decodificacao de Enderecos
// ============================================================================
module soc_top #(
    parameter DATA_WIDTH = 32,
    parameter RAM_ADDR_W = 15,
    parameter INIT_FILE  = "firmware.hex"
)(
    input  wire        clk,          // Clock do sistema (50 MHz padrao FPGA)
    input  wire        rst_n,        // Reset ativo em nivel baixo
    
    // Interface Serial UART
    input  wire        uart_rx,
    output wire        uart_tx,
    
    // Interface GPIO (Pinos Fisicos da Placa FPGA)
    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out,
    
    // Interface de Video VGA
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);

    // ========================================================================
    // SINAIS INTERNOS DE CONEXAO DO SOC
    // ========================================================================
    
    // Barramento de Instrucoes (IF Core -> RAM Porta A)
    wire [DATA_WIDTH-1:0] imem_addr;
    wire [31:0]           imem_rdata;
    wire                  imem_req;

    // Barramento de Dados (MEM Core -> Interconnect)
    wire [DATA_WIDTH-1:0] dmem_addr;
    wire [DATA_WIDTH-1:0] dmem_wdata;
    wire [DATA_WIDTH-1:0] dmem_rdata;
    wire                  dmem_read;
    wire                  dmem_write;
    wire [3:0]              dmem_wstrb;

    // Interrupcao de Timer (CLINT -> Core)
    wire                  timer_irq;

    // RAM Porta B (Interconnect -> RAM)
    wire [14:0]           ram_addr;
    wire [31:0]           ram_wdata;
    wire [31:0]           ram_rdata;
    wire                  ram_we;
    wire [3:0]            ram_wstrb;

    // UART (Interconnect -> UART)
    wire [3:0]            uart_addr;
    wire [31:0]           uart_wdata;
    wire [31:0]           uart_rdata;
    wire                  uart_we;
    wire                  uart_re;

    // CLINT (Interconnect -> CLINT)
    wire [3:0]            clint_addr;
    wire [31:0]           clint_wdata;
    wire [31:0]           clint_rdata;
    wire                  clint_we;

    // GPIO (Interconnect -> GPIO)
    wire [3:0]            gpio_addr;
    wire [31:0]           gpio_wdata;
    wire [31:0]           gpio_rdata;
    wire                  gpio_we;

    // VGA (Interconnect -> VGA)
    wire [13:0]           vga_addr;
    wire [31:0]           vga_wdata;
    wire [31:0]           vga_rdata;
    wire                  vga_we;

    // ------------------------------------------------------------------------
    // 1. INSTANCIACAO DO NUCLEO RISC-V
    // ------------------------------------------------------------------------
    riscv_core #(
        .DATA_WIDTH (DATA_WIDTH),
        .RESET_PC   (32'h00000000)
    ) u_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .imem_req   (imem_req),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_read  (dmem_read),
        .dmem_write (dmem_write),
        .dmem_wstrb (dmem_wstrb),
        .timer_irq  (timer_irq)
    );

    // ------------------------------------------------------------------------
    // 2. INSTANCIACAO DA MEMORIA RAM DUAL-PORT
    // ------------------------------------------------------------------------
    ram_controller #(
        .ADDR_WIDTH (RAM_ADDR_W),
        .DATA_WIDTH (DATA_WIDTH),
        .INIT_FILE  (INIT_FILE)
    ) u_ram (
        .clk     (clk),
        .i_addr  (imem_addr[16:2]),
        .i_rdata (imem_rdata),
        .d_addr  (ram_addr),
        .d_wdata (ram_wdata),
        .d_rdata (ram_rdata),
        .d_we    (ram_we),
        .d_wstrb (ram_wstrb)
    );

    // ------------------------------------------------------------------------
    // 3. INSTANCIACAO DO INTERCONECTOR DE BARRAMENTO
    // ------------------------------------------------------------------------
    bus_interconnect u_bus (
        .cpu_addr   (dmem_addr),
        .cpu_wdata  (dmem_wdata),
        .cpu_rdata  (dmem_rdata),
        .cpu_read   (dmem_read),
        .cpu_write  (dmem_write),
        .cpu_wstrb  (dmem_wstrb),
        .ram_addr   (ram_addr),
        .ram_wdata  (ram_wdata),
        .ram_rdata  (ram_rdata),
        .ram_we     (ram_we),
        .ram_wstrb  (ram_wstrb),
        .uart_addr  (uart_addr),
        .uart_wdata (uart_wdata),
        .uart_rdata (uart_rdata),
        .uart_we    (uart_we),
        .uart_re    (uart_re),
        .clint_addr (clint_addr),
        .clint_wdata(clint_wdata),
        .clint_rdata(clint_rdata),
        .clint_we   (clint_we),
        .gpio_addr  (gpio_addr),
        .gpio_wdata (gpio_wdata),
        .gpio_rdata (gpio_rdata),
        .gpio_we    (gpio_we),
        .vga_addr   (vga_addr),
        .vga_wdata  (vga_wdata),
        .vga_rdata  (vga_rdata),
        .vga_we     (vga_we)
    );

    // ------------------------------------------------------------------------
    // 4. INSTANCIACAO DA SERIAL UART
    // ------------------------------------------------------------------------
    uart #(
        .DEFAULT_BAUD_DIV (434) // 50 MHz / 115200 = ~434
    ) u_uart (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (uart_addr),
        .wdata (uart_wdata),
        .rdata (uart_rdata),
        .we    (uart_we),
        .re    (uart_re),
        .rx    (uart_rx),
        .tx    (uart_tx)
    );

    // ------------------------------------------------------------------------
    // 5. INSTANCIACAO DO TEMPORIZADOR CLINT
    // ------------------------------------------------------------------------
    clint_timer u_clint (
        .clk       (clk),
        .rst_n     (rst_n),
        .addr      (clint_addr),
        .wdata     (clint_wdata),
        .rdata     (clint_rdata),
        .we        (clint_we),
        .timer_irq (timer_irq)
    );

    // ------------------------------------------------------------------------
    // 6. INSTANCIACAO DO CONTROLADOR GPIO
    // ------------------------------------------------------------------------
    gpio u_gpio (
        .clk           (clk),
        .rst_n         (rst_n),
        .addr          (gpio_addr),
        .wdata         (gpio_wdata),
        .rdata         (gpio_rdata),
        .we            (gpio_we),
        .gpio_pins_in  (gpio_in),
        .gpio_pins_out (gpio_out)
    );

    // ------------------------------------------------------------------------
    // 7. INSTANCIACAO DO CONTROLADOR DE VIDEO VGA
    // ------------------------------------------------------------------------
    vga_controller u_vga (
        .clk_50mhz (clk),
        .rst_n     (rst_n),
        .fb_addr   (vga_addr),
        .fb_wdata  (vga_wdata),
        .fb_rdata  (vga_rdata),
        .fb_we     (vga_we),
        .vga_hsync (vga_hsync),
        .vga_vsync (vga_vsync),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b)
    );

endmodule
