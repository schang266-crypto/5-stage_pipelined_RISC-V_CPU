module hazard_detection_unit (
    input  wire        i_rst,
    input  wire        MemRead_ID_EX,
    input  wire [4:0]  RD_ID_EX,
    input  wire [4:0]  RS1_IF_ID,
    input  wire [4:0]  RS2_IF_ID,

    output wire        PCWrite,
    output wire        Haz
);

    wire match_rs1 = (RD_ID_EX == RS1_IF_ID);
    wire match_rs2 = (RD_ID_EX == RS2_IF_ID);

    wire load_haz = (MemRead_ID_EX & (RD_ID_EX != 5'b00000) & (match_rs1 | match_rs2));

    assign Haz     = (load_haz) ? 1'b1 : 1'b0;
    assign PCWrite = (load_haz) ? 1'b0 : 1'b1;

endmodule