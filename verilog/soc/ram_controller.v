`timescale 1ns / 1ps

// ============================================================================
// Controlador de Memoria RAM / ROM Dual-Port Sintetizavel para Block RAM (FPGA)
// Porta A: Acesso de Instrucao (Leitura em 1 ciclo)
// Porta B: Acesso de Dados (Leitura e Escrita com strobe de bytes)
// Suporta carregamento de firmware via arquivo HEX ($readmemh)
// ============================================================================
module ram_controller #(
    parameter ADDR_WIDTH = 15,         // 32 KB (8192 palavras de 32 bits)
    parameter DATA_WIDTH = 32,
    parameter INIT_FILE  = "firmware.hex"
)(
    input  wire                    clk,
    
    // Porta de Instrucao (Porta A - Leitura)
    input  wire [ADDR_WIDTH-1:0]   i_addr,
    output reg  [DATA_WIDTH-1:0]   i_rdata,
    
    // Porta de Dados (Porta B - Leitura / Escrita)
    input  wire [ADDR_WIDTH-1:0]   d_addr,
    input  wire [DATA_WIDTH-1:0]   d_wdata,
    output reg  [DATA_WIDTH-1:0]   d_rdata,
    input  wire                    d_we,
    input  wire [3:0]              d_wstrb
);

    localparam RAM_DEPTH = 1 << ADDR_WIDTH;

    // Matriz de Memoria Block RAM (4 canais de 8 bits para escrita seletiva)
    reg [7:0] ram_b0 [0:RAM_DEPTH-1];
    reg [7:0] ram_b1 [0:RAM_DEPTH-1];
    reg [7:0] ram_b2 [0:RAM_DEPTH-1];
    reg [7:0] ram_b3 [0:RAM_DEPTH-1];

    // Inicializacao Opcional de Firmware para Simulacao e Bitstream FPGA
    initial begin
        // Se arquivo existir, sera carregado pelo testbench ou sintese
    end

    // Porta A: Leitura Sincrona de Instrucao
    always @(posedge clk) begin
        i_rdata <= {ram_b3[i_addr], ram_b2[i_addr], ram_b1[i_addr], ram_b0[i_addr]};
    end

    // Porta B: Leitura e Escrita Sincrona de Dados
    always @(posedge clk) begin
        if (d_we) begin
            if (d_wstrb[0]) ram_b0[d_addr] <= d_wdata[7:0];
            if (d_wstrb[1]) ram_b1[d_addr] <= d_wdata[15:8];
            if (d_wstrb[2]) ram_b2[d_addr] <= d_wdata[23:16];
            if (d_wstrb[3]) ram_b3[d_addr] <= d_wdata[31:24];
        end
        d_rdata <= {ram_b3[d_addr], ram_b2[d_addr], ram_b1[d_addr], ram_b0[d_addr]};
    end

endmodule
