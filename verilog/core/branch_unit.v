`timescale 1ns / 1ps
`include "riscv_defines.vh"

// ============================================================================
// Unidade de Desvio Condicional e Salto (Branch Unit)
// Avalia predicados de desvio (BEQ, BNE, BLT, BGE, BLTU, BGEU)
// ============================================================================
module branch_unit #(
    parameter DATA_WIDTH = 32
)(
    input  wire [2:0]              funct3,
    input  wire [DATA_WIDTH-1:0]   rs1_data,
    input  wire [DATA_WIDTH-1:0]   rs2_data,
    input  wire                    branch_enable,
    output reg                     branch_taken
);

    wire signed [DATA_WIDTH-1:0] rs1_signed = rs1_data;
    wire signed [DATA_WIDTH-1:0] rs2_signed = rs2_data;

    always @(*) begin
        if (!branch_enable) begin
            branch_taken = 1'b0;
        end else begin
            case (funct3)
                `FUNCT3_BEQ:  branch_taken = (rs1_data == rs2_data);
                `FUNCT3_BNE:  branch_taken = (rs1_data != rs2_data);
                `FUNCT3_BLT:  branch_taken = (rs1_signed < rs2_signed);
                `FUNCT3_BGE:  branch_taken = (rs1_signed >= rs2_signed);
                `FUNCT3_BLTU: branch_taken = (rs1_data < rs2_data);
                `FUNCT3_BGEU: branch_taken = (rs1_data >= rs2_data);
                default:      branch_taken = 1'b0;
            endcase
        end
    end

endmodule
