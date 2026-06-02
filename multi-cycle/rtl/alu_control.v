module alu_control (
    input wire [2:0] i_aluop,
    input wire [2:0] i_func3,
    input wire i_func7,
    output wire [3:0] o_aluctrl
);

    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SLL = 4'b0101;
    localparam ALU_SRL = 4'b0110;
    localparam ALU_SRA = 4'b0111;
    localparam ALU_SLT = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_PASS_B = 4'b1010;
    localparam ALU_EQUAL = 4'b1011;
    localparam ALU_NEQUAL = 4'b1100;
    localparam ALU_SGTE = 4'b1101;
    localparam ALU_SGTEU = 4'b1110;

    assign o_aluctrl = (i_aluop == 3'b010) ? ( 
                           (i_func3 == 3'b000) ? (i_func7 ? ALU_SUB : ALU_ADD) :
                           (i_func3 == 3'b001) ? ALU_SLL :
                           (i_func3 == 3'b010) ? ALU_SLT :
                           (i_func3 == 3'b011) ? ALU_SLTU :
                           (i_func3 == 3'b100) ? ALU_XOR :
                           (i_func3 == 3'b101) ? (i_func7 ? ALU_SRA : ALU_SRL) :
                           (i_func3 == 3'b110) ? ALU_OR :
                           (i_func3 == 3'b111) ? ALU_AND :
                           4'bx
                        ) :
                        (i_aluop == 3'b100) ? ( 
                           (i_func3 == 3'b000) ? ALU_EQUAL :
                           (i_func3 == 3'b001) ? ALU_NEQUAL :
                           (i_func3 == 3'b100) ? ALU_SLT :
                           (i_func3 == 3'b101) ? ALU_SGTE :
                           (i_func3 == 3'b110) ? ALU_SLTU :
                           (i_func3 == 3'b111) ? ALU_SGTEU :
                           4'bx
                        ) :
                        (i_aluop == 3'b000) ? ALU_ADD : 
                        (i_aluop == 3'b001) ? ALU_SUB :
                        (i_aluop == 3'b011) ? ALU_PASS_B :
                        4'bx;
endmodule