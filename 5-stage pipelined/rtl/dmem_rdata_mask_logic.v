module dmem_rdata_mask_logic (
    input wire [31:0]  i_dmem_rdata,
    input wire [2:0]   i_func3,
    input wire [1:0]   i_addr_offset,
    output wire [31:0] o_dmem_rdata_masked
);

    assign o_dmem_rdata_masked =
        (i_func3 == 3'b000) ? ( // lb
            (i_addr_offset == 2'b00) ? {{24{i_dmem_rdata[7]}}, i_dmem_rdata[7:0]} :
            (i_addr_offset == 2'b01) ? {{24{i_dmem_rdata[15]}}, i_dmem_rdata[15:8]} :
            (i_addr_offset == 2'b10) ? {{24{i_dmem_rdata[23]}},  i_dmem_rdata[23:16]} :
                                       {{24{i_dmem_rdata[31]}},  i_dmem_rdata[31:24]}
        ) :
        (i_func3 == 3'b100) ? ( // lbu
            (i_addr_offset == 2'b00) ? {24'b0, i_dmem_rdata[7:0]} :
            (i_addr_offset == 2'b01) ? {24'b0, i_dmem_rdata[15:8]} :
            (i_addr_offset == 2'b10) ? {24'b0, i_dmem_rdata[23:16]} :
                                       {24'b0, i_dmem_rdata[31:24]}
        ) :
        (i_func3 == 3'b001) ? ( // lh
            (i_addr_offset == 2'b00) ? {{16{i_dmem_rdata[15]}}, i_dmem_rdata[15:0]} :
                                       {{16{i_dmem_rdata[31]}}, i_dmem_rdata[31:16]}
        ) :
        (i_func3 == 3'b101) ? ( // lhu
            (i_addr_offset == 2'b00) ? {16'b0, i_dmem_rdata[15:0]} :
                                       {16'b0, i_dmem_rdata[31:16]}
        ) :
        i_dmem_rdata; // lw
endmodule