`default_nettype none

module alu (
    input wire [3:0] i_aluctrl,
    input wire [31:0] i_op1,
    input wire [31:0] i_op2,
    output wire [31:0] o_result,
    output wire o_br_true
);
    wire [31:0] right_shift;
    wire [31:0] left_shift;
    wire arith;
    wire op1_sign;
    wire op2_sign;
    wire lt_signed;

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

    assign op1_sign = i_op1[31];
    assign op2_sign = i_op2[31];
    assign arith = (i_aluctrl == 4'b0111);
    right_shifter alu_right_shifter(.A(i_op1), .B(i_op2[4:0]), .Arith(arith), .Out(right_shift));   
    left_shifter alu_left_shifter(.A(i_op1), .B(i_op2[4:0]), .Out(left_shift));
    less_than_32b_signed alu_lts(.A(i_op1), .B(i_op2), .LT(lt_signed));

    assign o_result = (i_aluctrl == ALU_ADD)     ? i_op1 + i_op2 :
                      (i_aluctrl == ALU_SUB)     ? i_op1 - i_op2 :  
                      (i_aluctrl == ALU_AND)     ? i_op1 & i_op2 :
                      (i_aluctrl == ALU_OR)      ? i_op1 | i_op2 :
                      (i_aluctrl == ALU_XOR)     ? i_op1 ^ i_op2 :
                      (i_aluctrl == ALU_SLL)     ? left_shift :
                      (i_aluctrl == ALU_SRL)     ? right_shift :
                      (i_aluctrl == ALU_SRA)     ? right_shift : 
                      (i_aluctrl == ALU_SLT)     ?  lt_signed :
                      (i_aluctrl == ALU_SLTU)    ?  i_op1 < i_op2 :
                      (i_aluctrl == ALU_PASS_B)  ? i_op2 : 
                      (i_aluctrl == ALU_EQUAL)   ? i_op1 == i_op2 :
                      (i_aluctrl == ALU_NEQUAL)  ? i_op1 != i_op2 :
                      (i_aluctrl == ALU_SGTE)    ? ~lt_signed :
                      (i_aluctrl == ALU_SGTEU)   ? i_op1 >= i_op2 :
                                                   32'bx;
    assign o_br_true = (o_result == 1'b1);
endmodule

module less_than_32b_signed (
    input wire [31:0] A, 
    input wire [31:0] B,
    output wire LT
);

    wire [31:0] D;
    wire overflow;

    assign D = A-B;
    assign overflow = (A[31] ^ B[31]) & (A[31] ^ D[31]);
    assign LT = D[31] ^ overflow;
endmodule

module right_shifter(
    input wire [31:0] A, 
    input wire [4:0] B, 
    input wire Arith,
    output wire [31:0] Out
);

    wire [31:0] shift1, shift2, shift4, shift8, shift16;
    wire shift_in;

    assign shift_in = Arith & A[31];
    assign shift1 = (B[0]) ? {shift_in, A[31:1]} : A;
    assign shift2 = (B[1]) ? {{2{shift_in}}, shift1[31:2]} : shift1;
    assign shift4 = (B[2]) ? {{4{shift_in}}, shift2[31:4]} : shift2;
    assign shift8  = (B[3]) ? {{8{shift_in}},  shift4[31:8]}  : shift4;
    assign shift16 = (B[4]) ? {{16{shift_in}}, shift8[31:16]} : shift8;
    assign Out = shift16;
endmodule

module left_shifter(
    input wire [31:0] A, 
    input wire [4:0] B, 
    output wire [31:0] Out
);

    wire [31:0] shift1, shift2, shift4, shift8, shift16;

    assign shift1 = (B[0]) ? A << 1 : A;
    assign shift2 = (B[1]) ? shift1 << 2 : shift1;
    assign shift4 = (B[2]) ? shift2 << 4 : shift2;
    assign shift8  = (B[3]) ? shift4 << 8 : shift4;
    assign shift16 = (B[4]) ? shift8 << 16 : shift8;
    assign Out = shift16;
endmodule
`default_nettype wire
