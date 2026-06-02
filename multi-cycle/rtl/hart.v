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
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available synchronously after
    // the next clock edge.
    // NOTE: This is different from the previous phase. To accomodate a
    // multi-cycle pipelined design, the instruction memory read is
    // now synchronous.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
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
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // after the next clock edge, this will reflect the contents of memory
    // at the specified address, for the bytes enabled by the mask. When
    // read enable is not asserted, or for bytes not set in the mask, the
    // value is undefined.
    // NOTE: This is different from the previous phase. To accomodate a
    // multi-cycle pipelined design, the data memory read is
    // now synchronous.
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
    // The following data memory retire interface is used to record the
    // memory transactions completed by the instruction being retired.
    // As such, it mirrors the transactions happening on the main data
    // memory interface (o_dmem_* and i_dmem_*) but is delayed to match
    // the retirement of the instruction. You can hook this up by just
    // registering the main dmem interface signals into the writeback
    // stage of your pipeline.
    //
    // All these fields are don't-care for instructions that do not
    // access data memory (o_retire_dmem_ren and o_retire_dmem_wen
    // not asserted).
    // NOTE: This interface is new for phase 5 in order to account for
    // the delay between data memory accesses and instruction retire.
    //
    // The 32-bit data memory address accessed by the instruction.
    output wire [31:0] o_retire_dmem_addr,
    // The byte masked used for the data memory access.
    output wire [ 3:0] o_retire_dmem_mask,
    // Asserted if the instruction performed a read (load) from data memory.
    output wire        o_retire_dmem_ren,
    // Asserted if the instruction performed a write (store) to data memory.
    output wire        o_retire_dmem_wen,
    // The 32-bit data read from memory by a load instruction.
    output wire [31:0] o_retire_dmem_rdata,
    // The 32-bit data written to memory by a store instruction.
    output wire [31:0] o_retire_dmem_wdata,
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


    // Instruction Fetch
    wire [31:0] if_pc;
    wire [31:0] if_pc_4;
    wire [31:0] if_next_pc;
    wire        if_bubble;
    wire flush;
    wire pcwrite;
    wire [31:0] pc_jumped;
    wire [31:0] if_instr;
    wire [31:0] if_instr_mux;
    // Instruction Decode
    wire [31:0] if_id_pc;
    wire [31:0] if_id_pc_4;
    wire [31:0] if_id_instr;
    wire        if_id_bubble;
    // Datapath signals
    wire [4:0]  id_rd;
    wire [4:0]  id_rs1;
    wire [4:0]  id_rs2;
    wire [31:0] id_imm;
    wire        id_func7;
    wire [2:0]  id_func3;
    wire [31:0] id_read_data_1;
    wire [31:0] id_read_data_2;
    // Control signals
    wire id_regwrite;
    wire id_memtoreg;
    wire id_pctoreg;
    wire id_auipc;
    wire id_jump;
    wire id_branch;
    wire id_jalr;
    wire id_memread;
    wire id_memwrite;
    wire id_alusrc;
    wire [2:0] id_aluop;
    wire id_mux_regwrite;
    wire id_mux_memtoreg;
    wire id_mux_pctoreg;
    wire id_mux_auipc;
    wire id_mux_jump;
    wire id_mux_branch;
    wire id_mux_jalr;
    wire id_mux_memread;
    wire id_mux_memwrite;
    wire id_mux_alusrc;
    wire [2:0] id_mux_aluop;
    wire id_mux_bubble;
    wire id_insert_nop;

    // Execute
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_pc_4;
    // Datapath signals
    wire [4:0]  id_ex_rd;
    wire [4:0]  id_ex_rs1;
    wire [4:0]  id_ex_rs2;
    wire [31:0] id_ex_imm;
    wire        id_ex_func7;
    wire [2:0]  id_ex_func3;
    wire [31:0] id_ex_read_data_1;
    wire [31:0] id_ex_read_data_2;
    wire [31:0] id_ex_instr;
    wire [31:0] ex_register_data_1;
    wire [31:0] ex_register_data_2;
    wire [31:0] ex_result;
    wire [31:0] ex_next_pc;
    // Control signals
    wire id_ex_regwrite;
    wire id_ex_memtoreg;
    wire id_ex_pctoreg;
    wire id_ex_auipc;
    wire id_ex_jump;
    wire id_ex_branch;
    wire id_ex_jalr;
    wire id_ex_memread;
    wire id_ex_memwrite;
    wire id_ex_alusrc;
    wire [2:0] id_ex_aluop;
    wire id_ex_bubble;

    // Mem
    // Datapath signals
    wire [31:0] ex_mem_pc;
    wire [31:0] ex_mem_pc_4;
    wire [2:0]  ex_mem_func3;
    wire [31:0] ex_mem_register_data_1;
    wire [31:0] ex_mem_register_data_2;
    wire [31:0] ex_mem_result;
    wire [4:0]  ex_mem_rd;
    wire [4:0]  ex_mem_rs1;
    wire [4:0]  ex_mem_rs2;
    wire [31:0] ex_mem_next_pc;
    wire [31:0] ex_mem_instr;
    wire [3:0] mem_mask;
    wire [31:0] mem_dmem_addr;
    wire [31:0] mem_dmem_wdata;
    // Control signals
    wire ex_mem_regwrite;
    wire ex_mem_memtoreg;
    wire ex_mem_pctoreg;
    wire ex_mem_memread;
    wire ex_mem_memwrite;
    wire ex_mem_branch;
    wire ex_mem_bubble;

    // Writeback
    // Datapath signals
    wire [31:0] wb_dmem_rdata;
    wire [31:0] mem_wb_pc;
    wire [4:0] mem_wb_rd;
    wire [4:0] mem_wb_rs1;
    wire [4:0] mem_wb_rs2;
    wire [31:0] mem_wb_register_data_1;
    wire [31:0] mem_wb_register_data_2;
    wire [31:0] mem_wb_next_pc;
    wire [31:0] mem_wb_instr;
    wire [31:0] mem_wb_result;
    wire [31:0] mem_wb_pc_4;
    wire [31:0] mem_wb_dmem_wdata;
    wire [31:0] mem_wb_dmem_addr;
    wire [31:0] mem_wb_rd_data;
    wire  [3:0] mem_wb_mask;
    wire  [2:0] mem_wb_func3;
    // Control signals
    wire mem_wb_memtoreg;
    wire mem_wb_branch;
    wire mem_wb_pctoreg;
    wire mem_wb_regwrite;
    wire mem_wb_memread;
    wire mem_wb_memwrite;
    wire mem_wb_bubble;

    reg pulse;
    always @(posedge i_clk)
        if (i_rst)
            pulse <= 1'b1;
        else
            pulse <= 1'b0;

    // Instruction Fetch
    fetch_stage u_fetch (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_pulse(pulse),
        .i_pc_jumped(pc_jumped),
        .i_pcwrite(pcwrite),
        .i_flush(flush),
        .o_pc(if_pc),
        .o_pc_4(if_pc_4),
        .o_next_pc(if_next_pc)
    );
    assign o_imem_raddr = if_next_pc;
    assign if_instr = (pulse) ? 32'h0000_0013 : i_imem_rdata;
    assign if_instr_mux = (flush) ? 32'h0000_0013 : if_instr;
    // IF ID Register
    IF_ID_register u_if_id_reg(
        .i_clk(i_clk),
        .i_rst(pulse | i_rst),
        .i_bubble(flush),
        .i_pcwrite(pcwrite),
        .i_pc(if_pc),
        .i_pc_4(if_pc_4),    
        .i_instr(if_instr_mux),
        .o_pc(if_id_pc),
        .o_pc_4(if_id_pc_4),
        .o_instr(if_id_instr),
        .o_bubble(if_id_bubble)
    );

    // Instruction Decode
    decode_stage u_decode (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_flush(flush),
        .i_instr(if_id_instr),
        .i_rs1_id_ex(id_ex_rs1),
        .i_rd_id_ex(id_ex_rd),
        .i_memread_id_ex(id_ex_memread),
        .i_memwrite_id_ex(id_ex_memwrite),
        .i_rd_mem_wb(mem_wb_rd),
        .i_regwrite(mem_wb_regwrite),
        .i_write_data(mem_wb_rd_data),
        .o_imm(id_imm),
        .o_func7(id_func7),
        .o_func3(id_func3),
        .o_rd(id_rd),
        .o_rs1(id_rs1),
        .o_rs2(id_rs2),
        .o_read_data_1(id_read_data_1),
        .o_read_data_2(id_read_data_2),
        .o_pcwrite(pcwrite),
        .o_regwrite(id_regwrite),
        .o_memtoreg(id_memtoreg),
        .o_pctoreg(id_pctoreg),
        .o_auipc(id_auipc),
        .o_jump(id_jump),
        .o_branch(id_branch),
        .o_jalr(id_jalr),
        .o_memread(id_memread),
        .o_memwrite(id_memwrite),
        .o_aluop(id_aluop),
        .o_alusrc(id_alusrc),
        .o_insert_nop(id_insert_nop)
    );

    assign id_mux_regwrite = (id_insert_nop) ? 0 : id_regwrite;
    assign id_mux_memtoreg = (id_insert_nop) ? 0 : id_memtoreg;
    assign id_mux_pctoreg  = (id_insert_nop) ? 0 : id_pctoreg ;
    assign id_mux_auipc    = (id_insert_nop) ? 0 : id_auipc   ;
    assign id_mux_jump     = (id_insert_nop) ? 0 : id_jump    ;
    assign id_mux_branch   = (id_insert_nop) ? 0 : id_branch  ;
    assign id_mux_jalr     = (id_insert_nop) ? 0 : id_jalr    ;
    assign id_mux_memread  = (id_insert_nop) ? 0 : id_memread ;
    assign id_mux_memwrite = (id_insert_nop) ? 0 : id_memwrite;
    assign id_mux_alusrc   = (id_insert_nop) ? 0 : id_alusrc  ;
    assign id_mux_aluop    = (id_insert_nop) ? 0 : id_aluop   ;
    assign id_mux_bubble   = (id_insert_nop) ? 1 : if_id_bubble;

    // ID EX Register
    ID_EX_register u_id_ex_reg(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_pc(if_id_pc),
        .i_pc_4(if_id_pc_4),
        .i_func3(id_func3),
        .i_func7(id_func7),
        .i_imm(id_imm),
        .i_read_data_1(id_read_data_1),
        .i_read_data_2(id_read_data_2),
        .i_rs1(id_rs1),
        .i_rs2(id_rs2),
        .i_rd(id_rd),
        .i_instr(if_id_instr),
        // Control signals
        .i_regwrite(id_mux_regwrite),
        .i_memtoreg(id_mux_memtoreg),
        .i_pctoreg(id_mux_pctoreg),
        .i_auipc(id_mux_auipc),
        .i_jump(id_mux_jump),
        .i_branch(id_mux_branch),
        .i_jalr(id_mux_jalr),
        .i_memread(id_mux_memread),
        .i_memwrite(id_mux_memwrite),
        .i_alusrc(id_mux_alusrc),
        .i_aluop(id_mux_aluop),
        .i_bubble(id_mux_bubble),
        .o_pc(id_ex_pc),
        .o_pc_4(id_ex_pc_4),    
        .o_func3(id_ex_func3),
        .o_func7(id_ex_func7),
        .o_imm(id_ex_imm),
        .o_read_data_1(id_ex_read_data_1),
        .o_read_data_2(id_ex_read_data_2),
        .o_rs1(id_ex_rs1),
        .o_rs2(id_ex_rs2),
        .o_rd(id_ex_rd),
        .o_instr(id_ex_instr),
        // Control signals
        .o_regwrite(id_ex_regwrite),
        .o_memtoreg(id_ex_memtoreg),
        .o_pctoreg(id_ex_pctoreg),
        .o_auipc(id_ex_auipc),
        .o_jump(id_ex_jump),
        .o_branch(id_ex_branch),
        .o_jalr(id_ex_jalr),
        .o_memread(id_ex_memread),
        .o_memwrite(id_ex_memwrite),
        .o_alusrc(id_ex_alusrc),
        .o_aluop(id_ex_aluop),
        .o_bubble(id_ex_bubble)
    );

    // Execute
    execute_stage u_execute (
        .i_pc(id_ex_pc),
        .i_func3(id_ex_func3),
        .i_func7(id_ex_func7),
        .i_imm(id_ex_imm),
        .i_read_data_1(id_ex_read_data_1),
        .i_read_data_2(id_ex_read_data_2),
        .i_rs1(id_ex_rs1),
        .i_rs2(id_ex_rs2),
        .i_rd(id_ex_rd),
        .i_regwrite_ex_mem(ex_mem_regwrite),
        .i_rd_ex_mem(ex_mem_rd),
        .i_regwrite_mem_wb(mem_wb_regwrite),
        .i_rd_mem_wb(mem_wb_rd),
        .i_forward_ex_mem_data(ex_mem_result),
        .i_forward_mem_wb_data(mem_wb_rd_data),
        // Control signals
        .i_auipc(id_ex_auipc),
        .i_jump(id_ex_jump),
        .i_branch(id_ex_branch),
        .i_jalr(id_ex_jalr),
        .i_alusrc(id_ex_alusrc),
        .i_aluop(id_ex_aluop),
        // Outputs
        .o_register_data_1(ex_register_data_1),
        .o_register_data_2(ex_register_data_2), 
        .o_result(ex_result),
        .o_pc_jumped(pc_jumped),
        .o_next_pc(ex_next_pc),
        .o_flush(flush)
    );

    // EX MEM Register
    EX_MEM_register i_ex_mem_reg(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_pc(id_ex_pc),   
        .i_pc_4(id_ex_pc_4),
        .i_func3(id_ex_func3),
        .i_register_data_1(ex_register_data_1),
        .i_register_data_2(ex_register_data_2),
        .i_result(ex_result),
        .i_rd(id_ex_rd),
        .i_rs1(id_ex_rs1),
        .i_rs2(id_ex_rs2),
        .i_next_pc(ex_next_pc),
        .i_instr(id_ex_instr),
        .i_regwrite(id_ex_regwrite),
        .i_memtoreg(id_ex_memtoreg),
        .i_pctoreg(id_ex_pctoreg),
        .i_memread(id_ex_memread),
        .i_memwrite(id_ex_memwrite),
        .i_branch(id_ex_branch),
        .i_bubble(id_ex_bubble),
        .o_pc(ex_mem_pc),   
        .o_pc_4(ex_mem_pc_4),
        .o_func3(ex_mem_func3),
        .o_register_data_1(ex_mem_register_data_1),
        .o_register_data_2(ex_mem_register_data_2),
        .o_result(ex_mem_result),
        .o_rd(ex_mem_rd),
        .o_rs1(ex_mem_rs1),
        .o_rs2(ex_mem_rs2),
        .o_instr(ex_mem_instr),
        .o_next_pc(ex_mem_next_pc),
        .o_regwrite(ex_mem_regwrite),
        .o_memtoreg(ex_mem_memtoreg),
        .o_pctoreg(ex_mem_pctoreg),
        .o_memread(ex_mem_memread),
        .o_memwrite(ex_mem_memwrite),
        .o_branch(ex_mem_branch),
        .o_bubble(ex_mem_bubble)
    );

    // Data Memory
    assign mem_dmem_addr = {ex_mem_result[31:2], 2'b00}; // Word aligned address
    assign o_dmem_addr = mem_dmem_addr;
    assign o_dmem_ren = ex_mem_memread;
    assign o_dmem_wen = ex_mem_memwrite;
    assign o_dmem_wdata = mem_dmem_wdata;
    // Data Memory Mask
    assign mem_mask = (ex_mem_func3 == 3'b000 | ex_mem_func3 == 3'b100) ? (1 << ex_mem_result[1:0]) : // b
                      (ex_mem_func3 == 3'b001 | ex_mem_func3 == 3'b101) ? (3 << ex_mem_result[1:0]) : // h
                       4'b1111; // w
    assign o_dmem_mask = mem_mask;
    // Store
    dmem_wdata_mask_logic i_mask_wdata(
        .i_register_data_2(ex_mem_register_data_2), 
        .i_func3(ex_mem_func3), 
        .i_addr_offset(ex_mem_result[1:0]),
        .o_dmem_wdata(mem_dmem_wdata)
    );

    MEM_WB_register i_mem_wb_reg (
        .i_clk(i_clk),
        .i_rst(i_rst),

        // Writeback values
        .i_result(ex_mem_result),
        .i_pc_4(ex_mem_pc_4),
        .i_dmem_wdata(mem_dmem_wdata),
        .i_dmem_addr(mem_dmem_addr),
        // Control
        .i_regwrite(ex_mem_regwrite),
        .i_memtoreg(ex_mem_memtoreg),
        .i_pctoreg(ex_mem_pctoreg),
        .i_memwrite(ex_mem_memwrite),
        .i_memread(ex_mem_memread),
        .i_branch(ex_mem_branch),
        .i_rd(ex_mem_rd),
        .i_rs1(ex_mem_rs1),
        .i_rs2(ex_mem_rs2),
        .i_register_data_1(ex_mem_register_data_1),
        .i_register_data_2(ex_mem_register_data_2),
        .i_pc(ex_mem_pc),
        .i_next_pc(ex_mem_next_pc),
        .i_instr(ex_mem_instr),
        .i_mask(mem_mask),
        .i_bubble(ex_mem_bubble),
        .i_func3(ex_mem_func3),
        // Outputs
        .o_result(mem_wb_result),
        .o_pc_4(mem_wb_pc_4),
        .o_dmem_wdata(mem_wb_dmem_wdata),
        .o_regwrite(mem_wb_regwrite),
        .o_memtoreg(mem_wb_memtoreg),
        .o_pctoreg(mem_wb_pctoreg),
        .o_memread(mem_wb_memread),
        .o_memwrite(mem_wb_memwrite),
        .o_branch(mem_wb_branch),
        .o_rd(mem_wb_rd),
        .o_rs1(mem_wb_rs1),
        .o_rs2(mem_wb_rs2),
        .o_register_data_1(mem_wb_register_data_1),
        .o_register_data_2(mem_wb_register_data_2),
        .o_pc(mem_wb_pc),
        .o_next_pc(mem_wb_next_pc),
        .o_instr(mem_wb_instr),
        .o_mask(mem_wb_mask),
        .o_bubble(mem_wb_bubble),
        .o_dmem_addr(mem_wb_dmem_addr),
        .o_func3(mem_wb_func3)
    );

    // Writeback
    dmem_rdata_mask_logic i_mask_rdata(
        .i_dmem_rdata(i_dmem_rdata), 
        .i_func3(mem_wb_func3), 
        .i_addr_offset(mem_wb_result[1:0]), 
        .o_dmem_rdata_masked(wb_dmem_rdata)
    );

    assign mem_wb_rd_data = mem_wb_memtoreg ? wb_dmem_rdata :
                            mem_wb_pctoreg ? mem_wb_pc_4 :
                            mem_wb_result;

    // Retire signals
    assign retire_halt = mem_wb_instr == 32'h0010_0073;
    assign o_retire_valid = (i_rst) ? 0 :  
                            (mem_wb_bubble == 1) ? 0 : 1;
    assign o_retire_inst = mem_wb_instr;
    assign o_retire_trap = 0; // No trap support
    assign o_retire_halt = retire_halt; // ebreak instruction
    assign o_retire_rs1_raddr = (mem_wb_rs1 == 5'b0) ? 32'b0 : mem_wb_rs1;
    assign o_retire_rs2_raddr = (mem_wb_rs2 == 5'b0) ? 32'b0 : mem_wb_rs2;
    assign o_retire_rs1_rdata = mem_wb_register_data_1;
    assign o_retire_rs2_rdata = mem_wb_register_data_2;
    assign o_retire_rd_waddr = mem_wb_rd;
    assign o_retire_rd_wdata = mem_wb_rd_data;
    assign o_retire_pc = mem_wb_pc;
    assign o_retire_next_pc = mem_wb_next_pc;
    assign o_retire_dmem_addr = mem_wb_dmem_addr;
    assign o_retire_dmem_mask = mem_wb_mask;
    assign o_retire_dmem_ren = mem_wb_memread;
    assign o_retire_dmem_wen = mem_wb_memwrite;
    assign o_retire_dmem_rdata = i_dmem_rdata;
    assign o_retire_dmem_wdata = mem_wb_dmem_wdata;
endmodule

`default_nettype wire
