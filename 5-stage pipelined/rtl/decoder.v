module decoder (
    input wire [31:0]  i_instr,
    output wire [6:0]  o_opcode,
    output wire        o_func7,
    output wire [2:0]  o_func3,
    output wire [4:0]  o_rs1,
    output wire [4:0]  o_rs2,
    output wire [4:0]  o_rd,
    output wire [31:0] o_imm
);
    wire [5:0] format; // Local format passed into sub modules
    format_decode iFD(i_instr, o_opcode, o_func3, o_func7, format);
    r_decode iRD(i_instr, format, o_rs1, o_rs2, o_rd); 
    imm_decode iID(i_instr, format, o_imm);
endmodule

module format_decode(
    input wire [31:0] i_instr,
    output wire [6:0] o_opcode,
    output wire [2:0] o_func3,
    output wire o_func7,
    output wire[5:0] o_format
);
    // Instruction 1 hot encoding
    localparam R_TYPE = 6'b000001;
    localparam I_TYPE = 6'b000010;
    localparam S_TYPE = 6'b000100;
    localparam B_TYPE = 6'b001000;
    localparam U_TYPE = 6'b010000;
    localparam J_TYPE = 6'b100000;

    wire [6:0] opcode;
    wire [5:0] format;
    assign opcode = i_instr[6:0];
    assign format = (opcode == 7'b011_0011) ? R_TYPE :
                    (opcode == 7'b001_0011) ? I_TYPE :
                    (opcode == 7'b011_0111) ? U_TYPE :
                    (opcode == 7'b001_0111) ? U_TYPE :
                    (opcode == 7'b000_0011) ? I_TYPE :
                    (opcode == 7'b010_0011) ? S_TYPE :
                    (opcode == 7'b110_0011) ? B_TYPE :
                    (opcode == 7'b110_1111) ? J_TYPE :
                    (opcode == 7'b110_0111) ? I_TYPE :
                                              32'bx; // Error
    assign o_opcode = opcode;
    assign o_func3  = (format == R_TYPE | format == I_TYPE | format == B_TYPE | format == S_TYPE) ? i_instr[14:12] : 3'bz;  
    assign o_func7  = (format == R_TYPE) ? i_instr[30] : 
                      ((format == I_TYPE) & (i_instr[14:12] === 3'b101)) ? i_instr[30] : // SRAI/SRLI
                      ((format == I_TYPE) & (i_instr[14:12] === 3'b000))  ? 0 : // ADDI
                                                               1'bz;
    assign o_format = format;
endmodule

module r_decode(
    input wire [31:0] i_instr,
    input wire [5:0] i_format,
    output wire [4:0] o_rs1,
    output wire [4:0] o_rs2,
    output wire [4:0] o_rd
);
    wire [4:0] rd, rs1, rs2;
    // Instruction 1 hot encoding
    localparam R_TYPE = 6'b000001;
    localparam I_TYPE = 6'b000010;
    localparam S_TYPE = 6'b000100;
    localparam B_TYPE = 6'b001000;
    localparam U_TYPE = 6'b010000;
    localparam J_TYPE = 6'b100000;

    assign rs1 = i_instr[19:15];
    assign rs2 = i_instr[24:20];

    assign rd = (i_format == R_TYPE | i_format == I_TYPE |
                 i_format == U_TYPE | i_format == J_TYPE) ?
                 i_instr[11:7] : 32'b0;
    assign o_rd = rd;
    assign o_rs1 = rs1;
    assign o_rs2 = rs2;
endmodule

module imm_decode (
    input  wire [31:0] i_instr,
    input  wire [ 5:0] i_format,
    output wire [31:0] o_immediate
);

    localparam R_TYPE = 6'b000001;
    localparam I_TYPE = 6'b000010;
    localparam S_TYPE = 6'b000100;
    localparam B_TYPE = 6'b001000;
    localparam U_TYPE = 6'b010000;
    localparam J_TYPE = 6'b100000;
    
    assign o_immediate = (i_format==I_TYPE) ? {{20{i_instr[31]}}, i_instr[31:20]} :
                         (i_format==S_TYPE) ? {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]} :
                         (i_format==B_TYPE) ? {{19{i_instr[31]}}, i_instr[31], i_instr[7], i_instr[30:25], i_instr[11:8], 1'b0} :
                         (i_format==U_TYPE) ? {i_instr[31:12], 12'b0} :
                         (i_format==J_TYPE) ? {{12{i_instr[31]}}, i_instr[19:12], i_instr[20], i_instr[30:25], i_instr[24:21], 1'b0} :
                        32'b0; // R type or Invalid
endmodule

`default_nettype wire
