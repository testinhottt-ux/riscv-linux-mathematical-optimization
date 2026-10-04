`timescale 1ns / 1ps

module tb_branch_predictor;

    reg clk;
    reg rst_n;
    reg [31:0] if_pc;
    wire if_predict_taken;

    reg ex_is_branch;
    reg [31:0] ex_pc;
    reg ex_actual_taken;
    wire ex_mispredict;

    branch_predictor #(
        .PC_WIDTH(32),
        .INDEX_BITS(8)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .if_pc(if_pc),
        .if_predict_taken(if_predict_taken),
        .ex_is_branch(ex_is_branch),
        .ex_pc(ex_pc),
        .ex_actual_taken(ex_actual_taken),
        .ex_mispredict(ex_mispredict)
    );

    always #5 clk = ~clk;

    integer hits = 0;
    integer misses = 0;
    integer k;

    initial begin
        clk = 0;
        rst_n = 0;
        if_pc = 32'h00010000;
        ex_is_branch = 0;
        ex_pc = 32'h00010000;
        ex_actual_taken = 0;

        #20 rst_n = 1;
        #10;

        $display("=== INICIANDO TESTE DO BRANCH PREDICTOR BIMODAL RISC-V ===");

        // Simula um loop de 100 iterações (onde o branch é tomado 99 vezes e 1 vez não)
        for (k = 0; k < 100; k = k + 1) begin
            ex_is_branch = 1;
            ex_pc = 32'h00010040;
            if_pc = 32'h00010040;
            ex_actual_taken = (k < 99) ? 1'b1 : 1'b0;

            @(posedge clk);
            #1;
            if (ex_mispredict) begin
                misses = misses + 1;
            end else begin
                hits = hits + 1;
            end
        end

        $display("Resultados do Loop de 100 Iteracoes:");
        $display("  Acertos (Hits)  : %0d", hits);
        $display("  Erros (Misses)  : %0d", misses);
        $display("  Taxa de Acerto  : %0d%%", (hits * 100) / (hits + misses));

        if (hits >= 95) begin
            $display("=== SUCESSO: Branch Predictor validado com precisao >= 95%%! ===");
        end else begin
            $display("=== FALHA: Taxa de acerto abaixo do esperado! ===");
            $finish(1);
        end

        $finish;
    end

endmodule
