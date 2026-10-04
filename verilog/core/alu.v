`timescale 1ns / 1ps
`include "riscv_defines.vh"

// ============================================================================
// Modulo ALU - Unidade Logica e Aritmetica Sintetizavel RISC-V (RV32I / RV64)
// Realiza operacoes em 1 ciclo de clock com caminhos criticos balanceados
// ============================================================================
module alu #(
    parameter DATA_WIDTH = 32
)(
    input  wire [DATA_WIDTH-1:0]   a_in,
    input  wire [DATA_WIDTH-1:0]   b_in,
    input  wire [3:0]              alu_op,
    output reg  [DATA_WIDTH-1:0]   result_out,
    output wire                    zero_out
);

    wire signed [DATA_WIDTH-1:0] a_signed = a_in;
    wire signed [DATA_WIDTH-1:0] b_signed = b_in;
    wire [4:0] shamt = b_in[4:0];

    always @(*) begin
        case (alu_op)
            `ALU_ADD:    result_out = a_in + b_in;
            `ALU_SUB:    result_out = a_in - b_in;
            `ALU_SLL:    result_out = a_in << shamt;
            `ALU_SLT:    result_out = (a_signed < b_signed) ? {{(DATA_WIDTH-1){1'b0}}, 1'b1} : {DATA_WIDTH{1'b0}};
            `ALU_SLTU:   result_out = (a_in < b_in) ? {{(DATA_WIDTH-1){1'b0}}, 1'b1} : {DATA_WIDTH{1'b0}};
            `ALU_XOR:    result_out = a_in ^ b_in;
            `ALU_SRL:    result_out = a_in >> shamt;
            `ALU_SRA:    result_out = a_signed >>> shamt;
            `ALU_OR:     result_out = a_in | b_in;
            `ALU_AND:    result_out = a_in & b_in;
            `ALU_PASS_B: result_out = b_in;
            default:     result_out = {DATA_WIDTH{1'b0}};
        endcase
    end

    assign zero_out = (result_out == {DATA_WIDTH{1'b0}});

endmodule
