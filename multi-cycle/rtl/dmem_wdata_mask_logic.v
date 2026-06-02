module dmem_wdata_mask_logic (
    input wire [31:0] i_register_data_2,
    input wire [2:0]  i_func3,
    input wire [1:0]  i_addr_offset,
    output wire [31:0] o_dmem_wdata
);

    wire [31:0] dmem_preshift;

    assign dmem_preshift = (i_func3 == 3'b000) ? {{24{i_register_data_2[15]}}, i_register_data_2[7:0]} :
                           (i_func3 == 3'b001) ? {{16{i_register_data_2[15]}} ,i_register_data_2[15:0]} :
                                                 i_register_data_2;

    assign o_dmem_wdata = (i_addr_offset == 2'b00) ? dmem_preshift :
                          (i_addr_offset == 2'b01) ? dmem_preshift << 8 :
                          (i_addr_offset == 2'b10) ? dmem_preshift << 16 :
                                                     dmem_preshift << 24;
endmodule