`timescale 1ns / 1ps

// ============================================================================
// Temporizador de Hardware CLINT (Core Local Interruptor) RISC-V
// Implementa contadores de 64 bits: mtime e mtimecmp.
// Dispara interrupcao de temporizacao (MTIP) quando mtime >= mtimecmp.
// Essencial para sistemas operacionais (Linux / RTOS) e medicao precisa de tempo.
// ============================================================================
module clint_timer (
    input  wire        clk,
    input  wire        rst_n,
    
    // Barramento de Acesso de Memoria
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        we,
    
    // Linha de Interrupcao de Timer para o Core RISC-V
    output wire        timer_irq
);

    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    // Dispara interrupcao de maquina quando mtime alcanca ou ultrapassa mtimecmp
    assign timer_irq = (mtime >= mtimecmp);

    // Leitura dos registradores
    always @(*) begin
        case (addr[3:2])
            2'b00: rdata = mtime[31:0];       // 0x00
            2'b01: rdata = mtime[63:32];      // 0x04
            2'b10: rdata = mtimecmp[31:0];    // 0x08
            2'b11: rdata = mtimecmp[63:32];   // 0x0C
            default: rdata = 32'd0;
        endcase
    end

    // Atualizacao e escrita
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime    <= 64'd0;
            mtimecmp <= 64'hFFFFFFFFFFFFFFFF; // Inicialmente desativado (teto)
        end else begin
            // Incremento permanente a cada ciclo de clock
            mtime <= mtime + 1'b1;

            if (we) begin
                case (addr[3:2])
                    2'b00: mtime[31:0]      <= wdata;
                    2'b01: mtime[63:32]     <= wdata;
                    2'b10: mtimecmp[31:0]   <= wdata;
                    2'b11: mtimecmp[63:32]  <= wdata;
                    default: ;
                endcase
            end
        end
    end

endmodule
