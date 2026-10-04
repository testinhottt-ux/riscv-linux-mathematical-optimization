`timescale 1ns / 1ps

// ============================================================================
// Top-Level FPGA para Placas Xilinx Artix-7 / Basys 3 / Nexys 4 / UltraScale
// Realiza divisao e distribuicao de clock, sincronizacao de reset com debounce
// e conexao com periféricos da placa fisica (LEDs, Chaves, UART, Conector VGA)
// ============================================================================
module fpga_top (
    input  wire        clk_100mhz,   // Oscilador de 100 MHz nativo da placa
    input  wire        btn_reset_n,  // Botao de reset (ativo baixo)
    
    // UART USB
    input  wire        uart_rxd_out, // RX vindo do chip USB-UART
    output wire        uart_txd_in,  // TX indo para o chip USB-UART
    
    // LEDs e Chaves DIP
    input  wire [15:0] sw,           // 16 Chaves DIP
    output wire [15:0] led,          // 16 LEDs indicadores
    
    // Porta de Video VGA
    output wire        vga_hs,
    output wire        vga_vs,
    output wire [3:0]  vga_red,
    output wire [3:0]  vga_green,
    output wire [3:0]  vga_blue
);

    // Divisor de Clock de 100 MHz para 50 MHz
    reg clk_50mhz;
    always @(posedge clk_100mhz) begin
        clk_50mhz <= ~clk_50mhz;
    end

    // Sincronizador de Reset com debounce simples
    reg [3:0] rst_sync;
    always @(posedge clk_50mhz or negedge btn_reset_n) begin
        if (!btn_reset_n) rst_sync <= 4'b0000;
        else rst_sync <= {rst_sync[2:0], 1'b1};
    end
    wire sys_rst_n = rst_sync[3];

    // Conexao GPIO
    wire [31:0] gpio_out_full;
    assign led = gpio_out_full[15:0];
    wire [31:0] gpio_in_full = {16'd0, sw};

    // Instancia do SoC RISC-V
    soc_top #(
        .DATA_WIDTH (32),
        .RAM_ADDR_W (15)
    ) u_soc (
        .clk       (clk_50mhz),
        .rst_n     (sys_rst_n),
        .uart_rx   (uart_rxd_out),
        .uart_tx   (uart_txd_in),
        .gpio_in   (gpio_in_full),
        .gpio_out  (gpio_out_full),
        .vga_hsync (vga_hs),
        .vga_vsync (vga_vs),
        .vga_r     (vga_red),
        .vga_g     (vga_green),
        .vga_b     (vga_blue)
    );

endmodule
