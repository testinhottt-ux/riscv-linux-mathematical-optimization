`timescale 1ns / 1ps

// ============================================================================
// Banco de Registradores RISC-V (x0 a x31)
// 32 Registradores x DATA_WIDTH bits com x0 permanentemente aterrado em zero.
// Leitura assincrona dupla (rs1, rs2) com bypass interno de escrita.
// ============================================================================
module regfile #(
    parameter DATA_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Porta de Leitura 1
    input  wire [4:0]              rs1_addr,
    output wire [DATA_WIDTH-1:0]   rs1_data,
    
    // Porta de Leitura 2
    input  wire [4:0]              rs2_addr,
    output wire [DATA_WIDTH-1:0]   rs2_data,
    
    // Porta de Escrita
    input  wire                    we,
    input  wire [4:0]              rd_addr,
    input  wire [DATA_WIDTH-1:0]   rd_data
);

    reg [DATA_WIDTH-1:0] registers [1:31];
    integer i;

    // Escrita sincronizada
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1) begin
                registers[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (we && (rd_addr != 5'd0)) begin
            registers[rd_addr] <= rd_data;
        end
    end

    // Leitura assincrona com forwarding caso leitura e escrita ocorram no mesmo ciclo
    assign rs1_data = (rs1_addr == 5'd0) ? {DATA_WIDTH{1'b0}} :
                      ((we && (rd_addr == rs1_addr)) ? rd_data : registers[rs1_addr]);

    assign rs2_data = (rs2_addr == 5'd0) ? {DATA_WIDTH{1'b0}} :
                      ((we && (rd_addr == rs2_addr)) ? rd_data : registers[rs2_addr]);

endmodule
