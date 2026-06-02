
//Forward control:
//00 = No Forwarding
//10 = MEM-EX Forwarding
//01 = MEM-MEM Forwarding

module forwarding_unit(
        input  wire [4:0]  i_rs1,
        input  wire [4:0]  i_rs2,
        input  wire [4:0]  i_rd_ex_mem,
        input  wire [4:0]  i_rd_mem_wb,
        input  wire        i_regwrite_ex_mem,
        input  wire        i_regwrite_mem_wb,

        output wire  [1:0] o_forwardA,
        output wire  [1:0] o_forwardB
);

    // ForwardA logic (rs1)
    assign o_forwardA =
        (i_regwrite_ex_mem & (i_rd_ex_mem != 5'b0) & (i_rd_ex_mem == i_rs1)) ? 2'b10 :
        (i_regwrite_mem_wb & (i_rd_mem_wb != 5'b0) & (i_rd_mem_wb == i_rs1)) ? 2'b01 :
        2'b00;

    // ForwardB logic (rs2)
    assign o_forwardB =
        (i_regwrite_ex_mem & (i_rd_ex_mem != 5'b0) & (i_rd_ex_mem == i_rs2)) ? 2'b10 :
        (i_regwrite_mem_wb & (i_rd_mem_wb != 5'b0) & (i_rd_mem_wb == i_rs2)) ? 2'b01 :
        2'b00;
endmodule