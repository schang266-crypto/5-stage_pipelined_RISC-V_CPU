module decode_stage(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_flush,
    input  wire [31:0] i_instr,
    input wire  [4:0]  i_rd_id_ex,
    input wire         i_memread_id_ex,
    input wire  [4:0]  i_rd_mem_wb,
    input wire         i_regwrite,
    input wire  [31:0] i_write_data,
    input wire         i_bubble,
    output wire [31:0] o_imm,
    output wire        o_func7,
    output wire [2:0]  o_func3,
    output wire [4:0]  o_rd,
    output wire [4:0]  o_rs1,
    output wire [4:0]  o_rs2,
    output wire [31:0] o_read_data_1,
    output wire [31:0] o_read_data_2,
    output wire        o_pcwrite,
    output wire        o_regwrite,
    output wire        o_memtoreg,
    output wire        o_pctoreg,
    output wire        o_auipc,
    output wire        o_jump,
    output wire        o_branch,
    output wire        o_jalr,
    output wire        o_memread,
    output wire        o_memwrite,
    output wire [2:0]  o_aluop,
    output wire        o_alusrc,
    output wire        o_bubble
);
    wire [6:0]  opcode;
    wire haz;
    wire [4:0] rs1, rs2;
    wire nop_id_ex_reg;
    
    // Instruction Decode
    decoder i_inst_decoder(
        .i_instr(i_instr),
        .o_opcode(opcode),
        .o_func3(o_func3),
        .o_func7(o_func7),
        .o_rs1(rs1),
        .o_rs2(rs2),
        .o_rd(o_rd),
        .o_imm(o_imm)
    );
    // Control
    assign nop_id_ex_reg = i_flush | haz | i_bubble;
    assign o_bubble = nop_id_ex_reg;
    control u_control(
        .i_opcode(opcode),
        .i_nop(nop_id_ex_reg),
        .o_branch(o_branch),
        .o_jump(o_jump),
        .o_jalr(o_jalr),
        .o_regwrite(o_regwrite),
        .o_memtoreg(o_memtoreg),
        .o_alusrc(o_alusrc),
        .o_memread(o_memread),
        .o_memwrite(o_memwrite),
        .o_pctoreg(o_pctoreg),
        .o_auipc(o_auipc),
        .o_aluop(o_aluop)
    );

    // Register File
    rf #(.BYPASS_EN(1)) rf (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(rs1),
        .i_rs2_raddr(rs2),
        .i_rd_waddr(i_rd_mem_wb),
        .i_rd_wdata(i_write_data),
        .i_rd_wen(i_regwrite),
        .o_rs1_rdata(o_read_data_1),
        .o_rs2_rdata(o_read_data_2)
    );
    assign o_rs1 = rs1;
    assign o_rs2 = rs2;

    // Hazard Detection Unit
    hazard_detection_unit u_hazard (
        .MemRead_ID_EX(i_memread_id_ex), // when 1, instruction in EX stage is a load
        .RD_ID_EX(i_rd_id_ex),
        .RS1_IF_ID(rs1),
        .RS2_IF_ID(rs2),
        .PCWrite(o_pcwrite),    // when 0, freeze PC (stall fetch)
        .Haz(haz)  // when 1, flush the ID/EX pipeline register 
    );
endmodule