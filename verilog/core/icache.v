`timescale 1ns / 1ps
// ============================================================================
// Instruction Cache (I-Cache) Direto / Modular para Processador RISC-V
// - Arquitetura: Mapeamento Direto com suporte a BRAM inferida em FPGA
// - Capacidade Padrao: 4 KB (1024 linhas x 32 bits por linha)
// - Latencia de Hit: 1 ciclo de clock
// - Tratamento de Miss transparente com stall do pipeline
// ============================================================================

module icache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CACHE_LINES = 1024, // 1024 palavras de 32 bits = 4 KB
    parameter INDEX_BITS  = 10,   // log2(1024) = 10
    parameter OFFSET_BITS = 2,    // 4 bytes por palavra = 2 bits (bits [1:0])
    parameter TAG_BITS    = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS // 32 - 10 - 2 = 20 bits
)(
    input  wire                   clk,
    input  wire                   rst_n,
    
    // Interface com o Core RISC-V (Instruction Fetch)
    input  wire [ADDR_WIDTH-1:0]  cpu_req_addr,
    input  wire                   cpu_req_valid,
    output wire [DATA_WIDTH-1:0]  cpu_resp_data,
    output wire                   cpu_resp_valid,
    output wire                   cache_stall,
    
    // Interface com a Memoria Principal / Interconnect (Wishbone / AXI / Mem)
    output reg  [ADDR_WIDTH-1:0]  mem_req_addr,
    output reg                    mem_req_valid,
    input  wire [DATA_WIDTH-1:0]  mem_resp_data,
    input  wire                   mem_resp_valid,
    
    // Manutencao e Estatisticas
    input  wire                   flush_req,
    output reg  [31:0]            hit_counter,
    output reg  [31:0]            miss_counter
);

    // Campos de Enderecamento:
    // [31 : 12] -> Tag (20 bits)
    // [11 : 2]  -> Index (10 bits)
    // [1 : 0]   -> Byte Offset (2 bits)
    wire [TAG_BITS-1:0]   req_tag   = cpu_req_addr[ADDR_WIDTH-1 : INDEX_BITS + OFFSET_BITS];
    wire [INDEX_BITS-1:0] req_index = cpu_req_addr[INDEX_BITS + OFFSET_BITS - 1 : OFFSET_BITS];

    // Matriz de Armazenamento da Cache:
    // 1. Array de Dados (BRAM)
    reg [DATA_WIDTH-1:0] data_mem [0:CACHE_LINES-1];
    // 2. Array de Tags
    reg [TAG_BITS-1:0]   tag_mem  [0:CACHE_LINES-1];
    // 3. Array de Bits de Validade
    reg                  valid_mem[0:CACHE_LINES-1];

    // Estados da FSM do I-Cache
    localparam STATE_IDLE    = 2'b00;
    localparam STATE_LOOKUP  = 2'b01;
    localparam STATE_REFILL  = 2'b10;
    localparam STATE_FLUSH   = 2'b11;

    reg [1:0] current_state, next_state;
    reg [INDEX_BITS-1:0] flush_idx;

    // Registrador de Endereco da Requisicao em Curso
    reg [ADDR_WIDTH-1:0] latched_addr;
    wire [TAG_BITS-1:0]   latched_tag   = latched_addr[ADDR_WIDTH-1 : INDEX_BITS + OFFSET_BITS];
    wire [INDEX_BITS-1:0] latched_index = latched_addr[INDEX_BITS + OFFSET_BITS - 1 : OFFSET_BITS];

    // Leitura Sincrona da Tag e Dados
    reg [DATA_WIDTH-1:0] cache_rdata;
    reg [TAG_BITS-1:0]   cache_rtag;
    reg                  cache_rvalid;

    always @(posedge clk) begin
        cache_rdata  <= data_mem[req_index];
        cache_rtag   <= tag_mem[req_index];
        cache_rvalid <= valid_mem[req_index];
    end

    // Deteccao de Hit / Miss
    wire is_hit = cache_rvalid && (cache_rtag == latched_tag);

    // FSM de Controle de Cache
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_FLUSH;
            flush_idx     <= {INDEX_BITS{1'b0}};
            latched_addr  <= {ADDR_WIDTH{1'b0}};
            hit_counter   <= 32'd0;
            miss_counter  <= 32'd0;
        end else begin
            current_state <= next_state;
            
            if (flush_req) begin
                current_state <= STATE_FLUSH;
                flush_idx     <= {INDEX_BITS{1'b0}};
            end
            
            case (current_state)
                STATE_IDLE: begin
                    if (cpu_req_valid) begin
                        latched_addr <= cpu_req_addr;
                    end
                end
                
                STATE_LOOKUP: begin
                    if (is_hit) begin
                        hit_counter <= hit_counter + 1'b1;
                        if (cpu_req_valid) begin
                            latched_addr <= cpu_req_addr;
                        end
                    end else begin
                        miss_counter <= miss_counter + 1'b1;
                    end
                end
                
                STATE_REFILL: begin
                    if (mem_resp_valid) begin
                        // Grava dados recem-buscados na linha da Cache
                        data_mem[latched_index]  <= mem_resp_data;
                        tag_mem[latched_index]   <= latched_tag;
                        valid_mem[latched_index] <= 1'b1;
                    end
                end
                
                STATE_FLUSH: begin
                    valid_mem[flush_idx] <= 1'b0;
                    flush_idx <= flush_idx + 1'b1;
                end
            endcase
        end
    end

    // Transicao de Estados e Saidas da FSM
    always @(*) begin
        next_state    = current_state;
        mem_req_valid = 1'b0;
        mem_req_addr  = latched_addr;

        case (current_state)
            STATE_FLUSH: begin
                if (flush_idx == {INDEX_BITS{1'b1}}) begin
                    next_state = STATE_IDLE;
                end else begin
                    next_state = STATE_FLUSH;
                end
            end

            STATE_IDLE: begin
                if (cpu_req_valid) begin
                    next_state = STATE_LOOKUP;
                end
            end

            STATE_LOOKUP: begin
                if (is_hit) begin
                    if (cpu_req_valid)
                        next_state = STATE_LOOKUP;
                    else
                        next_state = STATE_IDLE;
                end else begin
                    // Cache Miss: Solicita dado da memoria principal
                    next_state = STATE_REFILL;
                end
            end

            STATE_REFILL: begin
                mem_req_valid = 1'b1;
                mem_req_addr  = latched_addr;
                if (mem_resp_valid) begin
                    next_state = STATE_LOOKUP;
                end
            end
        endcase
    end

    // Saidas para a CPU
    assign cpu_resp_data  = is_hit ? cache_rdata : mem_resp_data;
    assign cpu_resp_valid = (current_state == STATE_LOOKUP && is_hit) || 
                            (current_state == STATE_REFILL && mem_resp_valid);
    assign cache_stall    = (current_state == STATE_LOOKUP && !is_hit) || 
                            (current_state == STATE_REFILL) || 
                            (current_state == STATE_FLUSH);

endmodule
