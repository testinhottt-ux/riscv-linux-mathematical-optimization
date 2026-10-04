`timescale 1ns / 1ps

// ============================================================================
// Controlador de Video VGA 640x480 @ 60Hz com Framebuffer On-Chip
// Gera sinais padrao de sincronismo horizontal (HSYNC), vertical (VSYNC) e
// saida de cor RGB para conexao direta a monitores VGA ou conversores HDMI
// Permite que o processador RISC-V desenhe graficos e jogos diretamente na tela!
// ============================================================================
module vga_controller (
    input  wire        clk_50mhz,    // Clock base do sistema (50 MHz)
    input  wire        rst_n,
    
    // Interface de Barramento com a CPU RISC-V (Memoria de Video)
    input  wire [13:0] fb_addr,      // Endereco do pixel/caractere no framebuffer
    input  wire [31:0] fb_wdata,
    output wire [31:0] fb_rdata,
    input  wire        fb_we,
    
    // Sinais Fisicos de Saida para o Conector VGA / HDMI da Placa FPGA
    output reg         vga_hsync,
    output reg         vga_vsync,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    // Divisor de Clock de 50 MHz para 25 MHz (Pixel Clock padrao VGA 640x480)
    reg clk_25mhz;
    always @(posedge clk_50mhz or negedge rst_n) begin
        if (!rst_n) clk_25mhz <= 1'b0;
        else clk_25mhz <= ~clk_25mhz;
    end

    // Parametros de Temporizacao VGA 640x480 @ 60Hz
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    reg [9:0] h_count;
    reg [9:0] v_count;

    // Contadores Horizontal e Vertical
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin
            if (h_count < H_TOTAL - 1) begin
                h_count <= h_count + 1'b1;
            end else begin
                h_count <= 10'd0;
                if (v_count < V_TOTAL - 1) begin
                    v_count <= v_count + 1'b1;
                end else begin
                    v_count <= 10'd0;
                end
            end
        end
    end

    // Geracao de Sinais de Sincronismo (Ativos em Nivel Baixo)
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            vga_hsync <= 1'b1;
            vga_vsync <= 1'b1;
        end else begin
            vga_hsync <= ~((h_count >= (H_VISIBLE + H_FRONT)) && (h_count < (H_VISIBLE + H_FRONT + H_SYNC)));
            vga_vsync <= ~((v_count >= (V_VISIBLE + V_FRONT)) && (v_count < (V_VISIBLE + V_FRONT + V_SYNC)));
        end
    end

    // Memoria Dual-Port do Framebuffer (Resolucao interna escalonada 160x120 pixels com 8 bits de cor)
    // 160 x 120 = 19200 bytes, cabendo perfeitamente em BRAMs de FPGA
    localparam FB_DEPTH = 4800; // 4800 palavras de 32 bits = 19200 bytes
    reg [7:0] vga_mem [0:19199];

    // Escrita pela CPU RISC-V
    always @(posedge clk_50mhz) begin
        if (fb_we && (fb_addr < 4800)) begin
            vga_mem[{fb_addr, 2'b00}] <= fb_wdata[7:0];
            vga_mem[{fb_addr, 2'b01}] <= fb_wdata[15:8];
            vga_mem[{fb_addr, 2'b10}] <= fb_wdata[23:16];
            vga_mem[{fb_addr, 2'b11}] <= fb_wdata[31:24];
        end
    end
    assign fb_rdata = 32'd0;

    // Leitura pelo Gerador de Video (Mapeamento de 640x480 para 160x120 com escala 4x4)
    wire video_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    wire [7:0] pixel_x = h_count[9:2]; // h_count / 4 (0 a 159)
    wire [6:0] pixel_y = v_count[8:2]; // v_count / 4 (0 a 119)
    wire [14:0] read_addr = (pixel_y * 160) + pixel_x;

    reg [7:0] current_pixel_color;
    always @(posedge clk_25mhz) begin
        if (read_addr < 19200) begin
            current_pixel_color <= vga_mem[read_addr];
        end else begin
            current_pixel_color <= 8'd0;
        end
    end

    // Conversao de Formato RGB 3-3-2 para RGB 4-4-4 nos Pinos Fisicos
    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end else if (video_on) begin
            vga_r <= {current_pixel_color[7:5], current_pixel_color[7]}; // Red (3 bits expandidos)
            vga_g <= {current_pixel_color[4:2], current_pixel_color[4]}; // Green (3 bits expandidos)
            vga_b <= {current_pixel_color[1:0], current_pixel_color[1:0]}; // Blue (2 bits expandidos)
        end else begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end
    end

endmodule
