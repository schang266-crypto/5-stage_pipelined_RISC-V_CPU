module ID_EX_register(
    input wire        i_clk,
    input wire        i_rst,
    input wire [31:0] i_pc,
    input wire [31:0] i_pc_4,    
    input wire [2:0]  i_func3,
    input wire        i_func7,
    input wire [31:0] i_imm,
    input wire [31:0] i_read_data_1,
    input wire [31:0] i_read_data_2,
    input wire [4:0]  i_rs1,
    input wire [4:0]  i_rs2,
    input wire [4:0]  i_rd,
    input  wire [31:0] i_instr,
    // Control signals
    input wire        i_regwrite,
    input wire        i_memtoreg,
    input wire        i_pctoreg,
    input wire        i_auipc,
    input wire        i_jump,
    input wire        i_branch,
    input wire        i_jalr,
    input wire        i_memread,
    input wire        i_memwrite,
    input wire        i_alusrc,
    input wire [2:0]  i_aluop,
    input wire        i_bubble,
    output reg [31:0] o_pc,
    output reg [31:0] o_pc_4,    
    output reg [2:0]  o_func3,
    output reg        o_func7,
    output reg [31:0] o_imm,
    output reg [31:0] o_read_data_1,
    output reg [31:0] o_read_data_2,
    output reg [4:0]  o_rs1,
    output reg [4:0]  o_rs2,
    output reg [4:0]  o_rd,
    output reg [31:0] o_instr,
    // Control signals
    output reg        o_regwrite,
    output reg        o_memtoreg,
    output reg        o_pctoreg,
    output reg        o_auipc,
    output reg        o_jump,
    output reg        o_branch,
    output reg        o_jalr,
    output reg        o_memread,
    output reg        o_memwrite,
    output reg        o_alusrc,
    output reg [2:0]  o_aluop,
    output reg        o_bubble
);

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc            <= 32'b0;
            o_pc_4          <= 32'b0;
            o_func3         <= 3'b0;
            o_func7         <= 1'b0;
            o_imm           <= 32'b0;
            o_read_data_1   <= 32'b0;
            o_read_data_2   <= 32'b0;
            o_rs1           <= 5'b0; 
            o_rs2           <= 5'b0;
            o_rd            <= 5'b0;
            o_instr         <= 32'h0000_0013;
            o_regwrite      <= 1'b0;
            o_memtoreg      <= 1'b0;
            o_pctoreg       <= 1'b0;
            o_auipc         <= 1'b0;
            o_jump          <= 1'b0;
            o_branch        <= 1'b0;
            o_jalr          <= 1'b0;
            o_memread       <= 1'b0;
            o_memwrite      <= 1'b0;
            o_alusrc        <= 1'b0;
            o_aluop         <= 3'b0;
            o_bubble        <= 1'b1;
        end else begin
            o_pc            <= i_pc;
            o_pc_4          <= i_pc_4;
            o_func3         <= i_func3;
            o_func7         <= i_func7;
            o_imm           <= i_imm;
            o_read_data_1   <= i_read_data_1;
            o_read_data_2   <= i_read_data_2;
            o_rs1           <= i_rs1; 
            o_rs2           <= i_rs2;
            o_rd            <= i_rd;
            o_instr         <= i_instr;
            o_regwrite      <= i_regwrite;
            o_memtoreg      <= i_memtoreg;
            o_pctoreg       <= i_pctoreg;
            o_auipc         <= i_auipc;
            o_jump          <= i_jump;
            o_branch        <= i_branch;
            o_jalr          <= i_jalr;
            o_memread       <= i_memread;
            o_memwrite      <= i_memwrite;
            o_alusrc        <= i_alusrc;
            o_aluop         <= i_aluop;
            o_bubble        <= i_bubble;
        end
    end
endmodule