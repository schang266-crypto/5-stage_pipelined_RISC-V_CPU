module control (
    input wire [6:0] i_opcode,
    input wire  i_nop,
    output wire o_branch, 
    output wire o_jump, 
    output wire o_jalr,
    output wire o_regwrite,
    output wire o_memtoreg,
    output wire o_alusrc,
    output wire o_memread,
    output wire o_memwrite,
    output wire o_pctoreg,
    output wire o_auipc,
    output wire [2:0] o_aluop
);

    wire branch, jump, jalr, regwrite, memtoreg, memwrite, memread, alusrc, auipc, pctoreg;

    assign branch   = (i_opcode == 7'b110_0011); // 1 if branch, else 0
    assign jump     = (i_opcode == 7'b110_1111); // 1 if JAL else 0
    assign jalr     = (i_opcode == 7'b110_0111); // 1 if JALR else 0
    assign regwrite = !(i_opcode == 7'b010_0011 | i_opcode === 7'b110_0011); // 0 if store or branch, 1 else
    assign memtoreg = (i_opcode == 7'b000_0011); // 1 if load, 0 else
    assign memwrite = (i_opcode == 7'b010_0011); // 1 if store, 0 else
    assign memread  = (i_opcode == 7'b000_0011); // 1 if load, 0 else
    assign alusrc   = (i_opcode != 7'b011_0011 & i_opcode !== 7'b110_0011); // 0 if R TYPE or B Type, 1 else
    assign auipc    = (i_opcode == 7'b001_0111); // 1 if auipc, 0 else
    assign pctoreg  = (i_opcode == 7'b110_1111) | (i_opcode === 7'b110_0111); // 1 if JAL/JALR else 0

    assign o_branch   = (i_nop) ? 0 : branch  ;
    assign o_jump     = (i_nop) ? 0 : jump    ;
    assign o_jalr     = (i_nop) ? 0 : jalr    ;
    assign o_regwrite = (i_nop) ? 0 : regwrite;
    assign o_memtoreg = (i_nop) ? 0 : memtoreg; 
    assign o_memwrite = (i_nop) ? 0 : memwrite;
    assign o_memread  = (i_nop) ? 0 : memread ;
    assign o_alusrc   = (i_nop) ? 0 : alusrc  ;
    assign o_auipc    = (i_nop) ? 0 : auipc   ; 
    assign o_pctoreg  = (i_nop) ? 0 : pctoreg ;

    /*
    000 : ADD
    001 : DECODE 
    010 : SUB
    011 : PASS 2nd Operand
    100 : DECODE BRANCH
    */
    assign o_aluop = (i_opcode == 7'b011_0011) ? 3'b010 : // R Type
                     (i_opcode == 7'b000_0011) ? 3'b000 : // I Type loads
                     (i_opcode == 7'b001_0011) ? 3'b010 : // Other I Type
                     (i_opcode == 7'b110_0111) ? 3'b000 : // JALR
                     (i_opcode == 7'b010_0011) ? 3'b000 : // S Type
                     (i_opcode == 7'b011_0111) ? 3'b011 : // U type 
                     (i_opcode == 7'b001_0111) ? 3'b000 : // AUIPC
                     (i_opcode == 7'b110_1111) ? 3'b011 : // JAL
                     (i_opcode == 7'b110_0011) ? 3'b100 : // B Type
                                                 3'bx; // Invalid
endmodule
