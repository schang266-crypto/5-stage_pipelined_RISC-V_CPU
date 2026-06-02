module control_tb;

    reg [6:0] i_opcode;
    wire o_branch, o_jump, o_jalr, o_regwrite, o_memtoreg, o_alusrc, o_memread, o_memwrite, o_pctoreg, o_auipc;
    wire [1:0] o_aluop;

    control uut (
        .i_opcode(i_opcode),
        .o_branch(o_branch),
        .o_jump(o_jump),
        .o_jalr(o_jalr),
        .o_regwrite(o_regwrite),
        .o_memtoreg(o_memtoreg),
        .o_alusrc(o_alusrc),
        .o_memread(o_memread),
        .o_memwrite(o_memwrite),
        .o_pctoreg(o_pctoreg),
        .o_auipc(o_auipc),
        .o_aluop(o_aluop)
    );

    // Expected values for each opcode
    reg exp_branch, exp_jump, exp_jalr, exp_regwrite, exp_memtoreg, exp_alusrc, exp_memread, exp_memwrite, exp_pctoreg, exp_auipc;
    reg [1:0] exp_aluop;

    task check_outputs;
        input [6:0] opcode;
        begin
            #1;
            if (o_branch    !== exp_branch   ) $display("FAIL: opcode=%b o_branch    %b != %b", opcode, o_branch, exp_branch);
            if (o_jump      !== exp_jump     ) $display("FAIL: opcode=%b o_jump      %b != %b", opcode, o_jump, exp_jump);
            if (o_jalr      !== exp_jalr     ) $display("FAIL: opcode=%b o_jalr      %b != %b", opcode, o_jalr, exp_jalr);
            if (o_regwrite  !== exp_regwrite ) $display("FAIL: opcode=%b o_regwrite  %b != %b", opcode, o_regwrite, exp_regwrite);
            if (o_memtoreg  !== exp_memtoreg ) $display("FAIL: opcode=%b o_memtoreg  %b != %b", opcode, o_memtoreg, exp_memtoreg);
            if (o_alusrc    !== exp_alusrc   ) $display("FAIL: opcode=%b o_alusrc    %b != %b", opcode, o_alusrc, exp_alusrc);
            if (o_memread   !== exp_memread  ) $display("FAIL: opcode=%b o_memread   %b != %b", opcode, o_memread, exp_memread);
            if (o_memwrite  !== exp_memwrite ) $display("FAIL: opcode=%b o_memwrite  %b != %b", opcode, o_memwrite, exp_memwrite);
            if (o_pctoreg   !== exp_pctoreg  ) $display("FAIL: opcode=%b o_pctoreg   %b != %b", opcode, o_pctoreg, exp_pctoreg);
            if (o_auipc     !== exp_auipc    ) $display("FAIL: opcode=%b o_auipc     %b != %b", opcode, o_auipc, exp_auipc);
            if (o_aluop     !== exp_aluop    ) $display("FAIL: opcode=%b o_aluop     %b != %b", opcode, o_aluop, exp_aluop);
        end
    endtask

    initial begin
        exp_branch = 0;
        exp_jump = 0;
        exp_jalr = 0;
        exp_auipc = 0;
        // R-Type
        i_opcode = 7'b011_0011;
        exp_regwrite = 1; exp_memtoreg = 0;
        exp_alusrc   = 0; exp_memread = 0; exp_memwrite = 0; exp_pctoreg = 0;
        exp_aluop    = 2'b10;
        #10;
        check_outputs(i_opcode);
        #10;

        // I-Type Load
        i_opcode = 7'b000_0011;
        exp_regwrite = 1; exp_memtoreg = 1;
        exp_alusrc   = 1; exp_memread = 1; exp_memwrite = 0; exp_pctoreg = 0;
        exp_aluop    = 2'b00;
        #10;
        check_outputs(i_opcode);
        #10;

        // I-Type Other
        i_opcode = 7'b001_0011;
        exp_regwrite = 1; exp_memtoreg = 0;
        exp_alusrc   = 1; exp_memread = 0; exp_memwrite = 0; exp_pctoreg = 0;
        exp_aluop    = 2'b10;
        #10;
        check_outputs(i_opcode);
        #10;

        // S-Type Store
        i_opcode = 7'b010_0011;
        exp_regwrite = 0; exp_memtoreg = 0;
        exp_alusrc   = 1; exp_memread = 0; exp_memwrite = 1; exp_pctoreg = 0;
        exp_aluop    = 2'b00;
        #10;
        check_outputs(i_opcode);
        #10;

        // B-Type Branch
        exp_branch = 1;
        i_opcode = 7'b110_0011;
        exp_regwrite = 0; exp_memtoreg = 0;
        exp_alusrc   = 1; exp_memread = 0; exp_memwrite = 0; exp_pctoreg = 0;
        exp_aluop    = 2'b01;
        #10;
        check_outputs(i_opcode);
        #10;
        exp_branch = 0;

        // JAL
        exp_jump = 1;
        i_opcode = 7'b110_1111;
        exp_regwrite = 1; exp_memtoreg = 0;
        exp_alusrc   = 2'b11; exp_memread = 0; exp_memwrite = 0; exp_pctoreg = 1;
        exp_aluop    = 2'b11;
        #10;
        check_outputs(i_opcode);
        #10;
        exp_jump = 0;

        // JALR
        exp_jalr = 1;
        i_opcode = 7'b110_0111;
        exp_regwrite = 1; exp_memtoreg = 0;
        exp_alusrc   = 1; exp_memread = 0; exp_memwrite = 0; exp_pctoreg = 1;
        exp_aluop    = 2'b00;
        #10;
        check_outputs(i_opcode);
        #10;
        exp_jalr = 0;

        // LUI
        i_opcode = 7'b011_0111;
        exp_regwrite = 1; exp_memtoreg = 0;
        exp_alusrc   = 1; exp_memread = 0; exp_memwrite = 0; exp_pctoreg = 0;
        exp_aluop    = 2'b11;
        #10;
        check_outputs(i_opcode);
        #10;

        // AUIPC
        exp_auipc = 1;
        i_opcode = 7'b001_0111;
        exp_regwrite = 1; exp_memtoreg = 0;
        exp_alusrc   = 1; exp_memread = 0; exp_memwrite = 0; exp_pctoreg = 0;
        exp_aluop    = 2'b11;
        #10;
        check_outputs(i_opcode);
        #10;
        exp_auipc = 0;

        $display("Testbench finished.");
        $stop;
    end

endmodule