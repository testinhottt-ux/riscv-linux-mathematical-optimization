`timescale 1ns / 1ps

// ============================================================================
// Controlador GPIO (General Purpose Input/Output) de 32 Bits para FPGA
// Registradores:
//   Offset 0x00: GPIO_OUT (Controla LEDs e pinos de saida da placa FPGA)
//   Offset 0x04: GPIO_IN  (Le chaves DIP, botoes e pinos de entrada da FPGA)
//   Offset 0x08: GPIO_DIR (Direcao: 1=Saida, 0=Entrada)
// ============================================================================
module gpio (
    input  wire        clk,
    input  wire        rst_n,
    
    // Barramento de Acesso de Memoria
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire        we,
    
    // Conexoes Externas com os Pinos da Placa FPGA
    input  wire [31:0] gpio_pins_in,
    output wire [31:0] gpio_pins_out
);

    reg [31:0] gpio_out_reg;
    reg [31:0] gpio_dir_reg;
    reg [31:0] gpio_in_sync1;
    reg [31:0] gpio_in_sync;

    assign gpio_pins_out = gpio_out_reg;

    // Sincronizador de entrada para evitar metaestabilidade
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_in_sync1 <= 32'd0;
            gpio_in_sync  <= 32'd0;
        end else begin
            gpio_in_sync1 <= gpio_pins_in;
            gpio_in_sync  <= gpio_in_sync1;
        end
    end

    // Leitura
    always @(*) begin
        case (addr[3:2])
            2'b00: rdata = gpio_out_reg;
            2'b01: rdata = gpio_in_sync;
            2'b10: rdata = gpio_dir_reg;
            default: rdata = 32'd0;
        endcase
    end

    // Escrita
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_out_reg <= 32'd0;
            gpio_dir_reg <= 32'hFFFFFFFF; // Todos como saida por padrao
        end else if (we) begin
            case (addr[3:2])
                2'b00: gpio_out_reg <= wdata;
                2'b10: gpio_dir_reg <= wdata;
                default: ;
            endcase
        end
    end

endmodule
