module instruction_decoder_tb();
    reg [31:0] i_inst;
    wire [6:0] o_opcode;
    wire o_func7;
    wire [2:0] o_func3;
    wire [4:0] o_rs1;
    wire [4:0] o_rs2;
    wire [4:0] o_rd;
    wire [31:0] o_imm;

    instruction_decoder uut (
        .i_inst(i_inst),
        .o_opcode(o_opcode),
        .o_func7(o_func7),
        .o_func3(o_func3),
        .o_rs1(o_rs1),
        .o_rs2(o_rs2),
        .o_rd(o_rd),
        .o_imm(o_imm)
    );

    initial begin
        // sub x5 x2 x1
        i_inst = 32'b0100_0000_0001_0001_0000_0010_1011_0011;
        #10;
        // Check outputs
        $display("Testing sub x5, x2, x1");
        if (o_func3 !== 3'b000) $display("Error: func3 expected 3'b000, got %b", o_func3);
        if (o_func7 !== 1'b1) $display("Error: func7 expected 1, got %b", o_func7);
        if (o_opcode !== 7'b0110011) $display("Error: opcode expected 0110011, got %b", o_opcode);
        if (o_rs1 !== 5'd2) $display("Error: rs1 expected 2, got %d", o_rs1);
        if (o_rs2 !== 5'd1) $display("Error: rs2 expected 1, got %d", o_rs2);
        if (o_rd !== 5'd5) $display("Error: rd expected 5, got %d", o_rd);
        #10;

        // sltiu x15, x6, 32
        i_inst = 32'b0000_0010_0000_0011_0011_0111_1001_0011;
        #10;
        // Check outputs
        $display("Testing sltiu x15, x6, 32");
        if (o_func3 !== 3'b011) $display("Error: func3 expected 3'b011, got %b", o_func3);
        if (o_opcode !== 7'b0010011) $display("Error: opcode expected 0010011, got %b", o_opcode);
        if (o_imm !== 32) $display("Error: imm expected 32, got %d", o_imm);
        if (o_rd !== 5'd15) $display("Error: rd expected 15, got %d", o_rd);
        if (o_rs1 !== 5'd6) $display("Error: rs1 expected 6, got %d", o_rs1);
        #10;

        // lui x3 -5
        i_inst = 32'b11111111111111111011000110110111;
        #10;
        // Check outputs
        $display("Testing lui x3, -5");
        if (o_opcode !== 7'b0110111) $display("Error: opcode expected 0110111, got %b", o_opcode);
        //if (o_imm !== -10) $display("Error: imm expected -10, got %d", o_imm);
        if (o_rd !== 3) $display("Error: rd expected 3, got %d", o_rd);
        #10;

        // auipc x1 -8
        i_inst = 32'b11111111111111111000000010010111;
        #10;
        $display("Testing auipc x1, -8");
        if (o_opcode !== 7'b0010111) $display("Error: opcode expected 0010111, got %b", o_opcode);
        //if (o_imm !== -16) $display("Error: imm expected -16, got %d", o_imm);
        if (o_rd !== 1) $display("Error: rd expected 1, got %d", o_rd);
        #10;

        // lw x0 4(x3)
        i_inst = 32'b00000000010000011010000000000011;
        #10;
        $display("Testing lw x0, 4(x3)");
        if (o_func3 !== 3'b010) $display("Error: func3 expected 3'b010, got %b", o_func3);
        if (o_opcode !== 7'b0000011) $display("Error: opcode expected b0000011, got %b", o_opcode);
        if (o_rs1 !== 5'd3) $display("Error: rs1 expected 3, got %d", o_rs1);
        if (o_rd !== 5'd0) $display("Error: rd expected 0, got %d", o_rd);
        if (o_imm !== 4) $display("Error: imm expected 4, got %d", o_imm);
        #10;

        // bltu x5, x10, 16
        i_inst = 32'b00000000101000101110100001100011;
        #10;
        $display("Testing bltu x5, x10, 16");
        if (o_func3 !== 3'b110) $display("Error: func3 expected 3'b110, got %b", o_func3);
        if (o_opcode !== 7'b1100011) $display("Error: opcode expected 1100011, got %b", o_opcode);
        if (o_imm !== 16) $display("Error: imm expected 16, got %d", o_imm);
        if (o_rd !== 5'd5) $display("Error: rd expected 5, got %d", o_rd);
        if (o_rs1 !== 5'd10) $display("Error: rs1 expected 10, got %d", o_rs1);
        #10;

        // jal x0, 4
        i_inst = 32'b00000000010000000000000001101111;
        #10;
        $display("Testing jal x0, 4");
        if (o_opcode !== 7'b1101111) $display("Error: opcode expected 1101111, got %b", o_opcode);
        if (o_imm !== 4) $display("Error: imm expected 4, got %d", o_imm);
        if (o_rd !== 5'd0) $display("Error: rd expected 0, got %d", o_rd);
        #10;

        // jalr x1, 8(x2)
        i_inst = 32'b00000000100000010000000011100111;
        #10;
        $display("Testing jalr x1, 8(x2)");
        if (o_opcode !== 7'b1100111) $display("Error: opcode expected 1100111, got %b", o_opcode);
        if (o_imm !== 8) $display("Error: imm expected 8, got %d", o_imm);
        if (o_rd !== 5'd1) $display("Error: rd expected 1, got %d", o_rd);     
        if (o_rs1 !== 5'd2) $display("Error: rs1 expected 2, got %d", o_rs1);
        #10;

        // sb x5, 2(x4)
        i_inst = 32'b00000000010100100000000100100011;
        #10;
        $display("Testing sb x5, 2(x4)");
        if (o_func3 !== 3'b000) $display("Error: func3 expected 3'b000, got %b", o_func3);
        if (o_opcode !== 7'b0100011) $display("Error: opcode expected 0100011, got %b", o_opcode);
        if (o_imm !== 2) $display("Error: imm expected 2, got %d", o_imm);
        if (o_rd !== 5'd5) $display("Error: rd expected 5, got %d", o_rd);     
        if (o_rs1 !== 5'd4) $display("Error: rs1 expected 4, got %d", o_rs1);
        #10;
    end

endmodule