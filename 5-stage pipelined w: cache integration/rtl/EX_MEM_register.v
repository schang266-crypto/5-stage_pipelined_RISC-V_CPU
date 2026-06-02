module EX_MEM_register (
    input wire        i_clk,
    input wire        i_stall,
    input wire        i_rst,
    input wire [31:0] i_pc,
    input wire [31:0] i_pc_4,
    input wire [ 2:0] i_func3,
    input wire [31:0] i_register_data_2,
    input wire [31:0] i_result,
    input wire [ 4:0] i_rd,
    input wire [ 4:0] i_rs1,
    input wire [ 4:0] i_rs2,
    input wire [31:0] i_read_data_1,
    input wire [31:0] i_read_data_2,
    input wire [31:0] i_next_pc,
    input wire [31:0] i_instr,
    input wire        i_regwrite,
    input wire        i_memtoreg,
    input wire        i_pctoreg,
    input wire        i_memread,
    input wire        i_memwrite,
    input wire        i_branch,
    input wire        i_bubble,

    output reg [31:0] o_pc,
    output reg [31:0] o_pc_4,
    output reg [ 2:0] o_func3,
    output reg [31:0] o_register_data_2,
    output reg [31:0] o_result,
    output reg [ 4:0] o_rd,
    output reg [ 4:0] o_rs1,
    output reg [ 4:0] o_rs2,
    output reg [31:0] o_read_data_1,
    output reg [31:0] o_read_data_2,
    output reg [31:0] o_next_pc,
    output reg [31:0] o_instr,
    output reg        o_regwrite,
    output reg        o_memtoreg,
    output reg        o_pctoreg,
    output reg        o_memread,
    output reg        o_memwrite,
    output reg        o_branch,
    output reg        o_bubble
);

  always @(posedge i_clk) begin
    if (i_rst) begin
      o_pc              <= 32'b0;
      o_pc_4            <= 32'b0;
      o_func3           <= 3'b0;
      o_register_data_2 <= 32'b0;
      o_result          <= 32'b0;
      o_rd              <= 5'b0;
      o_rs1             <= 5'b0;
      o_rs2             <= 5'b0;
      o_read_data_1     <= 32'b0;
      o_read_data_2     <= 32'b0;
      o_next_pc         <= 32'b0;
      o_instr           <= 32'b0;
      o_regwrite        <= 1'b0;
      o_memtoreg        <= 1'b0;
      o_pctoreg         <= 1'b0;
      o_memread         <= 1'b0;
      o_memwrite        <= 1'b0;
      o_branch          <= 1'b0;
      o_bubble          <= 1'b1;
    end else if (!i_stall) begin
      o_pc              <= i_pc;
      o_pc_4            <= i_pc_4;
      o_func3           <= i_func3;
      o_register_data_2 <= i_register_data_2;
      o_result          <= i_result;
      o_rd              <= i_rd;
      o_rs1             <= i_rs1;
      o_rs2             <= i_rs2;
      o_read_data_1     <= i_read_data_1;
      o_read_data_2     <= i_read_data_2;
      o_next_pc         <= i_next_pc;
      o_instr           <= i_instr;
      o_regwrite        <= i_regwrite;
      o_memtoreg        <= i_memtoreg;
      o_pctoreg         <= i_pctoreg;
      o_memread         <= i_memread;
      o_memwrite        <= i_memwrite;
      o_branch          <= i_branch;
      o_bubble          <= i_bubble;
    end
  end

endmodule
