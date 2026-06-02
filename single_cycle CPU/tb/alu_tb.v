`default_nettype none

module alu_tb;
    reg [3:0] i_aluctrl;
    reg [31:0] i_op1, i_op2;
    wire [31:0] o_result;
    wire o_zero;

    alu uut (
        .i_aluctrl(i_aluctrl),
        .i_op1(i_op1),
        .i_op2(i_op2),
        .o_result(o_result),
        .o_zero(o_zero)
    );

    initial begin
        // Test ADD
        i_aluctrl = 4'b0000; i_op1 = 32'd10; i_op2 = 32'd20;
        #10;
        if (o_result !== 32'd30) $error("ADD failed");
        #10;
        
        // Test SUB
        i_aluctrl = 4'b0001; i_op1 = 32'd50; i_op2 = 32'd20;
        #10;
        if (o_result !== 32'd30) $error("SUB failed");
        #10;

        // Test AND
        i_aluctrl = 4'b0010; i_op1 = 32'hFF00FF00; i_op2 = 32'h0F0F0F0F;
        #10;
        if (o_result !== (32'hFF00FF00 & 32'h0F0F0F0F)) $error("AND failed");
        #10;

        // Test OR
        i_aluctrl = 4'b0011; i_op1 = 32'hFF00FF00; i_op2 = 32'h0F0F0F0F;
        #10;
        if (o_result !== (32'hFF00FF00 | 32'h0F0F0F0F)) $error("OR failed");
        #10;

        // Test XOR
        i_aluctrl = 4'b0100; i_op1 = 32'hFF00FF00; i_op2 = 32'h0F0F0F0F;
        #10;
        if (o_result !== (32'hFF00FF00 ^ 32'h0F0F0F0F)) $error("XOR failed");
        #10;

        // Test SLL
        i_aluctrl = 4'b0101; i_op1 = 32'h00000001; i_op2 = 32'd8;
        #10;
        if (o_result !== 32'h00000100) $error("SLL failed");
        #10;

        // Test SRL
        i_aluctrl = 4'b0110; i_op1 = 32'h80000000; i_op2 = 32'd8;
        #10;
        if (o_result !== 32'h00800000) $error("SRL failed");
        #10;

        // Test SRA
        i_aluctrl = 4'b0111; i_op1 = 32'h80000000; i_op2 = 32'd8;
        #10;
        if (o_result !== 32'hff800000) $error("SRA failed");
        #10;

        // Test SLT (signed less than)
        i_aluctrl = 4'b1000; i_op1 = -32'd1; i_op2 = 32'd1;
        #10;
        if (o_result !== 1) $error("SLT failed");
        #10;

        // Test SLTU (unsigned less than)
        i_aluctrl = 4'b1001; i_op1 = 32'd1; i_op2 = 32'd2;
        #10;
        if (o_result !== 1) $error("SLTU failed");
        #10;

        // Test PASS_B
        i_aluctrl = 4'b1010; i_op1 = 32'd123; i_op2 = 32'd456;
        #10;
        if (o_result !== 32'd456) $error("PASS_B failed");
        #10;

        // Test SUB_CMP
        i_aluctrl = 4'b1011; i_op1 = 32'd100; i_op2 = 32'd50;
        #10;
        if (o_result !== 32'd50) $error("SUB_CMP failed");
        #10;

        // Test o_zero
        i_aluctrl = 4'b0000; i_op1 = 32'd0; i_op2 = 32'd0;
        #10;
        if (o_zero !== 1'b1) $error("o_zero failed");
        #10;

        $display("All tests passed.");
        $stop;
    end
endmodule