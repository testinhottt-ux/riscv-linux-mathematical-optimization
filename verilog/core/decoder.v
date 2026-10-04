`timescale 1ns / 1ps
`include "riscv_defines.vh"

// ============================================================================
// Decodificador de Instrucoes RISC-V RV32I / RV64
// Decodifica formato de instrucao, campos de registradores, imediatos com
// extensao de sinal e sinais de controle do pipeline
// ============================================================================
module decoder #(
    parameter DATA_WIDTH = 32
)(
    input  wire [31:0]             instr,
    
    // Campos dos Registradores
    output wire [4:0]              rs1,
    output wire [4:0]              rs2,
    output wire [4:0]              rd,
    output wire [2:0]              funct3,
    output wire [6:0]              funct7,
    output wire [6:0]              opcode,
    
    // Imediato Expandido com Sinal
    output reg  [DATA_WIDTH-1:0]   imm,
    
    // Sinais de Controle
    output reg  [3:0]              alu_op,
    output reg                     alu_src_b,    // 0: rs2, 1: imediato
    output reg                     alu_src_a,    // 0: rs1, 1: PC
    output reg                     mem_read,
    output reg                     mem_write,
    output reg  [1:0]              wb_sel,       // 0: ALU, 1: MEM, 2: PC+4, 3: CSR
    output reg                     reg_write,
    output reg                     branch,
    output reg                     jump,
    output reg                     is_jalr,
    output reg                     is_csr,
    output reg                     is_mret
);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // Geracao de Imediatos com Extensao de Sinal Conforme Especificacao RISC-V
    always @(*) begin
        case (opcode)
            `OPCODE_OP_IMM, `OPCODE_LOAD, `OPCODE_JALR: 
                imm = {{ (DATA_WIDTH-12){instr[31]} }, instr[31:20]};
            
            `OPCODE_STORE: 
                imm = {{ (DATA_WIDTH-12){instr[31]} }, instr[31:25], instr[11:7]};
            
            `OPCODE_BRANCH: 
                imm = {{ (DATA_WIDTH-13){instr[31]} }, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            
            `OPCODE_LUI, `OPCODE_AUIPC: 
                imm = {{ (DATA_WIDTH-32){instr[31]} }, instr[31:12], 12'b0};
            
            `OPCODE_JAL: 
                imm = {{ (DATA_WIDTH-21){instr[31]} }, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            
            `OPCODE_SYSTEM: // Imediato zimm para operacoes CSR tipo I
                imm = { {(DATA_WIDTH-5){1'b0}}, instr[19:15] };
            
            default: 
                imm = {DATA_WIDTH{1'b0}};
        endcase
    end

    // Geracao de Sinais de Controle do Processador
    always @(*) begin
        // Valores padrao
        alu_op    = `ALU_ADD;
        alu_src_a = 1'b0; // rs1
        alu_src_b = 1'b0; // rs2
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_sel    = 2'b00; // ALU
        reg_write = 1'b0;
        branch    = 1'b0;
        jump      = 1'b0;
        is_jalr   = 1'b0;
        is_csr    = 1'b0;
        is_mret   = 1'b0;

        case (opcode)
            `OPCODE_LUI: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1; // usa imm
                alu_op    = `ALU_PASS_B;
                wb_sel    = 2'b00;
            end

            `OPCODE_AUIPC: begin
                reg_write = 1'b1;
                alu_src_a = 1'b1; // PC
                alu_src_b = 1'b1; // imm
                alu_op    = `ALU_ADD;
                wb_sel    = 2'b00;
            end

            `OPCODE_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                wb_sel    = 2'b10; // PC + 4
            end

            `OPCODE_JALR: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                is_jalr   = 1'b1;
                alu_src_b = 1'b1; // imm
                alu_op    = `ALU_ADD;
                wb_sel    = 2'b10; // PC + 4
            end

            `OPCODE_BRANCH: begin
                branch = 1'b1;
            end

            `OPCODE_LOAD: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1; // imm
                alu_op    = `ALU_ADD;
                mem_read  = 1'b1;
                wb_sel    = 2'b01; // Memoria
            end

            `OPCODE_STORE: begin
                alu_src_b = 1'b1; // imm
                alu_op    = `ALU_ADD;
                mem_write = 1'b1;
            end

            `OPCODE_OP_IMM: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1; // imm
                case (funct3)
                    `FUNCT3_ADD_SUB: alu_op = `ALU_ADD;
                    `FUNCT3_SLL:     alu_op = `ALU_SLL;
                    `FUNCT3_SLT:     alu_op = `ALU_SLT;
                    `FUNCT3_SLTU:    alu_op = `ALU_SLTU;
                    `FUNCT3_XOR:     alu_op = `ALU_XOR;
                    `FUNCT3_SRL_SRA: alu_op = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                    `FUNCT3_OR:      alu_op = `ALU_OR;
                    `FUNCT3_AND:     alu_op = `ALU_AND;
                    default:         alu_op = `ALU_ADD;
                endcase
            end

            `OPCODE_OP: begin
                reg_write = 1'b1;
                case (funct3)
                    `FUNCT3_ADD_SUB: alu_op = (funct7[5]) ? `ALU_SUB : `ALU_ADD;
                    `FUNCT3_SLL:     alu_op = `ALU_SLL;
                    `FUNCT3_SLT:     alu_op = `ALU_SLT;
                    `FUNCT3_SLTU:    alu_op = `ALU_SLTU;
                    `FUNCT3_XOR:     alu_op = `ALU_XOR;
                    `FUNCT3_SRL_SRA: alu_op = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                    `FUNCT3_OR:      alu_op = `ALU_OR;
                    `FUNCT3_AND:     alu_op = `ALU_AND;
                    default:         alu_op = `ALU_ADD;
                endcase
            end

            `OPCODE_SYSTEM: begin
                if (funct3 == 3'b000) begin
                    // mret ou ecall
                    if (instr[31:20] == 12'h302) begin
                        is_mret = 1'b1;
                    end
                end else begin
                    // Instrucoes CSR
                    reg_write = 1'b1;
                    is_csr    = 1'b1;
                    wb_sel    = 2'b11; // CSR
                end
            end

            default: begin
                // No-op / Ilegal
            end
        endcase
    end

endmodule
