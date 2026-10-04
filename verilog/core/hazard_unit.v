`timescale 1ns / 1ps

// ============================================================================
// Unidade de Tratamento de Conflitos e Encaminhamento (Hazard & Forwarding Unit)
// Detecta conflitos de dados RAW (Read After Write) e aplica encaminhamento
// direto ou parada controlada de 1 ciclo no caso de Load-Use Hazard
// ============================================================================
module hazard_unit (
    // Registradores fonte no estagio Decode / Execute
    input  wire [4:0]  id_rs1,
    input  wire [4:0]  id_rs2,
    input  wire [4:0]  ex_rs1,
    input  wire [4:0]  ex_rs2,
    
    // Registradores destino e controle de escrita nos estagios posteriores
    input  wire [4:0]  ex_rd,
    input  wire        ex_mem_read,
    input  wire [4:0]  mem_rd,
    input  wire        mem_reg_write,
    input  wire [4:0]  wb_rd,
    input  wire        wb_reg_write,
    
    // Sinais de Encaminhamento para a ALU no estagio Execute
    // 2'b00: dado original do registrador
    // 2'b01: encaminhamento do estagio MEM (EX/MEM pipeline register)
    // 2'b10: encaminhamento do estagio WB (MEM/WB pipeline register)
    output reg  [1:0]  forward_a,
    output reg  [1:0]  forward_b,
    
    // Sinais de Controle de Fluxo do Pipeline
    output reg         stall,       // Trava estagios IF e ID
    output reg         flush_ex     // Zera instrucao no estagio EX
);

    // 1. Logica de Encaminhamento de Dados (Forwarding)
    always @(*) begin
        // Encaminhamento para operando A
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs1)) begin
            forward_a = 2'b01; // Encaminha de MEM
        end else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs1)) begin
            forward_a = 2'b10; // Encaminha de WB
        end else begin
            forward_a = 2'b00; // Usa registrador original
        end

        // Encaminhamento para operando B
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs2)) begin
            forward_b = 2'b01; // Encaminha de MEM
        end else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs2)) begin
            forward_b = 2'b10; // Encaminha de WB
        end else begin
            forward_b = 2'b00; // Usa registrador original
        end
    end

    // 2. Deteccao de Conflito Load-Use Hazard
    // Ocorre quando uma instrucao no estagio ID depende do resultado de um LOAD no estagio EX
    always @(*) begin
        if (ex_mem_read && (ex_rd != 5'd0) && ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
            stall    = 1'b1;
            flush_ex = 1'b1;
        end else begin
            stall    = 1'b0;
            flush_ex = 1'b0;
        end
    end

endmodule
