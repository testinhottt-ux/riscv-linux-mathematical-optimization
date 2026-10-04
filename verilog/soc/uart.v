`timescale 1ns / 1ps

// ============================================================================
// Controlador Serial UART 8N1 Sintetizavel para Console RISC-V no FPGA
// Registradores:
//   Offset 0x00: DATA (Escrita = Transmite caractere, Leitura = Recebe caractere)
//   Offset 0x04: STATUS (Bit 0: RX pronto, Bit 1: TX ocupado)
//   Offset 0x08: BAUD_DIV (Divisor de Clock para Baud Rate)
// ============================================================================
module uart #(
    parameter DEFAULT_BAUD_DIV = 434 // 50MHz / 115200 baud = ~434
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // Barramento de Acesso
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        we,
    input  wire        re,
    
    // Linhas Fisicas Seriais
    input  wire        rx,
    output reg         tx
);

    reg [15:0] baud_div;
    reg [7:0]  tx_data;
    reg        tx_start;
    wire       tx_busy;
    
    reg [7:0]  rx_buffer;
    reg        rx_ready;
    wire [7:0] rx_byte;
    wire       rx_valid;

    // Leitura dos Registradores
    always @(*) begin
        case (addr[3:0])
            4'h0: rdata = {24'd0, rx_buffer};
            4'h4: rdata = {30'd0, tx_busy, rx_ready};
            4'h8: rdata = {16'd0, baud_div};
            default: rdata = 32'd0;
        endcase
    end

    // Escrita nos Registradores
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_div  <= DEFAULT_BAUD_DIV;
            tx_data   <= 8'd0;
            tx_start  <= 1'b0;
            rx_ready  <= 1'b0;
            rx_buffer <= 8'd0;
        end else begin
            tx_start <= 1'b0;
            
            if (rx_valid) begin
                rx_buffer <= rx_byte;
                rx_ready  <= 1'b1;
            end

            if (re && (addr[3:0] == 4'h0)) begin
                rx_ready <= 1'b0; // Limpa flag de recepcao ao ler
            end

            if (we) begin
                case (addr[3:0])
                    4'h0: begin
                        tx_data  <= wdata[7:0];
                        tx_start <= 1'b1;
                    end
                    4'h8: begin
                        baud_div <= wdata[15:0];
                    end
                    default: ;
                endcase
            end
        end
    end

    // ------------------------------------------------------------------------
    // TRANSMISSOR SERIAL (TX FSM)
    // ------------------------------------------------------------------------
    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA  = 2'd2;
    localparam TX_STOP  = 2'd3;

    reg [1:0]  tx_state;
    reg [15:0] tx_clk_cnt;
    reg [2:0]  tx_bit_idx;
    reg [7:0]  tx_shift;

    assign tx_busy = (tx_state != TX_IDLE) || tx_start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state   <= TX_IDLE;
            tx_clk_cnt <= 16'd0;
            tx_bit_idx <= 3'd0;
            tx_shift   <= 8'd0;
            tx         <= 1'b1; // Linha idle em nivel alto
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        tx_shift   <= tx_data;
                        tx_clk_cnt <= 16'd0;
                        tx_state   <= TX_START;
                    end
                end

                TX_START: begin
                    tx <= 1'b0; // Start bit
                    if (tx_clk_cnt < baud_div - 1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end else begin
                        tx_clk_cnt <= 16'd0;
                        tx_bit_idx <= 3'd0;
                        tx_state   <= TX_DATA;
                    end
                end

                TX_DATA: begin
                    tx <= tx_shift[tx_bit_idx];
                    if (tx_clk_cnt < baud_div - 1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end else begin
                        tx_clk_cnt <= 16'd0;
                        if (tx_bit_idx < 3'd7) begin
                            tx_bit_idx <= tx_bit_idx + 1'b1;
                        end else begin
                            tx_state <= TX_STOP;
                        end
                    end
                end

                TX_STOP: begin
                    tx <= 1'b1; // Stop bit
                    if (tx_clk_cnt < baud_div - 1) begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end else begin
                        tx_clk_cnt <= 16'd0;
                        tx_state   <= TX_IDLE;
                    end
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // RECEPTOR SERIAL (RX FSM)
    // ------------------------------------------------------------------------
    // Filtro e sincronizador de entrada RX
    reg rx_sync1, rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync  <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync  <= rx_sync1;
        end
    end

    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [15:0] rx_clk_cnt;
    reg [2:0]  rx_bit_idx;
    reg [7:0]  rx_shift;
    reg        rx_valid_reg;

    assign rx_valid = rx_valid_reg;
    assign rx_byte  = rx_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state     <= RX_IDLE;
            rx_clk_cnt   <= 16'd0;
            rx_bit_idx   <= 3'd0;
            rx_shift     <= 8'd0;
            rx_valid_reg <= 1'b0;
        end else begin
            rx_valid_reg <= 1'b0;

            case (rx_state)
                RX_IDLE: begin
                    if (!rx_sync) begin // Deteccao de borda de descida do start bit
                        rx_clk_cnt <= 16'd0;
                        rx_state   <= RX_START;
                    end
                end

                RX_START: begin
                    // Amostragem no meio do bit de start
                    if (rx_clk_cnt == (baud_div >> 1)) begin
                        if (!rx_sync) begin
                            rx_clk_cnt <= 16'd0;
                            rx_bit_idx <= 3'd0;
                            rx_state   <= RX_DATA;
                        end else begin
                            rx_state   <= RX_IDLE; // Falso start
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (rx_clk_cnt < baud_div - 1) begin
                        rx_clk_cnt <= rx_clk_cnt + 1'b1;
                    end else begin
                        rx_clk_cnt <= 16'd0;
                        rx_shift[rx_bit_idx] <= rx_sync;
                        if (rx_bit_idx < 3'd7) begin
                            rx_bit_idx <= rx_bit_idx + 1'b1;
                        end else begin
                            rx_state <= RX_STOP;
                        end
                    end
                end

                RX_STOP: begin
                    if (rx_clk_cnt < baud_div - 1) begin
                        rx_clk_cnt <= rx_clk_cnt + 1'b1;
                    end else begin
                        rx_clk_cnt   <= 16'd0;
                        rx_valid_reg <= 1'b1;
                        rx_state     <= RX_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
