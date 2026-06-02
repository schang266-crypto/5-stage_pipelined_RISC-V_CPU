module fetch_stage(
    input  wire        i_clk,
    input  wire        i_rst,        // active high reset
    input wire         i_pulse,
    input  wire [31:0] i_pc_jumped,  // target PC for jumps/flush
    input  wire        i_pcwrite,    // allow PC update (stall control)
    input  wire        i_flush,      // flush signal
    output reg  [31:0] o_pc,         // registered PC output
    output reg  [31:0] o_pc_4,       // registered PC+4
    output wire [31:0] o_next_pc
);
    wire [31:0] next_pc;

    // Next PC computation (combinational)
    assign next_pc = (i_rst | i_pulse) ? 32'd0 :
                     (!i_pcwrite) ? o_pc : 
                     (i_flush) ? i_pc_jumped :
                                 o_pc + 32'd4;
    assign o_next_pc = next_pc;
    // Synchronous state update
    always @(posedge i_clk) begin
        if (i_pulse) begin
            o_pc   <= 32'd0;
            o_pc_4 <= 32'd4;
        end else if (i_pcwrite) begin
            o_pc   <= next_pc;
            o_pc_4 <= next_pc + 32'd4;
        end
    end
endmodule