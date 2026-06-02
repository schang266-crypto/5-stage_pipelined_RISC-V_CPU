module PC (
    input wire i_clk,
    input wire i_rst,
    input i_PCWrite,
    input wire [31:0] i_next_pc,
    output reg [31:0] o_pc
);

always @(posedge i_clk) begin
    if (i_rst)
        o_pc <= 32'h00000000;
    else if (i_PCWrite)
        o_pc <= i_next_pc;
    // !i_PCWrite -> Don't increment PC. Used to stall
end

endmodule