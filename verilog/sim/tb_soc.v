`timescale 1ns / 1ps

// ============================================================================
// Bancada de Testes Automatizada (Testbench) para o SoC RISC-V
// Simula a execucao do processador no Icarus Verilog (iverilog + vvp),
// decodifica a saida da UART em tempo real e monitora LEDs do GPIO
// ============================================================================
module tb_soc;

    reg         clk;
    reg         rst_n;
    reg         uart_rx;
    wire        uart_tx;
    reg  [31:0] gpio_in;
    wire [31:0] gpio_out;
    wire        vga_hsync;
    wire        vga_vsync;
    wire [3:0]  vga_r, vga_g, vga_b;

    // Instancia do SoC RISC-V Completo
    soc_top #(
        .DATA_WIDTH (32),
        .RAM_ADDR_W (15)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .uart_rx   (uart_rx),
        .uart_tx   (uart_tx),
        .gpio_in   (gpio_in),
        .gpio_out  (gpio_out),
        .vga_hsync (vga_hsync),
        .vga_vsync (vga_vsync),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b)
    );

    // Gerador de Clock de 50 MHz (Periodo de 20 ns)
    always #10 clk = ~clk;

    // Decodificador de UART na Simulacao para Exibir Saida no Terminal
    // 50 MHz clock / 434 baud divider = ~8680 ns por bit serial
    localparam BIT_PERIOD = 8680;
    reg [7:0] rx_char;
    integer i;

    always begin
        @(negedge uart_tx); // Espera borda de descida do start bit
        #(BIT_PERIOD + (BIT_PERIOD/2)); // Avanca para o meio do primeiro bit de dados
        for (i = 0; i < 8; i = i + 1) begin
            rx_char[i] = uart_tx;
            #BIT_PERIOD;
        end
        $write("%c", rx_char);
        $fflush();
    end

    // Inicializacao da Memoria com Programa de Teste
    initial begin
        // Instrucoes de Teste em Codigo de Maquina RISC-V RV32I:
        // 0x00: lui  x1, 0x10000       -> 0x100000b7 (x1 = 0x10000000, base UART)
        // 0x04: addi x2, x0, 0x52      -> 0x05200113 (x2 = 'R')
        // 0x08: sw   x2, 0(x1)         -> 0x0020a023 (Envia 'R' pela UART)
        // 0x0C: addi x2, x0, 0x56      -> 0x05600113 (x2 = 'V')
        // 0x10: sw   x2, 0(x1)         -> 0x0020a023 (Envia 'V' pela UART)
        // 0x14: lui  x3, 0x12000       -> 0x120001b7 (x3 = 0x12000000, base GPIO)
        // 0x18: addi x4, x0, 0x55      -> 0x05500213 (x4 = 0x55, padrao de LEDs)
        // 0x1C: sw   x4, 0(x3)         -> 0x0041a023 (Acende LEDs no GPIO)
        // 0x20: jal  x0, -8            -> 0xff9ff06f (Loop infinito)

        dut.u_ram.ram_b0[0] = 8'hb7; dut.u_ram.ram_b1[0] = 8'h00; dut.u_ram.ram_b2[0] = 8'h00; dut.u_ram.ram_b3[0] = 8'h10;
        dut.u_ram.ram_b0[1] = 8'h13; dut.u_ram.ram_b1[1] = 8'h01; dut.u_ram.ram_b2[1] = 8'h20; dut.u_ram.ram_b3[1] = 8'h05;
        dut.u_ram.ram_b0[2] = 8'h23; dut.u_ram.ram_b1[2] = 8'ha0; dut.u_ram.ram_b2[2] = 8'h20; dut.u_ram.ram_b3[2] = 8'h00;
        dut.u_ram.ram_b0[3] = 8'h13; dut.u_ram.ram_b1[3] = 8'h01; dut.u_ram.ram_b2[3] = 8'h60; dut.u_ram.ram_b3[3] = 8'h05;
        dut.u_ram.ram_b0[4] = 8'h23; dut.u_ram.ram_b1[4] = 8'ha0; dut.u_ram.ram_b2[4] = 8'h20; dut.u_ram.ram_b3[4] = 8'h00;
        dut.u_ram.ram_b0[5] = 8'hb7; dut.u_ram.ram_b1[5] = 8'h01; dut.u_ram.ram_b2[5] = 8'h00; dut.u_ram.ram_b3[5] = 8'h12;
        dut.u_ram.ram_b0[6] = 8'h13; dut.u_ram.ram_b1[6] = 8'h02; dut.u_ram.ram_b2[6] = 8'h50; dut.u_ram.ram_b3[6] = 8'h05;
        dut.u_ram.ram_b0[7] = 8'h23; dut.u_ram.ram_b1[7] = 8'ha0; dut.u_ram.ram_b2[7] = 8'h41; dut.u_ram.ram_b3[7] = 8'h00;
        dut.u_ram.ram_b0[8] = 8'h6f; dut.u_ram.ram_b1[8] = 8'hf0; dut.u_ram.ram_b2[8] = 8'h9f; dut.u_ram.ram_b3[8] = 8'hff;
    end

    // Sequencia de Simulacao
    initial begin
        $dumpfile("soc_waveform.vcd");
        $dumpvars(0, tb_soc);

        $display("=============================================================");
        $display("  INICIANDO SIMULACAO DO SOC RISC-V EM VERILOG (IVERILOG)");
        $display("=============================================================");

        clk     = 1'b0;
        rst_n   = 1'b0;
        uart_rx = 1'b1;
        gpio_in = 32'h00000000;

        // Reset de 100 ns
        #100;
        rst_n = 1'b1;
        $display("[%0t ns] Reset liberado. Processador RISC-V em execucao...", $time);

        // Aguarda transmissao de dados pela UART e atualizacao do GPIO
        #250000;

        $display("\n[%0t ns] Verificando Saida do GPIO...", $time);
        $display("GPIO LEDs Output: 0x%08X (Esperado: 0x00000055)", gpio_out);

        if (gpio_out == 32'h00000055) begin
            $display(">>> TESTE DE SIMULACAO DO SOC RISC-V: SUCESSO ABSOLUTO! <<<");
        end else begin
            $display(">>> TESTE DE SIMULACAO DO SOC RISC-V: FALHA <<<");
        end

        $display("=============================================================");
        $finish;
    end

endmodule
