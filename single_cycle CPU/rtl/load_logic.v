module load_logic (
    input wire [31:0]  i_mem_data,
    input wire [2:0]   i_func3,
    input wire [1:0]   i_alu_result,
    output wire [31:0] o_write_data_masked
);

    assign o_write_data_masked =
        (i_func3 == 3'b000) ? (
            (i_alu_result == 2'b00) ? {{24{i_mem_data[7]}}, i_mem_data[7:0]} :
            (i_alu_result == 2'b01) ? {{24{i_mem_data[15]}}, i_mem_data[15:8]} :
            (i_alu_result == 2'b10) ? {{24{i_mem_data[23]}},  i_mem_data[23:16]} :
                                    {{24{i_mem_data[31]}},  i_mem_data[31:24]}
        ) :
        (i_func3 == 3'b100) ? (
            (i_alu_result == 2'b00) ? {24'b0, i_mem_data[7:0]} :
            (i_alu_result == 2'b01) ? {24'b0, i_mem_data[15:8]} :
            (i_alu_result == 2'b10) ? {24'b0, i_mem_data[23:16]} :
                                    {24'b0, i_mem_data[31:24]}
        ) :
        (i_func3 == 3'b001) ? (
            (i_alu_result == 2'b00) ? {{16{i_mem_data[15]}}, i_mem_data[15:0]} :
                                    {{16{i_mem_data[31]}}, i_mem_data[31:16]}
        ) :
        (i_func3 == 3'b101) ? (
            (i_alu_result == 2'b00) ? {16'b0, i_mem_data[15:0]} :
                                    {16'b0, i_mem_data[31:16]}
        ) :
        i_mem_data;

endmodule