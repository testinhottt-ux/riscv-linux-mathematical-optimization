`timescale 1ns / 1ps
`include "riscv_defines.vh"

// ============================================================================
// Unidade de Registradores de Controle e Estado (CSR Unit)
// Implementa suporte a interrupcoes de maquina, timer ticks, excecoes e
// instrucoes atomicas CSRRW, CSRRS, CSRRC
// ============================================================================
module csr_unit #(
    parameter DATA_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    
    // Acesso por Instrucao
    input  wire [11:0]             csr_addr,
    input  wire [DATA_WIDTH-1:0]   csr_wdata,
    input  wire [2:0]              csr_op,       // funct3
    input  wire                    csr_we,
    output reg  [DATA_WIDTH-1:0]   csr_rdata,
    
    // Sinais de Trap e Interrupcao
    input  wire                    timer_irq,    // Interrupcao de Timer (MTIP)
    input  wire                    trap_entry,   // Disparo de Trap
    input  wire [DATA_WIDTH-1:0]   trap_pc,      // PC da instrucao que disparou o trap
    input  wire [DATA_WIDTH-1:0]   trap_cause,   // Causa do trap (mcause)
    input  wire                    mret_inst,    // Retorno de Trap (mret)
    
    output wire                    irq_pending,  // Sinaliza interrupcao ativa para o core
    output wire [DATA_WIDTH-1:0]   trap_vector,  // Endereco de destino do trap (mtvec)
    output wire [DATA_WIDTH-1:0]   mepc_out      // Endereco de retorno do trap (mepc)
);

    // Registradores CSR Internos
    reg [DATA_WIDTH-1:0] csr_mstatus;
    reg [DATA_WIDTH-1:0] csr_mie;
    reg [DATA_WIDTH-1:0] csr_mtvec;
    reg [DATA_WIDTH-1:0] csr_mepc;
    reg [DATA_WIDTH-1:0] csr_mcause;
    reg [DATA_WIDTH-1:0] csr_mtval;
    reg [63:0]           csr_mcycle;
    reg [63:0]           csr_minstret;

    // Mascaras de Bits para mstatus: MIE (bit 3), MPIE (bit 7)
    wire mie_bit  = csr_mstatus[3];
    wire mpie_bit = csr_mstatus[7];

    // Interrupcao pendente: Timer Interrupt habilitado globalmente e localmente
    wire mtip = timer_irq;
    wire mtip_enabled = csr_mie[7]; // MTIE bit no registrador mie
    assign irq_pending = mie_bit && mtip_enabled && mtip;
    assign trap_vector = csr_mtvec;
    assign mepc_out    = csr_mepc;

    // Leitura dos Registradores CSR
    always @(*) begin
        case (csr_addr)
            `CSR_MSTATUS:  csr_rdata = csr_mstatus;
            `CSR_MISA:     csr_rdata = 32'h40001100; // RV32I base
            `CSR_MIE:      csr_rdata = csr_mie;
            `CSR_MTVEC:    csr_rdata = csr_mtvec;
            `CSR_MEPC:     csr_rdata = csr_mepc;
            `CSR_MCAUSE:   csr_rdata = csr_mcause;
            `CSR_MTVAL:    csr_rdata = csr_mtval;
            `CSR_MIP:      csr_rdata = { {(DATA_WIDTH-8){1'b0}}, mtip, 7'b0 };
            `CSR_MCYCLE:   csr_rdata = csr_mcycle[31:0];
            `CSR_MINSTRET: csr_rdata = csr_minstret[31:0];
            default:       csr_rdata = {DATA_WIDTH{1'b0}};
        endcase
    end

    // Calculo do novo valor para escrita
    reg [DATA_WIDTH-1:0] next_csr_val;
    always @(*) begin
        case (csr_op[1:0])
            2'b01: next_csr_val = csr_wdata;                 // CSRRW (Write)
            2'b10: next_csr_val = csr_rdata | csr_wdata;     // CSRRS (Set)
            2'b11: next_csr_val = csr_rdata & (~csr_wdata);  // CSRRC (Clear)
            default: next_csr_val = csr_wdata;
        endcase
    end

    // Atualizacao Sequencial dos CSRs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_mstatus  <= 32'h00000008; // MIE ativo por padrao
            csr_mie      <= 32'h00000080; // MTIE ativo por padrao
            csr_mtvec    <= 32'h00000020; // Vetor padrao de trap
            csr_mepc     <= 32'h00000000;
            csr_mcause   <= 32'h00000000;
            csr_mtval    <= 32'h00000000;
            csr_mcycle   <= 64'd0;
            csr_minstret <= 64'd0;
        end else begin
            csr_mcycle   <= csr_mcycle + 1'b1;
            csr_minstret <= csr_minstret + 1'b1;

            if (trap_entry) begin
                // Salva contexto para entrada em trap
                csr_mepc        <= trap_pc;
                csr_mcause      <= trap_cause;
                csr_mstatus[7]  <= csr_mstatus[3]; // MPIE <= MIE
                csr_mstatus[3]  <= 1'b0;           // Desabilita MIE durante execucao do tratador
            end else if (mret_inst) begin
                // Retorno da rotina de trap
                csr_mstatus[3]  <= csr_mstatus[7]; // MIE <= MPIE
                csr_mstatus[7]  <= 1'b1;           // MPIE <= 1
            end else if (csr_we) begin
                case (csr_addr)
                    `CSR_MSTATUS: csr_mstatus <= next_csr_val;
                    `CSR_MIE:     csr_mie     <= next_csr_val;
                    `CSR_MTVEC:   csr_mtvec   <= next_csr_val;
                    `CSR_MEPC:    csr_mepc    <= next_csr_val;
                    `CSR_MCAUSE:  csr_mcause  <= next_csr_val;
                    `CSR_MTVAL:   csr_mtval   <= next_csr_val;
                    default: ;
                endcase
            end
        end
    end

endmodule
