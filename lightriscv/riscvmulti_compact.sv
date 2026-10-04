// ==============================================================================
// riscvmulti_compact.sv - Processador RISC-V Multiciclo Monolítico
//
// Implementação sugerida pelo Prof. Ricardo Menotti (UFSCar) no minuto 37:29
// (https://www.youtube.com/watch?v=X7HwhFXKtaY&t=2249s):
//
// "Um exercício muito legal seria vocês pegarem o código do monociclo
//  e transformar ele em multiciclo, ou seja, colocar só a máquina de estados
//  lá, mas manter aquela estrutura mais monolítica... em vez de ter vários
//  módulos aqui porque esses módulos tornam o código muito verboso...
//  o formato monolítico igual do monociclo, senão vai ficar bem menor."
//
// Diferenciais desta implementação:
//  - Arquitetura Von Neumann unificada (1 barramento de memória para dados e código)
//  - FSM explícita e legível (sem vetores de controle de 16 bits concatenados)
//  - Banco de 32 registradores e ALU integrados diretamente
//  - Eliminação de 6 submódulos intermediários redundantes
// ==============================================================================

module riscvmulti_compact(
    input  logic        clk,
    input  logic        reset,
    output logic [31:0] adr,
    output logic [31:0] writedata,
    output logic        memwrite,
    input  logic [31:0] readdata
);

    // Estados da FSM do Multiciclo
    localparam [3:0]
        S_FETCH   = 4'b0000, // 0: Busca instrução da memória
        S_DECODE  = 4'b0001, // 1: Decodifica e lê banco de registradores
        S_MEMADR  = 4'b0010, // 2: Calcula endereço efetivo de memória (LW/SW)
        S_MEMRD   = 4'b0011, // 3: Leitura de dados da memória (LW)
        S_MEMWB   = 4'b0100, // 4: Escrita de dados no registrador de destino (LW)
        S_MEMWR   = 4'b0101, // 5: Escrita de dados na memória (SW)
        S_RTYPEEX = 4'b0110, // 6: Execução de operação R-type na ALU
        S_RTYPEWB = 4'b0111, // 7: Escrita do resultado R-type no registrador
        S_BEQEX   = 4'b1000, // 8: Avaliação e salto condicional (BEQ/BNE)
        S_ADDIEX  = 4'b1001, // 9: Execução de operação imediata (ADDI) na ALU
        S_ADDIWB  = 4'b1010, // 10: Escrita do resultado I-type no registrador
        S_JEX     = 4'b1011; // 11: Salto incondicional JAL/JALR

    // Opcodes RISC-V RV32I
    localparam [6:0]
        OP_LOAD   = 7'b0000011, // lw
        OP_STORE  = 7'b0100011, // sw
        OP_RTYPE  = 7'b0110011, // add, sub, and, or, slt...
        OP_BRANCH = 7'b1100011, // beq, bne...
        OP_IMM    = 7'b0010011, // addi, andi...
        OP_JAL    = 7'b1101111, // jal
        OP_JALR   = 7'b1100111, // jalr
        OP_LUI    = 7'b0110111, // lui
        OP_AUIPC  = 7'b0010111; // auipc

    // Registradores internos de pipeline de estado
    logic [3:0]  state, nextstate;
    logic [31:0] PC, PCA;
    logic [31:0] Instr;
    logic [31:0] Data;
    logic [31:0] A, B;
    logic [31:0] ALUOut;

    // Banco de Registradores (32 x 32 bits)
    logic [31:0] RegisterFile [0:31];

    // Decodificação de campos da instrução
    wire [6:0] op     = Instr[6:0];
    wire [4:0] rd     = Instr[11:7];
    wire [2:0] funct3 = Instr[14:12];
    wire [4:0] rs1    = Instr[19:15];
    wire [4:0] rs2    = Instr[24:20];
    wire [6:0] funct7 = Instr[31:25];

    // Formatos de Imediatos (RV32I)
    wire [31:0] ImmI = {{20{Instr[31]}}, Instr[31:20]};
    wire [31:0] ImmS = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
    wire [31:0] ImmB = {{19{Instr[31]}}, Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0};
    wire [31:0] ImmU = {Instr[31:12], 12'b0};
    wire [31:0] ImmJ = {{19{Instr[31]}}, Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0};

    // Leitura combinacional do banco de registradores (x0 sempre 0)
    wire [31:0] rf_rd1 = (rs1 != 5'b0) ? RegisterFile[rs1] : 32'b0;
    wire [31:0] rf_rd2 = (rs2 != 5'b0) ? RegisterFile[rs2] : 32'b0;

    // Entradas e Operações da ALU
    logic [31:0] SrcA, SrcB;
    logic [2:0]  alucontrol;
    logic [31:0] ALUResult;
    wire         zero;

    wire funct7_sub = funct7[5];

    // Multiplexação de entradas da ALU
    always @* begin
        case (state)
            S_FETCH: begin
                SrcA = PC;
                SrcB = 32'd4;
                alucontrol = 3'b010; // ADD (PC + 4)
            end
            S_DECODE: begin
                SrcA = PCA;
                SrcB = ImmB; // Pré-cálculo do endereço de branch (PCA + Bimm)
                alucontrol = 3'b010; // ADD
            end
            S_MEMADR: begin
                SrcA = A;
                SrcB = (op == OP_STORE) ? ImmS : ImmI;
                alucontrol = 3'b010; // ADD (base + offset)
            end
            S_RTYPEEX: begin
                SrcA = A;
                SrcB = B;
                // Decodificação de função ALU para R-type
                case (funct3)
                    3'b000:  alucontrol = funct7_sub ? 3'b110 : 3'b010; // SUB : ADD
                    3'b111:  alucontrol = 3'b000; // AND
                    3'b110:  alucontrol = 3'b001; // OR
                    3'b010:  alucontrol = 3'b111; // SLT
                    default: alucontrol = 3'b010;
                endcase
            end
            S_ADDIEX: begin
                SrcA = A;
                SrcB = ImmI;
                alucontrol = 3'b010; // ADD (rs1 + ImmI)
            end
            S_BEQEX: begin
                SrcA = A;
                SrcB = B;
                alucontrol = 3'b110; // SUB (comparação para branch)
            end
            S_JEX: begin
                SrcA = PCA;
                SrcB = ImmJ; // PCA + Jimm
                alucontrol = 3'b010; // ADD
            end
            default: begin
                SrcA = A;
                SrcB = B;
                alucontrol = 3'b010;
            end
        endcase
    end

    // Unidade Aritmética e Lógica (ALU)
    wire [31:0] condinvb = alucontrol[2] ? ~SrcB : SrcB;
    wire [31:0] sum      = SrcA + condinvb + alucontrol[2];

    always @* begin
        case (alucontrol)
            3'b000, 3'b100: ALUResult = SrcA & SrcB;
            3'b001, 3'b101: ALUResult = SrcA | SrcB;
            3'b010, 3'b110: ALUResult = sum;
            3'b011, 3'b111: ALUResult = {31'b0, sum[31]};
        endcase
    end

    assign zero = (ALUResult == 32'b0);

    // Próximo estado da FSM
    always_comb begin
        case (state)
            S_FETCH:   nextstate = S_DECODE;
            S_DECODE:  case (op)
                           OP_LOAD:   nextstate = S_MEMADR;
                           OP_STORE:  nextstate = S_MEMADR;
                           OP_RTYPE:  nextstate = S_RTYPEEX;
                           OP_BRANCH: nextstate = S_BEQEX;
                           OP_IMM:    nextstate = S_ADDIEX;
                           OP_JAL:    nextstate = S_JEX;
                           default:   nextstate = S_FETCH;
                       endcase
            S_MEMADR:  nextstate = (op == OP_LOAD) ? S_MEMRD : S_MEMWR;
            S_MEMRD:   nextstate = S_MEMWB;
            S_MEMWB:   nextstate = S_FETCH;
            S_MEMWR:   nextstate = S_FETCH;
            S_RTYPEEX: nextstate = S_RTYPEWB;
            S_RTYPEWB: nextstate = S_FETCH;
            S_ADDIEX:  nextstate = S_ADDIWB;
            S_ADDIWB:  nextstate = S_FETCH;
            S_BEQEX:   nextstate = S_FETCH;
            S_JEX:     nextstate = S_FETCH;
            default:   nextstate = S_FETCH;
        endcase
    end

    // Interface com o Barramento de Memória Unificado
    assign adr       = (state == S_FETCH) ? PC : ALUOut;
    assign writedata = B;
    assign memwrite  = (state == S_MEMWR);

    // Registradores síncronos de controle e dados
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state   <= S_FETCH;
            PC      <= 32'b0;
            PCA     <= 32'b0;
            Instr   <= 32'b0;
            Data    <= 32'b0;
            A       <= 32'b0;
            B       <= 32'b0;
            ALUOut  <= 32'b0;
        end else begin
            state <= nextstate;

            case (state)
                S_FETCH: begin
                    Instr <= readdata;
                    PCA   <= PC;
                    PC    <= ALUResult; // PC + 4
                end
                S_DECODE: begin
                    A      <= rf_rd1;
                    B      <= rf_rd2;
                    ALUOut <= ALUResult; // PCA + Bimm
                end
                S_MEMADR: begin
                    ALUOut <= ALUResult; // Endereço efetivo
                end
                S_MEMRD: begin
                    Data <= readdata;
                end
                S_MEMWB: begin
                    if (rd != 5'b0)
                        RegisterFile[rd] <= Data;
                end
                S_RTYPEEX, S_ADDIEX: begin
                    ALUOut <= ALUResult;
                end
                S_RTYPEWB, S_ADDIWB: begin
                    if (rd != 5'b0)
                        RegisterFile[rd] <= ALUOut;
                end
                S_BEQEX: begin
                    if (zero) // Salto tomado
                        PC <= ALUOut; // Destino já calculado em S_DECODE
                end
                S_JEX: begin
                    if (rd != 5'b0)
                        RegisterFile[rd] <= PC; // PC+4 (salva link)
                    PC <= ALUResult; // Destino do salto JAL
                end
                default: ;
            endcase
        end
    end

endmodule
