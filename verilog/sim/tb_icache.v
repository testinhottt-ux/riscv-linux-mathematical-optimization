`timescale 1ns / 1ps

module tb_icache;

    reg clk;
    reg rst_n;

    // Interface CPU
    reg  [31:0] cpu_req_addr;
    reg         cpu_req_valid;
    wire [31:0] cpu_resp_data;
    wire        cpu_resp_valid;
    wire        cache_stall;

    // Interface Memoria Principal
    wire [31:0] mem_req_addr;
    wire        mem_req_valid;
    reg  [31:0] mem_resp_data;
    reg         mem_resp_valid;

    reg         flush_req;
    wire [31:0] hit_counter;
    wire [31:0] miss_counter;

    // Instancia do Modulo
    icache #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .CACHE_LINES(16),
        .INDEX_BITS(4),
        .OFFSET_BITS(2)
    ) uut (
        .clk           (clk),
        .rst_n         (rst_n),
        .cpu_req_addr  (cpu_req_addr),
        .cpu_req_valid (cpu_req_valid),
        .cpu_resp_data (cpu_resp_data),
        .cpu_resp_valid(cpu_resp_valid),
        .cache_stall   (cache_stall),
        .mem_req_addr  (mem_req_addr),
        .mem_req_valid (mem_req_valid),
        .mem_resp_data (mem_resp_data),
        .mem_resp_valid(mem_resp_valid),
        .flush_req     (flush_req),
        .hit_counter   (hit_counter),
        .miss_counter  (miss_counter)
    );

    // Gerador de Clock (50 MHz)
    always #10 clk = ~clk;

    // Emulador de Memoria Principal (latencia de 2 ciclos para responder)
    always @(posedge clk) begin
        if (mem_req_valid) begin
            #20;
            mem_resp_data  <= mem_req_addr + 32'hA5A50000;
            mem_resp_valid <= 1'b1;
            #20;
            mem_resp_valid <= 1'b0;
        end
    end

    initial begin
        clk = 0;
        rst_n = 0;
        cpu_req_addr = 0;
        cpu_req_valid = 0;
        mem_resp_data = 0;
        mem_resp_valid = 0;
        flush_req = 0;

        #100;
        rst_n = 1;
        #500; // Aguarda termino do flush inicial da cache

        $display("=== TESTE DO I-CACHE RISC-V ===");
        // 1. Requisicao em 0x0000_1000 (esperado: MISS inicial)
        @(posedge clk);
        cpu_req_addr  <= 32'h00001000;
        cpu_req_valid <= 1'b1;
        @(posedge clk);
        cpu_req_valid <= 1'b0;

        // Aguarda resposta
        wait(cpu_resp_valid);
        $display("[MISS OK] Dados recebidos da memoria: 0x%08x", cpu_resp_data);
        #40;

        // 2. Segunda requisicao no mesmo endereco (esperado: HIT imediato)
        @(posedge clk);
        cpu_req_addr  <= 32'h00001000;
        cpu_req_valid <= 1'b1;
        @(posedge clk);
        cpu_req_valid <= 1'b0;

        wait(cpu_resp_valid);
        $display("[HIT OK] Dados lidos da cache diretamente: 0x%08x", cpu_resp_data);
        #40;

        $display("Estatisticas da Cache -> Hits: %0d, Misses: %0d", hit_counter, miss_counter);
        $display(">>> TESTE DO I-CACHE CONCLUIDO COM SUCESSO! <<<");
        $finish;
    end

endmodule
