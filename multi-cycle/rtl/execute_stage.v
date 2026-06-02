module execute_stage(
    input  wire [31:0] i_pc,  
    input  wire [2:0]  i_func3,
    input  wire        i_func7,
    input  wire [31:0] i_imm,
    input  wire [31:0] i_read_data_1,
    input  wire [31:0] i_read_data_2,
    input  wire [4:0]  i_rs1,
    input  wire [4:0]  i_rs2,
    input  wire [4:0]  i_rd,
    input  wire        i_regwrite_ex_mem,
    input  wire [4:0]  i_rd_ex_mem,
    input  wire        i_regwrite_mem_wb,
    input  wire [4:0]  i_rd_mem_wb,
    input  wire [31:0] i_forward_ex_mem_data,
    input  wire [31:0] i_forward_mem_wb_data,
    // Control signals
    input  wire        i_auipc,
    input  wire        i_jump,
    input  wire        i_branch,
    input  wire        i_jalr,
    input  wire        i_alusrc,
    input  wire [2:0]  i_aluop,

    output wire [31:0] o_register_data_1,
    output wire [31:0] o_register_data_2,
    output wire [31:0] o_result,
    output wire [31:0] o_pc_jumped,
    output wire        o_flush,
    output wire [31:0] o_next_pc
);

    // ==============================
    // Internal signals
    // ==============================
    wire [3:0]  alu_control;
    wire [31:0] alu_op1, alu_op2;
    wire [31:0] alu_op1_fw, alu_op2_fw;
    wire [1:0]  forwardA, forwardB;
    wire        br_true;
    wire        flush;
    wire [31:0] pc_jumped;
    wire [31:0] alu_result;

    // ==============================
    // ALU Control
    // ==============================
    alu_control u_alu_control(
        .i_aluop(i_aluop),
        .i_func3(i_func3),
        .i_func7(i_func7),
        .o_aluctrl(alu_control)
    );

    // ==============================
    // Forwarding Unit
    // ==============================
    forwarding_unit u_forwarding_unit (
        .i_rs1(i_rs1),
        .i_rs2(i_rs2),
        .i_rd_ex_mem(i_rd_ex_mem),
        .i_rd_mem_wb(i_rd_mem_wb),
        .i_regwrite_ex_mem(i_regwrite_ex_mem),
        .i_regwrite_mem_wb(i_regwrite_mem_wb),
        .o_forwardA(forwardA),
        .o_forwardB(forwardB)
    );

    // ==============================
    // Forwarding Muxes
    // ==============================
    // (NOTE: fixed duplication and correct sources)
    assign alu_op1_fw = (forwardA == 2'b10) ? i_forward_ex_mem_data :
                        (forwardA == 2'b01) ? i_forward_mem_wb_data :
                                              i_read_data_1;

    assign alu_op2_fw = (forwardB == 2'b10) ? i_forward_ex_mem_data :
                        (forwardB == 2'b01) ? i_forward_mem_wb_data :
                                              i_read_data_2;

    // ==============================
    // ALU Operand Muxes
    // ==============================
    assign alu_op1 = (i_auipc) ? i_pc : alu_op1_fw; 
    assign alu_op2 = (i_alusrc) ? i_imm : alu_op2_fw;

    // Pass through register data (data 2 for stores and both needed for retires)
    assign o_register_data_1 = alu_op1_fw;
    assign o_register_data_2 = alu_op2_fw;

    // ==============================
    // ALU
    // ==============================
    alu u_alu(
        .i_aluctrl(alu_control),
        .i_op1(alu_op1),
        .i_op2(alu_op2),
        .o_result(alu_result),
        .o_br_true(br_true)
    );

    assign o_result = alu_result;

    // ==============================
    // Branch and Jump Control
    // ==============================
    assign flush =
        ((i_branch & br_true) | i_jalr | i_jump)
            ? 1'b1 : 1'b0;
    assign pc_jumped = (i_jalr) ? alu_result : (i_pc + i_imm);
    assign o_next_pc = (flush) ? pc_jumped : i_pc;
    assign o_flush = flush;
    assign o_pc_jumped = pc_jumped;
endmodule