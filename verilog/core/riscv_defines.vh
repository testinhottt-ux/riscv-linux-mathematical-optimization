`ifndef RISCV_DEFINES_VH
`define RISCV_DEFINES_VH

// ============================================================================
// RISC-V RV32I / RV64 Definicoes de Instrucoes, Opcodes e Opeacoes de ALU
// Arquitetura Modular Sintetizavel para FPGA e Simulacao
// ============================================================================

// Opcodes Principais (Bits [6:0])
`define OPCODE_LUI      7'b0110111  // Load Upper Immediate
`define OPCODE_AUIPC    7'b0010111  // Add Upper Immediate to PC
`define OPCODE_JAL      7'b1101111  // Jump and Link
`define OPCODE_JALR     7'b1100111  // Jump and Link Register
`define OPCODE_BRANCH   7'b1100011  // Branch condicional
`define OPCODE_LOAD     7'b0000011  // Load memoria
`define OPCODE_STORE    7'b0100011  // Store memoria
`define OPCODE_OP_IMM   7'b0010011  // Operacoes Inteiras Imediatas
`define OPCODE_OP       7'b0110011  // Operacoes Inteiras Registrador-Registrador
`define OPCODE_SYSTEM   7'b1110011  // Chamadas de Sistema e Registradores CSR
`define OPCODE_FENCE    7'b0001111  // Barreira de Memoria

// Funct3 para Branches (OPCODE_BRANCH)
`define FUNCT3_BEQ      3'b000
`define FUNCT3_BNE      3'b001
`define FUNCT3_BLT      3'b100
`define FUNCT3_BGE      3'b101
`define FUNCT3_BLTU     3'b110
`define FUNCT3_BGEU     3'b111

// Funct3 para Loads (OPCODE_LOAD)
`define FUNCT3_LB       3'b000
`define FUNCT3_LH       3'b001
`define FUNCT3_LW       3'b010
`define FUNCT3_LBU      3'b100
`define FUNCT3_LHU      3'b101

// Funct3 para Stores (OPCODE_STORE)
`define FUNCT3_SB       3'b000
`define FUNCT3_SH       3'b001
`define FUNCT3_SW       3'b010

// Funct3 para Operacoes Inteiras (OPCODE_OP e OPCODE_OP_IMM)
`define FUNCT3_ADD_SUB  3'b000
`define FUNCT3_SLL      3'b001
`define FUNCT3_SLT      3'b010
`define FUNCT3_SLTU     3'b011
`define FUNCT3_XOR      3'b100
`define FUNCT3_SRL_SRA  3'b101
`define FUNCT3_OR       3'b110
`define FUNCT3_AND      3'b111

// Funct3 para Operacoes de CSR (OPCODE_SYSTEM)
`define FUNCT3_CSRRW    3'b001
`define FUNCT3_CSRRS    3'b010
`define FUNCT3_CSRRC    3'b011
`define FUNCT3_CSRRWI   3'b101
`define FUNCT3_CSRRSI   3'b110
`define FUNCT3_CSRRCI   3'b111

// Operacoes Internas da ALU (4 bits)
`define ALU_ADD         4'b0000
`define ALU_SUB         4'b0001
`define ALU_SLL         4'b0010
`define ALU_SLT         4'b0011
`define ALU_SLTU        4'b0100
`define ALU_XOR         4'b0101
`define ALU_SRL         4'b0110
`define ALU_SRA         4'b0111
`define ALU_OR          4'b1000
`define ALU_AND         4'b1001
`define ALU_PASS_B      4'b1010

// Enderecos de Registradores CSR Principais
`define CSR_MSTATUS     12'h300
`define CSR_MISA        12'h301
`define CSR_MIE         12'h304
`define CSR_MTVEC       12'h305
`define CSR_MEPC        12'h341
`define CSR_MCAUSE      12'h342
`define CSR_MTVAL       12'h343
`define CSR_MIP         12'h344
`define CSR_MCYCLE      12'hB00
`define CSR_MINSTRET    12'hB02

// Causas de Trap / Interrupcao (mcause)
`define TRAP_TIMER_INT  32'h80000007  // Interrupcao de Timer da Maquina (MTIP)
`define TRAP_ILLEGAL_IN 32'h00000002  // Instrucao Ilegal
`define TRAP_ECALL_M    32'h0000000B  // ECALL de Modo Maquina

`endif // RISCV_DEFINES_VH
