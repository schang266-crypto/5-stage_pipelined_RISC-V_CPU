module PC (
    input wire i_clk,
    input wire i_rst,
    input wire [31:0] next_pc,
    output reg [31:0] pc
);

always @(posedge i_clk or posedge i_rst) begin
    if (i_rst)
        pc <= 32'h00000000;
    else
        pc <= next_pc;
end

endmodule