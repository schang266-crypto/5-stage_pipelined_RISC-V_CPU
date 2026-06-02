module fetch_stage (
    input  wire        i_clk,
    input  wire        i_rst,        // active high reset
    input  wire [31:0] i_pc_jumped,  // target PC for jumps/flush
    input  wire        i_pcwrite,    // allow PC update (stall control)
    input  wire        i_flush,      // flush signal
    output reg  [31:0] o_pc,         // registered PC output
    output reg  [31:0] o_pc_4        // registered PC+4
);
  wire [31:0] pc_next;

  // Synchronous state update
  always @(posedge i_clk) begin
    if (i_rst) begin
      o_pc   <= 32'd0;
      o_pc_4 <= 32'd4;
    end else if (i_flush) begin
      o_pc   <= i_pc_jumped;
      o_pc_4 <= i_pc_jumped + 32'd4;
    end
    else if (i_pcwrite) begin
      o_pc   <= o_pc + 32'd4;
      o_pc_4 <= o_pc_4 + 32'd4;
    end
  end
endmodule
