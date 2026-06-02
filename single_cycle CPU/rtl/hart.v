module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be br_true.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be br_true). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/br_true extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002003`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
    
    wire [6:0] opcode;
    wire [2:0] func3;
    wire func7;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [31:0] imm;
    wire [31:0] pc;
    wire [31:0] next_pc;
    wire [31:0] inst;
    wire [31:0] alu_result;
    wire [31:0] read_data1;
    wire [31:0] read_data2;
    wire [31:0] write_data;
    wire [31:0] alu_op2;
    wire [31:0] mem_read_data;
    wire [3:0] alu_control;
    wire branch;
    wire jump;
    wire jalr;
    wire regwrite;
    wire memtoreg;
    wire alusrc;
    wire memread;
    wire memwrite;
    wire pctoreg;
    wire auipc;
    wire [2:0] aluop;
    wire br_true;
    wire [31:0] pc_plus_4;
    wire [31:0] branch_addr;
    wire [31:0] jump_addr;
    wire [31:0] jalr_addr;
    wire branch_taken;
    wire [31:0] write_data_masked;
    
    // Instruction Fetch
    assign o_imem_raddr = pc;
    assign inst = i_imem_rdata;

    PC i_pc(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .next_pc(next_pc),
        .pc(pc)
    );

    // Instruction Decode
    instruction_decoder i_inst_decoder(
        .i_inst(inst),
        .o_opcode(opcode),
        .o_func3(func3),
        .o_func7(func7),
        .o_rs1(rs1),
        .o_rs2(rs2),
        .o_rd(rd),
        .o_imm(imm)
    );

    // Control
    control i_control(
        .i_opcode(opcode),
        .o_branch(branch),
        .o_jump(jump),
        .o_jalr(jalr),
        .o_regwrite(regwrite),
        .o_memtoreg(memtoreg),
        .o_alusrc(alusrc),
        .o_memread(memread),
        .o_memwrite(memwrite),
        .o_pctoreg(pctoreg),
        .o_auipc(auipc),
        .o_aluop(aluop)
    );

    // Register File
    rf rf(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(rs1),
        .i_rs2_raddr(rs2),
        .i_rd_waddr(rd),
        .i_rd_wdata(write_data),
        .i_rd_wen(regwrite),
        .o_rs1_rdata(read_data1),
        .o_rs2_rdata(read_data2)
    );

    // ALU
    alu_control i_alu_control(
        .i_aluop(aluop),
        .i_func3(func3),
        .i_func7(func7),
        .o_aluctrl(alu_control)
    );

    assign alu_op2 = alusrc ? imm : read_data2;

    alu i_alu(
        .i_aluctrl(alu_control),
        .i_op1(read_data1),
        .i_op2(alu_op2),
        .o_result(alu_result),
        .o_br_true(br_true)
    );

    // Data Memory
    assign o_dmem_addr = {alu_result[31:2], 2'b00}; // Word aligned address
    assign o_dmem_ren = memread;
    assign o_dmem_wen = memwrite;
    store_logic i_store_logic(.i_rs2(read_data2), .i_func3(func3), .i_alu_result(alu_result[1:0]), .o_dmem(o_dmem_wdata));

    // Data Memory Mask
    assign o_dmem_mask = (func3 == 3'b000 | func3 == 3'b100) ? (1 << alu_result[1:0]) : // sb
                         (func3 == 3'b001 | func3 == 3'b101) ? (3 << alu_result[1:0]) : // sh
                         4'b1111; // sw

    // // Write Back
    load_logic i_load_loagic(.i_mem_data(i_dmem_rdata), .i_func3(func3), .i_alu_result(alu_result[1:0]), .o_write_data_masked(write_data_masked));

    assign write_data = memtoreg ? write_data_masked :
                        pctoreg ? pc_plus_4 :
                        auipc ? pc + imm :
                        alu_result;


    // PC Update
    assign pc_plus_4 = pc + 4;
    assign branch_addr = pc + imm;
    assign jump_addr = pc + imm;
    assign jalr_addr = read_data1 + imm;

    assign branch_taken = branch & br_true;

    assign next_pc = branch_taken ? branch_addr :
                     jump ? jump_addr :
                     jalr ? jalr_addr :
                     pc_plus_4;
                     
    // Retire signals
    assign o_retire_valid = 1;
    assign o_retire_inst = inst;
    assign o_retire_trap = 0; // No trap support in single-cycle processor
    assign o_retire_halt = (inst == 32'h0010_0073); // ebreak instruction
    assign o_retire_rs1_raddr = (rs1 == 5'b0) ? 32'b0 : rs1;
    assign o_retire_rs2_raddr = (rs2 == 5'b0) ? 32'b0 : rs2;
    assign o_retire_rs1_rdata = read_data1;
    assign o_retire_rs2_rdata = read_data2;
    assign o_retire_rd_waddr = rd;
    assign o_retire_rd_wdata = write_data;
    assign o_retire_pc = pc;
    assign o_retire_next_pc = next_pc;
endmodule

`default_nettype wire
