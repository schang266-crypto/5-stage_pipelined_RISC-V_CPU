module IF_ID_register(
    input  wire        i_clk,
    input  wire        i_rst,       // synchronous active-high reset
    input  wire        i_pcwrite,     // stall when low  
    input wire         i_bubble,
    input  wire [31:0] i_pc,
    input  wire [31:0] i_pc_4,    
    input  wire [31:0] i_instr,

    output reg  [31:0] o_pc,
    output reg  [31:0] o_pc_4,
    output reg  [31:0] o_instr,
    output reg         o_bubble
);

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc    <= 0;
            o_pc_4  <= 0;
            o_instr <= 32'h00000013; // NOP
            o_bubble <= 1;
        end else if (i_pcwrite) begin
            o_pc    <= i_pc;
            o_pc_4  <= i_pc_4;
            o_instr <= i_instr;
            o_bubble <= i_bubble;
        end
    end
endmodule