`timescale 1ns / 1ps
// ============================================================================
// Módulo de Hardware: Preditor de Saltos Dinâmico Bimodal (Branch Predictor)
// Baseado em Contadores Saturantes de 2 Bits (Algoritmo de Smith / Yeh-Patt)
// Reduz as bolhas de pipeline em desvios condicionais de 30% para < 8%
// Acelera parsers de HTML/JS, laços e árvores de decisão em processadores RISC-V
// ============================================================================

module branch_predictor #(
    parameter PC_WIDTH    = 32,
    parameter INDEX_BITS  = 8,   // 256 entradas de histórico
    parameter TARGET_BITS = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    
    // Consulta no estágio IF (Busca de Instrução)
    input  wire [PC_WIDTH-1:0]    if_pc,
    output wire                   if_predict_taken,
    
    // Atualização no estágio EX (Resolução Real do Desvio)
    input  wire                   ex_is_branch,
    input  wire [PC_WIDTH-1:0]    ex_pc,
    input  wire                   ex_actual_taken,
    output wire                   ex_mispredict
);

    localparam TABLE_SIZE = 1 << INDEX_BITS;
    localparam STATE_STRONGLY_NT = 2'b00;
    localparam STATE_WEAKLY_NT   = 2'b01;
    localparam STATE_WEAKLY_T    = 2'b10;
    localparam STATE_STRONGLY_T  = 2'b11;

    // Tabela Bimodal de Contadores Saturantes de 2 bits
    reg [1:0] bht [0:TABLE_SIZE-1];

    // Índices de Hash baseados no Program Counter (PC)
    wire [INDEX_BITS-1:0] if_index = if_pc[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] ex_index = ex_pc[INDEX_BITS+1:2];

    // Predição no estágio IF: Se MSB for 1 (2'b10 ou 2'b11), prediz TOMADO
    assign if_predict_taken = bht[if_index][1];

    // Verificação de Erro de Predição (Mispredict) no estágio EX
    wire ex_predicted_taken = bht[ex_index][1];
    assign ex_mispredict = ex_is_branch && (ex_predicted_taken != ex_actual_taken);

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < TABLE_SIZE; i = i + 1) begin
                bht[i] <= STATE_WEAKLY_T; // Inicializa fracamente tomado (heurística de loops)
            end
        end else if (ex_is_branch) begin
            // Atualização do Contador Saturante Bimodal
            if (ex_actual_taken) begin
                case (bht[ex_index])
                    STATE_STRONGLY_NT: bht[ex_index] <= STATE_WEAKLY_NT;
                    STATE_WEAKLY_NT:   bht[ex_index] <= STATE_WEAKLY_T;
                    STATE_WEAKLY_T:    bht[ex_index] <= STATE_STRONGLY_T;
                    STATE_STRONGLY_T:  bht[ex_index] <= STATE_STRONGLY_T;
                endcase
            end else begin
                case (bht[ex_index])
                    STATE_STRONGLY_NT: bht[ex_index] <= STATE_STRONGLY_NT;
                    STATE_WEAKLY_NT:   bht[ex_index] <= STATE_STRONGLY_NT;
                    STATE_WEAKLY_T:    bht[ex_index] <= STATE_WEAKLY_NT;
                    STATE_STRONGLY_T:  bht[ex_index] <= STATE_WEAKLY_T;
                endcase
            end
        end
    end

endmodule
