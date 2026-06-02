module hazard_detection_unit (
    input  wire        memread_id_ex,
    input  wire        memwrite_id_ex,
    input  wire [4:0]  rd_id_ex,
    input  wire [4:0]  rs1_id_ex,
    input  wire        memwrite,
    input  wire        memread,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    output wire        pcwrite,
    output wire        haz
);

    wire load_haz, mem_haz;
    wire match_rs1 = (rd_id_ex == rs1);
    wire match_rs2 = (rd_id_ex == rs2);

    // RAW after a load
    assign load_haz = (memread_id_ex & (rd_id_ex != 5'b00000) & (match_rs1 | match_rs2)) ? 1 : 0;
    // Stall after every store
    assign mem_haz = (memwrite_id_ex & memread & (rs1_id_ex == rs1) ? 1 : 0);

    assign haz     = (load_haz) ? 1'b1 : 
                     (mem_haz)  ? 1'b1 :
                                  1'b0;
    assign pcwrite = (load_haz) ? 1'b0 :
                      (mem_haz) ? 1'b0 : 
                                  1'b1;

endmodule