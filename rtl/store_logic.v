module store_logic(
    input wire [31:0] i_rs2,
    input wire [2:0]  i_func3,
    input wire [1:0]  i_alu_result,
    output wire [31:0] o_dmem
);

    wire [31:0] dmem_preshift;

    assign dmem_preshift = (i_func3 == 3'b000) ? {{24{i_rs2[15]}}, i_rs2[7:0]} :
                           (i_func3 == 3'b001) ? {{16{i_rs2[15]}} ,i_rs2[15:0]} :
                                                 i_rs2;

    assign o_dmem = (i_alu_result == 2'b00) ? dmem_preshift :
                    (i_alu_result == 2'b01) ? dmem_preshift << 8 :
                    (i_alu_result == 2'b10) ? dmem_preshift << 16 :
                                              dmem_preshift << 24;
endmodule