`timescale 1ns / 1ps
`include "riscv_defines.vh"

// ============================================================================
// Processador RISC-V RV32I / RV64 - Nucleo Completo Pipelined em 5 Estagios
// Estagios: IF (Busca) -> ID (Decodificacao) -> EX (Execucao) -> MEM -> WB
// Totalmente sintetizavel para FPGA com alta frequencia de operacao
// ============================================================================
module riscv_core #(
    parameter DATA_WIDTH = 32,
    parameter RESET_PC   = 32'h00000000
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Barramento de Memoria de Instrucao (Porta IF)
    output wire [DATA_WIDTH-1:0]   imem_addr,
    input  wire [31:0]             imem_rdata,
    output wire                    imem_req,
    
    // Barramento de Memoria de Dados (Porta MEM)
    output wire [DATA_WIDTH-1:0]   dmem_addr,
    output wire [DATA_WIDTH-1:0]   dmem_wdata,
    input  wire [DATA_WIDTH-1:0]   dmem_rdata,
    output wire                    dmem_read,
    output wire                    dmem_write,
    output wire [3:0]              dmem_wstrb,
    
    // Interrupcao de Timer Externa (CLINT)
    input  wire                    timer_irq
);

    // ========================================================================
    // SINAIS E REGISTRADORES DO PIPELINE
    // ========================================================================
    
    // Program Counter
    reg  [DATA_WIDTH-1:0] pc;
    wire [DATA_WIDTH-1:0] pc_plus_4 = pc + 4;
    wire [DATA_WIDTH-1:0] next_pc;

    // Sinais de Controle de Fluxo
    wire branch_taken;
    wire [DATA_WIDTH-1:0] branch_target;
    wire is_jump;
    wire pipeline_stall;
    wire pipeline_flush_ex;
    wire pipeline_flush_id = branch_taken || is_jump;

    // ------------------------------------------------------------------------
    // ESTAGIO 1: INSTRUCTION FETCH (IF)
    // ------------------------------------------------------------------------
    assign imem_addr = pc;
    assign imem_req  = 1'b1;

    // ------------------------------------------------------------------------
    // REGISTRADOR DE PIPELINE IF / ID
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] if_id_pc;
    reg [31:0]           if_id_instr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc    <= RESET_PC;
            if_id_instr <= 32'h00000013; // NOP (addi x0, x0, 0)
        end else if (!pipeline_stall) begin
            if (pipeline_flush_id) begin
                if_id_pc    <= {DATA_WIDTH{1'b0}};
                if_id_instr <= 32'h00000013; // NOP
            end else begin
                if_id_pc    <= pc;
                if_id_instr <= imem_rdata;
            end
        end
    end

    // ------------------------------------------------------------------------
    // ESTAGIO 2: INSTRUCTION DECODE (ID)
    // ------------------------------------------------------------------------
    wire [4:0]  id_rs1, id_rs2, id_rd;
    wire [2:0]  id_funct3;
    wire [6:0]  id_funct7, id_opcode;
    wire [DATA_WIDTH-1:0] id_imm;
    wire [3:0]  id_alu_op;
    wire        id_alu_src_a, id_alu_src_b;
    wire        id_mem_read, id_mem_write;
    wire [1:0]  id_wb_sel;
    wire        id_reg_write, id_branch, id_jump, id_is_jalr, id_is_csr, id_is_mret;

    decoder #(DATA_WIDTH) u_decoder (
        .instr        (if_id_instr),
        .rs1          (id_rs1),
        .rs2          (id_rs2),
        .rd           (id_rd),
        .funct3       (id_funct3),
        .funct7       (id_funct7),
        .opcode       (id_opcode),
        .imm          (id_imm),
        .alu_op       (id_alu_op),
        .alu_src_a    (id_alu_src_a),
        .alu_src_b    (id_alu_src_b),
        .mem_read     (id_mem_read),
        .mem_write    (id_mem_write),
        .wb_sel       (id_wb_sel),
        .reg_write    (id_reg_write),
        .branch       (id_branch),
        .jump         (id_jump),
        .is_jalr      (id_is_jalr),
        .is_csr       (id_is_csr),
        .is_mret      (id_is_mret)
    );

    wire [DATA_WIDTH-1:0] id_rs1_data, id_rs2_data;
    wire [4:0]            wb_rd;
    wire [DATA_WIDTH-1:0] wb_data;
    wire                  wb_reg_write;

    regfile #(DATA_WIDTH) u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (id_rs1),
        .rs1_data (id_rs1_data),
        .rs2_addr (id_rs2),
        .rs2_data (id_rs2_data),
        .we       (wb_reg_write),
        .rd_addr  (wb_rd),
        .rd_data  (wb_data)
    );

    // ------------------------------------------------------------------------
    // REGISTRADOR DE PIPELINE ID / EX
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] id_ex_pc;
    reg [DATA_WIDTH-1:0] id_ex_rs1_data, id_ex_rs2_data;
    reg [DATA_WIDTH-1:0] id_ex_imm;
    reg [4:0]            id_ex_rs1, id_ex_rs2, id_ex_rd;
    reg [2:0]            id_ex_funct3;
    reg [3:0]            id_ex_alu_op;
    reg                  id_ex_alu_src_a, id_ex_alu_src_b;
    reg                  id_ex_mem_read, id_ex_mem_write;
    reg [1:0]            id_ex_wb_sel;
    reg                  id_ex_reg_write, id_ex_branch, id_ex_jump, id_ex_is_jalr;
    reg                  id_ex_is_csr, id_ex_is_mret;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc        <= {DATA_WIDTH{1'b0}};
            id_ex_rs1_data  <= {DATA_WIDTH{1'b0}};
            id_ex_rs2_data  <= {DATA_WIDTH{1'b0}};
            id_ex_imm       <= {DATA_WIDTH{1'b0}};
            id_ex_rs1       <= 5'd0;
            id_ex_rs2       <= 5'd0;
            id_ex_rd        <= 5'd0;
            id_ex_funct3    <= 3'd0;
            id_ex_alu_op    <= 4'd0;
            id_ex_alu_src_a <= 1'b0;
            id_ex_alu_src_b <= 1'b0;
            id_ex_mem_read  <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_wb_sel    <= 2'd0;
            id_ex_reg_write <= 1'b0;
            id_ex_branch    <= 1'b0;
            id_ex_jump      <= 1'b0;
            id_ex_is_jalr   <= 1'b0;
            id_ex_is_csr    <= 1'b0;
            id_ex_is_mret   <= 1'b0;
        end else if (pipeline_flush_ex || pipeline_flush_id) begin
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read  <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_branch    <= 1'b0;
            id_ex_jump      <= 1'b0;
            id_ex_rd        <= 5'd0;
        end else begin
            id_ex_pc        <= if_id_pc;
            id_ex_rs1_data  <= id_rs1_data;
            id_ex_rs2_data  <= id_rs2_data;
            id_ex_imm       <= id_imm;
            id_ex_rs1       <= id_rs1;
            id_ex_rs2       <= id_rs2;
            id_ex_rd        <= id_rd;
            id_ex_funct3    <= id_funct3;
            id_ex_alu_op    <= id_alu_op;
            id_ex_alu_src_a <= id_alu_src_a;
            id_ex_alu_src_b <= id_alu_src_b;
            id_ex_mem_read  <= id_mem_read;
            id_ex_mem_write <= id_mem_write;
            id_ex_wb_sel    <= id_wb_sel;
            id_ex_reg_write <= id_reg_write;
            id_ex_branch    <= id_branch;
            id_ex_jump      <= id_jump;
            id_ex_is_jalr   <= id_is_jalr;
            id_ex_is_csr    <= id_is_csr;
            id_ex_is_mret   <= id_is_mret;
        end
    end

    // ------------------------------------------------------------------------
    // ESTAGIO 3: EXECUTE (EX)
    // ------------------------------------------------------------------------
    wire [1:0] forward_a, forward_b;
    reg  [DATA_WIDTH-1:0] ex_op_a_forwarded;
    reg  [DATA_WIDTH-1:0] ex_op_b_forwarded;
    wire [DATA_WIDTH-1:0] mem_alu_result;

    always @(*) begin
        case (forward_a)
            2'b01: ex_op_a_forwarded = mem_alu_result;
            2'b10: ex_op_a_forwarded = wb_data;
            default: ex_op_a_forwarded = id_ex_rs1_data;
        endcase

        case (forward_b)
            2'b01: ex_op_b_forwarded = mem_alu_result;
            2'b10: ex_op_b_forwarded = wb_data;
            default: ex_op_b_forwarded = id_ex_rs2_data;
        endcase
    end

    wire [DATA_WIDTH-1:0] alu_in_a = (id_ex_alu_src_a) ? id_ex_pc : ex_op_a_forwarded;
    wire [DATA_WIDTH-1:0] alu_in_b = (id_ex_alu_src_b) ? id_ex_imm : ex_op_b_forwarded;
    wire [DATA_WIDTH-1:0] ex_alu_result;
    wire                  ex_alu_zero;

    alu #(DATA_WIDTH) u_alu (
        .a_in       (alu_in_a),
        .b_in       (alu_in_b),
        .alu_op     (id_ex_alu_op),
        .result_out (ex_alu_result),
        .zero_out   (ex_alu_zero)
    );

    branch_unit #(DATA_WIDTH) u_branch (
        .funct3        (id_ex_funct3),
        .rs1_data      (ex_op_a_forwarded),
        .rs2_data      (ex_op_b_forwarded),
        .branch_enable (id_ex_branch),
        .branch_taken  (branch_taken)
    );

    assign is_jump = id_ex_jump;
    assign branch_target = (id_ex_is_jalr) ? ((ex_op_a_forwarded + id_ex_imm) & ~1) :
                                             (id_ex_pc + id_ex_imm);

    // CSR Unit
    wire [DATA_WIDTH-1:0] csr_rdata;
    wire                  irq_pending;
    wire [DATA_WIDTH-1:0] trap_vector;
    wire [DATA_WIDTH-1:0] mepc_out;

    csr_unit #(DATA_WIDTH) u_csr (
        .clk         (clk),
        .rst_n       (rst_n),
        .csr_addr    (id_ex_imm[11:0]),
        .csr_wdata   (ex_op_a_forwarded),
        .csr_op      (id_ex_funct3),
        .csr_we      (id_ex_is_csr),
        .csr_rdata   (csr_rdata),
        .timer_irq   (timer_irq),
        .trap_entry  (irq_pending),
        .trap_pc     (id_ex_pc),
        .trap_cause  (`TRAP_TIMER_INT),
        .mret_inst   (id_ex_is_mret),
        .irq_pending (irq_pending),
        .trap_vector (trap_vector),
        .mepc_out    (mepc_out)
    );

    // Proximo Program Counter
    assign next_pc = (irq_pending)    ? trap_vector :
                     (id_ex_is_mret)  ? mepc_out :
                     (branch_taken || is_jump) ? branch_target :
                     pc_plus_4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_PC;
        end else if (!pipeline_stall) begin
            pc <= next_pc;
        end
    end

    // ------------------------------------------------------------------------
    // REGISTRADOR DE PIPELINE EX / MEM
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] ex_mem_alu_result;
    reg [DATA_WIDTH-1:0] ex_mem_wdata;
    reg [DATA_WIDTH-1:0] ex_mem_pc_plus_4;
    reg [DATA_WIDTH-1:0] ex_mem_csr_data;
    reg [4:0]            ex_mem_rd;
    reg [2:0]            ex_mem_funct3;
    reg [1:0]            ex_mem_wb_sel;
    reg                  ex_mem_mem_read, ex_mem_mem_write, ex_mem_reg_write;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= {DATA_WIDTH{1'b0}};
            ex_mem_wdata      <= {DATA_WIDTH{1'b0}};
            ex_mem_pc_plus_4  <= {DATA_WIDTH{1'b0}};
            ex_mem_csr_data   <= {DATA_WIDTH{1'b0}};
            ex_mem_rd         <= 5'd0;
            ex_mem_funct3     <= 3'd0;
            ex_mem_wb_sel     <= 2'd0;
            ex_mem_mem_read   <= 1'b0;
            ex_mem_mem_write  <= 1'b0;
            ex_mem_reg_write  <= 1'b0;
        end else begin
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_wdata      <= ex_op_b_forwarded;
            ex_mem_pc_plus_4  <= id_ex_pc + 4;
            ex_mem_csr_data   <= csr_rdata;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_funct3     <= id_ex_funct3;
            ex_mem_wb_sel     <= id_ex_wb_sel;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_mem_write;
            ex_mem_reg_write  <= id_ex_reg_write;
        end
    end

    // ------------------------------------------------------------------------
    // ESTAGIO 4: MEMORY ACCESS (MEM)
    // ------------------------------------------------------------------------
    assign mem_alu_result = ex_mem_alu_result;
    assign dmem_addr      = ex_mem_alu_result;
    assign dmem_wdata     = ex_mem_wdata;
    assign dmem_read      = ex_mem_mem_read;
    assign dmem_write     = ex_mem_mem_write;

    // Geracao de Strobe de Escrita em Memoria
    reg [3:0] wstrb_comb;
    always @(*) begin
        case (ex_mem_funct3[1:0])
            2'b00: wstrb_comb = 4'b0001 << ex_mem_alu_result[1:0]; // SB (Byte)
            2'b01: wstrb_comb = 4'b0011 << ex_mem_alu_result[1:0]; // SH (Half)
            default: wstrb_comb = 4'b1111;                         // SW (Word)
        endcase
    end
    assign dmem_wstrb = (dmem_write) ? wstrb_comb : 4'b0000;

    // ------------------------------------------------------------------------
    // REGISTRADOR DE PIPELINE MEM / WB
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem_wb_alu_result;
    reg [DATA_WIDTH-1:0] mem_wb_rdata;
    reg [DATA_WIDTH-1:0] mem_wb_pc_plus_4;
    reg [DATA_WIDTH-1:0] mem_wb_csr_data;
    reg [4:0]            mem_wb_rd;
    reg [1:0]            mem_wb_wb_sel;
    reg                  mem_wb_reg_write;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result <= {DATA_WIDTH{1'b0}};
            mem_wb_rdata      <= {DATA_WIDTH{1'b0}};
            mem_wb_pc_plus_4  <= {DATA_WIDTH{1'b0}};
            mem_wb_csr_data   <= {DATA_WIDTH{1'b0}};
            mem_wb_rd         <= 5'd0;
            mem_wb_wb_sel     <= 2'd0;
            mem_wb_reg_write  <= 1'b0;
        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_rdata      <= dmem_rdata;
            mem_wb_pc_plus_4  <= ex_mem_pc_plus_4;
            mem_wb_csr_data   <= ex_mem_csr_data;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_wb_sel     <= ex_mem_wb_sel;
            mem_wb_reg_write  <= ex_mem_reg_write;
        end
    end

    // ------------------------------------------------------------------------
    // ESTAGIO 5: WRITEBACK (WB)
    // ------------------------------------------------------------------------
    assign wb_rd        = mem_wb_rd;
    assign wb_reg_write = mem_wb_reg_write;

    reg [DATA_WIDTH-1:0] wb_mux;
    always @(*) begin
        case (mem_wb_wb_sel)
            2'b00: wb_mux = mem_wb_alu_result;
            2'b01: wb_mux = mem_wb_rdata;
            2'b10: wb_mux = mem_wb_pc_plus_4;
            2'b11: wb_mux = mem_wb_csr_data;
            default: wb_mux = mem_wb_alu_result;
        endcase
    end
    assign wb_data = wb_mux;

    // ------------------------------------------------------------------------
    // INSTANCIACAO DA UNIDADE DE HAZARD E ENCAMINHAMENTO
    // ------------------------------------------------------------------------
    hazard_unit u_hazard (
        .id_rs1        (id_rs1),
        .id_rs2        (id_rs2),
        .ex_rs1        (id_ex_rs1),
        .ex_rs2        (id_ex_rs2),
        .ex_rd         (id_ex_rd),
        .ex_mem_read   (id_ex_mem_read),
        .mem_rd        (ex_mem_rd),
        .mem_reg_write (ex_mem_reg_write),
        .wb_rd         (mem_wb_rd),
        .wb_reg_write  (mem_wb_reg_write),
        .forward_a     (forward_a),
        .forward_b     (forward_b),
        .stall         (pipeline_stall),
        .flush_ex      (pipeline_flush_ex)
    );

endmodule
