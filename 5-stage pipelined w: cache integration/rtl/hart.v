`default_nettype none

module hart #(
    parameter RESET_ADDR = 32'h00000000
) (
    input wire i_clk,
    input wire i_rst,

    // ========================================================================
    // INSTRUCTION MEMORY INTERFACE (Main Memory / Stalling)
    // ========================================================================
    input  wire        i_imem_ready,
    output wire [31:0] o_imem_raddr,
    output wire        o_imem_ren,
    input  wire        i_imem_valid,
    input  wire [31:0] i_imem_rdata,

    // ========================================================================
    // DATA MEMORY INTERFACE (Main Memory / Stalling)
    // ========================================================================
    // Inferred ports based on standard Project 6 Stalling Memory Interface
    input  wire        i_dmem_ready,
    output wire [31:0] o_dmem_addr,
    output wire        o_dmem_ren,
    output wire        o_dmem_wen,
    output wire [31:0] o_dmem_wdata,
    output wire [ 3:0] o_dmem_mask,   // Explicit mask for memory
    input  wire        i_dmem_valid,
    input  wire [31:0] i_dmem_rdata,

    // ========================================================================
    // RETIRE SIGNALS (For Verification)
    // ========================================================================
    output wire        o_retire_valid,
    output wire [31:0] o_retire_inst,
    output wire        o_retire_trap,
    output wire        o_retire_halt,
    output wire [ 4:0] o_retire_rs1_raddr,
    output wire [ 4:0] o_retire_rs2_raddr,
    output wire [31:0] o_retire_rs1_rdata,
    output wire [31:0] o_retire_rs2_rdata,
    output wire [ 4:0] o_retire_rd_waddr,
    output wire [31:0] o_retire_rd_wdata,
    output wire [31:0] o_retire_dmem_addr,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [31:0] o_retire_dmem_rdata,
    output wire [31:0] o_retire_dmem_wdata,
    output wire [31:0] o_retire_pc,
    output wire [31:0] o_retire_next_pc
);

  // ========================================================================
  // INTERNAL WIRES
  // ========================================================================

  // Cache <-> CPU signals
  wire [31:0] cpu_if_instr;  // Instruction from I-Cache
  wire [31:0] cpu_dmem_rdata;  // Data from D-Cache

  wire        icache_busy;
  wire        dcache_busy;

  // D-Cache Request Signals (From MEM Stage)
  wire [31:0] cpu_req_dmem_addr;
  wire        cpu_req_dmem_ren;
  wire        cpu_req_dmem_wen;
  wire [31:0] cpu_req_dmem_wdata;
  wire [ 3:0] cpu_req_dmem_mask;

  // ========================================================================
  // STALL LOGIC
  // ========================================================================
  // 

  // Global Stall: If D-Cache is busy (miss/refill), freeze the entire backend.
  wire        stall_global = dcache_busy;

  // Fetch Stall: If I-Cache OR D-Cache is busy, freeze the PC.
  wire        stall_fetch = icache_busy | stall_global;

  // ========================================================================
  // CACHE INSTANTIATIONS
  // ========================================================================

  // 1. Instruction Cache
  cache ICACHE (
      .i_clk(i_clk),
      .i_rst(i_rst),

      // CPU Side
      .i_req_ren  (1'b1),          // Always fetch
      .i_req_wen  (1'b0),
      .i_req_addr (if_pc),         // Connect directly to Fetch Stage PC
      .i_req_wdata(32'b0),
      .i_req_mask (4'b1111),
      .o_res_rdata(cpu_if_instr),  // Output instruction to pipeline
      .o_busy     (icache_busy),

      // Memory Side (Direct connection to hart ports)
      .i_mem_ready(i_imem_ready),
      .o_mem_addr (o_imem_raddr),
      .o_mem_ren  (o_imem_ren),
      .o_mem_wen  (  /* I-Cache is Read Only */),
      .o_mem_wdata(  /* I-Cache is Read Only */),
      .i_mem_rdata(i_imem_rdata),
      .i_mem_valid(i_imem_valid)
  );

  // 2. Data Cache
  cache DCACHE (
      .i_clk(i_clk),
      .i_rst(i_rst),

      // CPU Side
      .i_req_ren(cpu_req_dmem_ren),
      .i_req_wen(cpu_req_dmem_wen),
      .i_req_addr(cpu_req_dmem_addr),
      .i_req_wdata(cpu_req_dmem_wdata),
      .i_req_mask(cpu_req_dmem_mask),
      .o_res_rdata(cpu_dmem_rdata),  // Output data to pipeline
      .o_busy(dcache_busy),

      // Memory Side (Direct connection to hart ports)
      .i_mem_ready(i_dmem_ready),
      .o_mem_addr (o_dmem_addr),
      .o_mem_ren  (o_dmem_ren),
      .o_mem_wen  (o_dmem_wen),
      .o_mem_wdata(o_dmem_wdata),
      .i_mem_rdata(i_dmem_rdata),
      .i_mem_valid(i_dmem_valid)
  );

  // Hardcode mask for main memory (Cache refills are always full lines)
  assign o_dmem_mask = 4'b1111;

  // ========================================================================
  // PIPELINE LOGIC
  // ========================================================================

  // Wires
  wire [31:0] if_pc, if_pc_4;
  wire [31:0] if_id_pc, if_id_pc_4, if_id_instr;
  wire if_id_bubble;
  wire [4:0] id_rd, id_rs1, id_rs2;
  wire [31:0] id_imm;
  wire        id_func7;
  wire [ 2:0] id_func3;
  wire [31:0] id_read_data_1, id_read_data_2;
  wire        id_regwrite, id_memtoreg, id_pctoreg, id_auipc, id_jump, id_branch, id_jalr, id_memread, id_memwrite, id_alusrc, id_bubble;
  wire [2:0] id_aluop;
  wire [31:0] id_ex_pc, id_ex_pc_4;
  wire [4:0] id_ex_rd, id_ex_rs1, id_ex_rs2;
  wire [31:0] id_ex_imm;
  wire        id_ex_func7;
  wire [ 2:0] id_ex_func3;
  wire [31:0] id_ex_read_data_1, id_ex_read_data_2, id_ex_instr;
  wire [31:0] ex_register_data_2, ex_result, ex_next_pc;
  wire        id_ex_regwrite, id_ex_memtoreg, id_ex_pctoreg, id_ex_auipc, id_ex_jump, id_ex_branch, id_ex_jalr, id_ex_memread, id_ex_memwrite, id_ex_alusrc, id_ex_bubble;
  wire [2:0] id_ex_aluop;
  wire [31:0] ex_mem_pc, ex_mem_pc_4, ex_mem_register_data_2, ex_mem_result;
  wire [4:0] ex_mem_rd, ex_mem_rs1, ex_mem_rs2;
  wire [31:0] ex_mem_read_data_1, ex_mem_read_data_2, ex_mem_next_pc, ex_mem_instr;
  wire [4:0] mem_mask;
  wire [31:0] mem_dmem_rdata, mem_dmem_wdata;
  wire        ex_mem_regwrite, ex_mem_memtoreg, ex_mem_pctoreg, ex_mem_memread, ex_mem_memwrite, ex_mem_branch, ex_mem_bubble;
  wire [2:0] ex_mem_func3;
  wire [31:0] mem_wb_pc, mem_wb_result, mem_wb_pc_4, mem_wb_dmem_rdata, mem_wb_dmem_wdata, mem_wb_rd_data, mem_wb_next_pc, mem_wb_read_data_1, mem_wb_read_data_2, mem_wb_instr;
  wire [4:0] mem_wb_rd, mem_wb_rs1, mem_wb_rs2, mem_wb_mask;
  wire        mem_wb_memtoreg, mem_wb_branch, mem_wb_pctoreg, mem_wb_regwrite, mem_wb_memread, mem_wb_memwrite, mem_wb_bubble;
  wire pcwrite, flush;
  wire [31:0] pc_jumped;
  wire        retire_halt;

  // ------------------------------------------------------------------------
  // FETCH STAGE
  // ------------------------------------------------------------------------
  fetch_stage #(
      .RESET_ADDR(RESET_ADDR)
  ) u_fetch (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_pc_jumped(pc_jumped),
      // Stall Fetch if any cache is busy
      .i_pcwrite(pcwrite && !stall_fetch),
      .i_flush(flush),
      .o_pc(if_pc),
      .o_pc_4(if_pc_4)
  );

  // ------------------------------------------------------------------------
  // IF/ID REGISTER
  // ------------------------------------------------------------------------
  IF_ID_register u_if_id_reg (
      .i_clk(i_clk),
      .i_rst(i_rst),
      // Flush (Bubble) if I-Cache is missing (waiting for data)
      .i_flush(flush),
      .i_stall_fetch(stall_fetch),
      // Stall if D-Cache is missing (Global Stall)
      .i_pcwrite(pcwrite && !stall_global),
      .i_pc(if_pc),
      .i_pc_4(if_pc_4),
      .i_instr(cpu_if_instr),  // Instruction comes from I-CACHE
      .o_pc(if_id_pc),
      .o_pc_4(if_id_pc_4),
      .o_instr(if_id_instr),
      .o_bubble(if_id_bubble)
  );

  // ------------------------------------------------------------------------
  // DECODE STAGE
  // ------------------------------------------------------------------------
  decode_stage u_decode (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_flush(flush),
      .i_instr(if_id_instr),
      .i_rd_id_ex(id_ex_rd),
      .i_memread_id_ex(id_ex_memread),
      .i_rd_mem_wb(mem_wb_rd),
      .i_regwrite(mem_wb_regwrite),
      .i_write_data(mem_wb_rd_data),
      .i_bubble(if_id_bubble),
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
      .o_bubble(id_bubble)
  );

  // ------------------------------------------------------------------------
  // ID/EX REGISTER
  // ------------------------------------------------------------------------
  // Note: Assumes you added `i_stall` to your ID_EX_register code
  ID_EX_register u_id_ex_reg (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_stall(stall_global),  // Stall Logic
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
      .i_regwrite(id_regwrite),
      .i_memtoreg(id_memtoreg),
      .i_pctoreg(id_pctoreg),
      .i_auipc(id_auipc),
      .i_jump(id_jump),
      .i_branch(id_branch),
      .i_jalr(id_jalr),
      .i_memread(id_memread),
      .i_memwrite(id_memwrite),
      .i_alusrc(id_alusrc),
      .i_aluop(id_aluop),
      .i_bubble(id_bubble),
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

  // ------------------------------------------------------------------------
  // EXECUTE STAGE
  // ------------------------------------------------------------------------
  execute_stage u_execute (
      .i_clk(i_clk),
      .i_rst(i_rst),
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
      .i_auipc(id_ex_auipc),
      .i_jump(id_ex_jump),
      .i_branch(id_ex_branch),
      .i_jalr(id_ex_jalr),
      .i_alusrc(id_ex_alusrc),
      .i_aluop(id_ex_aluop),
      .o_register_data_2(ex_register_data_2),
      .o_result(ex_result),
      .o_pc_jumped(pc_jumped),
      .o_next_pc(ex_next_pc),
      .o_flush(flush)
  );

  // ------------------------------------------------------------------------
  // EX/MEM REGISTER
  // ------------------------------------------------------------------------

  wire [31:0] trace_fwd_rs1;
  wire [31:0] trace_fwd_rs2;

  // Replicate the forwarding logic (Priority: EX/MEM > MEM/WB > ID/EX)
  assign trace_fwd_rs1 = (ex_mem_regwrite && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1)) ? ex_mem_result :
                         (mem_wb_regwrite && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1)) ? mem_wb_rd_data :
                         id_ex_read_data_1;

  assign trace_fwd_rs2 = (ex_mem_regwrite && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2)) ? ex_mem_result :
                         (mem_wb_regwrite && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2)) ? mem_wb_rd_data :
                         id_ex_read_data_2;

  EX_MEM_register i_ex_mem_reg (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_stall(stall_global),  // Stall Logic
      .i_pc(id_ex_pc),
      .i_pc_4(id_ex_pc_4),
      .i_func3(id_ex_func3),
      .i_register_data_2(ex_register_data_2),
      .i_result(ex_result),
      .i_rd(id_ex_rd),
      .i_rs1(id_ex_rs1),
      .i_rs2(id_ex_rs2),
      .i_read_data_1(trace_fwd_rs1),
      .i_read_data_2(trace_fwd_rs2),
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
      .o_register_data_2(ex_mem_register_data_2),
      .o_result(ex_mem_result),
      .o_rd(ex_mem_rd),
      .o_rs1(ex_mem_rs1),
      .o_rs2(ex_mem_rs2),
      .o_read_data_1(ex_mem_read_data_1),
      .o_read_data_2(ex_mem_read_data_2),
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

  // ------------------------------------------------------------------------
  // MEMORY STAGE LOGIC (Drive D-Cache Inputs)
  // ------------------------------------------------------------------------
  assign cpu_req_dmem_addr = {ex_mem_result[31:2], 2'b00};
  assign cpu_req_dmem_ren  = ex_mem_memread;
  assign cpu_req_dmem_wen  = ex_mem_memwrite;

  store_logic i_store_logic (
      .i_rs2(ex_mem_register_data_2),
      .i_func3(ex_mem_func3),
      .i_alu_result(ex_mem_result[1:0]),
      .o_dmem(mem_dmem_wdata)
  );
  assign cpu_req_dmem_wdata = mem_dmem_wdata;

  // Generate Mask based on funct3 (SB, SH, SW)
  assign mem_mask = (ex_mem_func3 == 3'b000 | ex_mem_func3 == 3'b100) ? (1 << ex_mem_result[1:0]) : 
                      (ex_mem_func3 == 3'b001 | ex_mem_func3 == 3'b101) ? (3 << ex_mem_result[1:0]) : 4'b1111;
  assign cpu_req_dmem_mask = mem_mask;

  // Load Data from D-CACHE
  load_logic i_load_logic (
      .i_mem_data(cpu_dmem_rdata),
      .i_func3(ex_mem_func3),
      .i_alu_result(ex_mem_result[1:0]),
      .o_write_data_masked(mem_dmem_rdata)
  );

  // ------------------------------------------------------------------------
  // MEM/WB REGISTER
  // ------------------------------------------------------------------------
  MEM_WB_register i_mem_wb_reg (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_stall(stall_global),  // Stall Logic
      .i_result(ex_mem_result),
      .i_pc_4(ex_mem_pc_4),
      .i_dmem_rdata(mem_dmem_rdata),
      .i_dmem_wdata(mem_dmem_wdata),
      .i_regwrite(ex_mem_regwrite),
      .i_memtoreg(ex_mem_memtoreg),
      .i_pctoreg(ex_mem_pctoreg),
      .i_memwrite(ex_mem_memwrite),
      .i_memread(ex_mem_memread),
      .i_branch(ex_mem_branch),
      .i_rd(ex_mem_rd),
      .i_rs1(ex_mem_rs1),
      .i_rs2(ex_mem_rs2),
      .i_pc(ex_mem_pc),
      .i_next_pc(ex_mem_next_pc),
      .i_read_data_1(ex_mem_read_data_1),
      .i_read_data_2(ex_mem_read_data_2),
      .i_instr(ex_mem_instr),
      .i_mask(mem_mask),
      .i_bubble(ex_mem_bubble),
      .o_result(mem_wb_result),
      .o_pc_4(mem_wb_pc_4),
      .o_dmem_rdata(mem_wb_dmem_rdata),
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
      .o_pc(mem_wb_pc),
      .o_next_pc(mem_wb_next_pc),
      .o_read_data_1(mem_wb_read_data_1),
      .o_read_data_2(mem_wb_read_data_2),
      .o_instr(mem_wb_instr),
      .o_mask(mem_wb_mask),
      .o_bubble(mem_wb_bubble)
  );

  // ------------------------------------------------------------------------
  // RETIREMENT
  // ------------------------------------------------------------------------
  assign mem_wb_rd_data = mem_wb_memtoreg ? mem_wb_dmem_rdata :
                            mem_wb_pctoreg ? mem_wb_pc_4 : mem_wb_result;

  assign retire_halt = mem_wb_instr == 32'h0010_0073;
  assign o_retire_valid = (i_rst) ? 0 : ~mem_wb_bubble | retire_halt;
  assign o_retire_inst = mem_wb_instr;
  assign o_retire_trap = 0;
  assign o_retire_halt = retire_halt;
  assign o_retire_rs1_raddr = (mem_wb_rs1 == 5'b0) ? 32'b0 : mem_wb_rs1;
  assign o_retire_rs2_raddr = (mem_wb_rs2 == 5'b0) ? 32'b0 : mem_wb_rs2;
  assign o_retire_rs1_rdata = mem_wb_read_data_1;
  assign o_retire_rs2_rdata = mem_wb_read_data_2;
  assign o_retire_rd_waddr = mem_wb_rd;
  assign o_retire_rd_wdata = mem_wb_rd_data;
  assign o_retire_pc = mem_wb_pc;
  assign o_retire_next_pc = mem_wb_next_pc;
  assign o_retire_dmem_addr = mem_wb_result;
  assign o_retire_dmem_mask = mem_wb_mask;
  assign o_retire_dmem_ren = mem_wb_memread;
  assign o_retire_dmem_wen = mem_wb_memwrite;
  assign o_retire_dmem_rdata = mem_wb_dmem_rdata;
  assign o_retire_dmem_wdata = mem_wb_dmem_wdata;

endmodule
