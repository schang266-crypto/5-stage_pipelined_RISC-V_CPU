`default_nettype none

module cache (
    // Global clock.
    input wire i_clk,
    // Synchronous active-high reset.
    input wire i_rst,


    // External memory interface
    // This interface is without the byte mask (`o_mem_mask`) 
    // This is no longer needed as the cache will only access the memory at word
    // granularity, and implement masking internally.
    input  wire        i_mem_ready, // tell the cache that main memory is ready to accept read or write requests

    // Output signals to main memory.
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata, // for writes through to main memory

    // Input signals from main memory.
    input wire [31:0] i_mem_rdata,  // for Loading data from main memory
    input wire        i_mem_valid,  // the data read from main memory is valid

    // Interface to CPU hart. 
    // This is nearly identical to the phase 5 hart memory
    // interface, but includes a stall signal (`o_busy`), and the input/output
    // polarities are swapped for obvious reasons.
    //
    // The CPU should use this as a stall signal for both instruction fetch
    // (IF) and memory (MEM) stages, from the instruction or data cache
    // respectively. If a memory request is made (`i_req_ren` for instruction
    // cache, or either `i_req_ren` or `i_req_wen` for data cache), this
    // should be asserted *combinationally* if the request results in a cache miss.
    //
    // In case of a cache miss, the CPU must stall the respective pipeline
    // stage and deassert ren/wen on subsequent cycles, until the cache
    // deasserts `o_busy` to indicate it has serviced the cache miss. However,
    // the CPU must keep the other request lines constant. For example, the
    // CPU should not change the request address while stalling.
    output wire o_busy,


    // 32-bit read/write address to access from the cache. 
    // This should be 32-bit aligned (i.e. the two LSBs should be zero). 
    // See `i_req_mask` for how to perform half-word and byte accesses to unaligned addresses.
    input wire [31:0] i_req_addr,

    // When asserted, the cache should perform a read at the aligned address
    // specified by `i_req_addr` and return the 32-bit word at that address,
    // either immediately (i.e. combinationally) on a cache hit, or
    // synchronously on a cache miss. It is illegal to assert this and
    // `i_dmem_wen` on the same cycle.
    input wire i_req_ren,

    // When asserted, the cache should perform a write at the aligned address
    // specified by `i_req_addr` with the 32-bit word provided in
    // `o_req_wdata` (specified by the mask). This is necessarily synchronous,
    // but may either happen on the next clock edge (on a cache hit) or after
    // multiple cycles of latency (cache miss). As the cache is write-through
    // and write-allocate, writes must be applied to both the cache and
    // underlying memory.
    // It is illegal to assert this and `i_dmem_ren` on the same cycle.
    input wire i_req_wen,

    // The memory interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    input wire [3:0] i_req_mask,

    // The 32-bit word to write to memory, if the request is a write
    // (i_req_wen is asserted). Only the bytes corresponding to set bits in
    // the mask should be written into the cache (and to backing memory).
    input wire [31:0] i_req_wdata,


    // The 32-bit data word read from memory on a read request.
    output wire [31:0] o_res_rdata
);
  ///////////////////
  // Cache parameters
  ///////////////////
  // 32 sets * 2 ways per set * 16 bytes per way = 1K cache
  localparam Offset = 4;  // 4 bit offset => 16 byte cache line
  localparam S = 5;  // 5 bit set index => 32 sets
  localparam DEPTH = 2 ** S;  // 32 sets
  localparam W = 2;  // 2 way set associative, NMRU
  localparam Tag = 32 - Offset - S;  // 23 bit tag
  localparam D = 2 ** Offset / 4;  // 16 bytes per line / 4 bytes per word = 4 words per line

  // Backing memory, modeled as two separate ways.
  reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0]; // way 0 for each set (32 bits per word * 32 sets * 4 words) word
  reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0]; // way 1 for each set (32 bits per word * 32 sets * 4 words)
  reg [Tag - 1:0] tags0[DEPTH - 1:0];  // tag array for way 0 in each set (23-bit tag * 32 sets)
  reg [Tag - 1:0] tags1[DEPTH - 1:0];  // tag array for way 1 in each set (23-bit tag * 32 sets)
  reg [1:0] valid [DEPTH - 1:0];               // valid bits for each way in each set (vaild[1] => way 1, valid[0] => way 0)
  reg lru[DEPTH - 1:0];  // LRU bit for each set, 0 => way0 is LRU, 1 => way1 is LRU

  // Internal state and control
  localparam CACHE = 2'b00;
  localparam MEMORY = 2'b01;
  localparam REFILL = 2'b10;
  reg [1:0] state;

  // helper extracted fields from request address
  wire [Offset-1:0] req_offset = i_req_addr[Offset-1:0];  // 4-bit offset (addr[3:0])
  wire [Offset-1:2] req_word_index = req_offset[Offset-1:2]; // 2-bit word index obtained from offset (addr[3:2])
  wire [S-1:0] req_set = i_req_addr[Offset+S-1:Offset];  // 5-bit set index (addr[8:4])
  wire [Tag-1:0] req_tag = i_req_addr[31:Offset+S];  // 23-bit tag (addr[31:9])

  ///////////
  // READ HIT
  ///////////
  // combinational hit detection (valid bit + tag compare)
  wire hit0 = valid[req_set][0] && (tags0[req_set] == req_tag);  // hit in way 0
  wire hit1 = valid[req_set][1] && (tags1[req_set] == req_tag);  // hit in way 1
  wire hit = hit0 | hit1;

  // select data word from ways (combinational for read-hit)
  wire [31:0] way0_word = datas0[req_set][req_word_index];  // word from way 0
  wire [31:0] way1_word = datas1[req_set][req_word_index];  // word from way 1
  assign o_res_rdata = hit0 ? way0_word : (hit1 ? way1_word : 32'b0);  // output read word combinationally when hit, else 0

  /////////////
  // BUSY: combinationally asserted if request causes a miss, or we're servicing memory
  /////////////
  assign o_busy = ((i_req_ren | i_req_wen) && !hit) || (state == MEMORY) || (state == REFILL);


  // When cache miss, choose which ways to allocate the new cache block
  wire victim_way;  // 0 => way0, 1 => way1
  assign victim_way = (valid[req_set] == 2'b00) ? 1'b0 :  // if both invalid choose way0
      (valid[req_set] == 2'b01) ? 1'b1 :  // only way0 valid -> choose way1 to fill
      (valid[req_set] == 2'b10) ? 1'b0 :  // only way1 valid -> choose way0 to fill
      lru[req_set];  // if both valid use lru bit (evict that way)

  ///////////////////
  // Masking function
  ///////////////////
  // combine bytes for masked write (returns merged word)
  function [31:0] merge_bytes;  // output of new merged word
    input [31:0] orig;  // requested original word from cache
    input [31:0] neww;  // requested write data (i_req_wdata)
    input [3:0] mask;  // byte mask (i_req_mask)
    reg [7:0] ob[3:0];
    reg [7:0] nb[3:0];
    integer i;
    begin
      for (i = 0; i < 4; i = i + 1) begin  // break a word into 4 bytes
        ob[i] = orig[i*8 +: 8]; // ob[0]= orig[0:7], ob[1]= orig[8:15], ob[2]= orig[16:23], ob[3]= orig[24:31]
        nb[i] = neww[i*8+:8];
      end
      for (
          i = 0; i < 4; i = i + 1
      ) begin  // new byte replaced if mask bit = 1, old byte retained if mask bit = 0
        if (mask[i]) merge_bytes[i*8+:8] = nb[i];
        else merge_bytes[i*8+:8] = ob[i];
      end
    end
  endfunction

  // Memory interface registers
  reg [31:0] mem_addr_reg;
  reg        mem_ren_reg;
  reg        mem_wen_reg;
  reg [31:0] mem_wdata_reg;

  assign o_mem_addr  = mem_addr_reg;
  assign o_mem_ren   = mem_ren_reg;
  assign o_mem_wen   = mem_wen_reg;
  assign o_mem_wdata = mem_wdata_reg;

  // memory refill counters
  reg [2:0] mem_word_cnt;  // counts 0 to 3 for 4 words in a cache block 
  reg [1:0] store_word_cnt; // counts how many words have been stored into cache line

  // Saved the info at the moment when a miss occurs
  reg saved_is_write;
  reg [3:0] saved_mask;
  reg [31:0] saved_wdata;
  reg [31:0] saved_addr;
  reg [S-1:0] saved_set;
  reg [Tag-1:0] saved_tag;
  reg [1:0] saved_word_idx;
  reg saved_victim_way;

  ///////////////////////////////
  // Synchronous logic for WRITE
  ///////////////////////////////
  integer si;
  always @(posedge i_clk) begin
    if (i_rst) begin
      // reset arrays' metadata
      for (si = 0; si < DEPTH; si = si + 1) begin
        valid[si] <= 2'b00;
        lru[si]   <= 1'b0;
        tags0[si] <= {Tag{1'b0}};
        tags1[si] <= {Tag{1'b0}};
      end

      state <= CACHE;
      mem_addr_reg <= 32'b0;
      mem_ren_reg <= 1'b0;
      mem_wen_reg <= 1'b0;
      mem_wdata_reg <= 32'b0;
      mem_word_cnt <= 3'b0;
      store_word_cnt <= 2'b0;
      saved_is_write <= 1'b0;
      saved_mask <= 4'b0;
      saved_wdata <= 32'b0;
      saved_addr <= 32'b0;
      saved_set <= {S{1'b0}};
      saved_tag <= {Tag{1'b0}};
      saved_word_idx <= 2'b0;
      saved_victim_way <= 1'b0;
    end 
    else begin
      // Default: clear memory request signals (unless we explicitly drive them)
      mem_ren_reg <= 1'b0;
      mem_wen_reg <= 1'b0;

      case (state)
        CACHE: begin
          // Hit
          if ((i_req_ren | i_req_wen) && hit) begin

            // update LRU bits on access
            if (hit0) lru[req_set] <= 1'b1;  // mark way1 as LRU
            else if (hit1) lru[req_set] <= 1'b0;  // mark way0 as LRU

            // Write-Hit: 
            // 1. Update cache and write-through to memory
            if (i_req_wen) begin
              if (hit0)
                datas0[req_set][req_word_index] <= merge_bytes(
                    datas0[req_set][req_word_index], i_req_wdata, i_req_mask
                );
              else
                datas1[req_set][req_word_index] <= merge_bytes(
                    datas1[req_set][req_word_index], i_req_wdata, i_req_mask
                );

              // 2. Initiate write-through to memory (single word) if memory ready
              mem_addr_reg  <= {i_req_addr[31:2], 2'b00};
              mem_wdata_reg <= merge_bytes(32'b0, i_req_wdata, i_req_mask);
              if (i_mem_ready) // If mem is ready to be written in this cycle, assert mem_wen for one cycle
                mem_wen_reg <= 1'b1;
            end
            // Read-hit: nothing more to do, only update LRU above
          end  

          // Miss: prepare to refill the whole line
          else if ((i_req_ren | i_req_wen) && !hit) begin
            saved_is_write <= i_req_wen;
            saved_mask <= i_req_mask;
            saved_wdata <= i_req_wdata;
            saved_addr <= i_req_addr;
            saved_set <= req_set;
            saved_tag <= req_tag;
            saved_word_idx <= req_word_index;
            saved_victim_way <= victim_way;
            // start memory burst from line base, word 0
            mem_word_cnt <= 0;
            store_word_cnt <= 0;
            mem_addr_reg <= {i_req_addr[31:Offset], {Offset{1'b0}}};  // base address of the cache line (16-byte aligned for a way)
            mem_ren_reg <= 1'b1;
            state <= MEMORY;
          end
        end

        MEMORY: begin
        // Issue next read request if memory is ready
        if (i_mem_ready) begin
            mem_ren_reg <= 1'b1;
        end
        mem_word_cnt <= mem_word_cnt + 1;
        mem_addr_reg <= {saved_addr[31:Offset], {Offset{1'b0}}} + ((mem_word_cnt + 1) << 2);
        if (mem_word_cnt >= 3'b011) begin 
          mem_word_cnt <= 3'b011;  // stay at 3 if already reached max
          mem_addr_reg <= {saved_addr[31:Offset], {Offset{1'b0}}} + (3'b011 << 2);
        end
          // The data read from memory is valid
        if (i_mem_valid) begin
            if (!saved_victim_way)  // way 0 is invalid
              datas0[saved_set][store_word_cnt] <= i_mem_rdata;
            else  // way 1 is invalid
              datas1[saved_set][store_word_cnt] <= i_mem_rdata;
            store_word_cnt <= store_word_cnt + 1;
            state <= REFILL;
        end
        end 

        REFILL: begin 
            store_word_cnt <= store_word_cnt + 1;
            if (!saved_victim_way)  // way 0 is invalid
              datas0[saved_set][store_word_cnt] <= i_mem_rdata;
            else  // way 1 is invalid
              datas1[saved_set][store_word_cnt] <= i_mem_rdata;

            // When the cache way is filled with the 4 words accessed from memory
            if (store_word_cnt == D - 1) begin
              // finished refill for entire line
              // update tag/valid
              if (!saved_victim_way) begin  // way 0 is invalid
                tags0[saved_set] <= saved_tag;
                valid[saved_set][0] <= 1'b1;
                lru[saved_set] <= 1'b1;  // if lru is previously way 0, set it to way 1
              end else begin  // way 1 is invalid
                tags1[saved_set] <= saved_tag;
                valid[saved_set][1] <= 1'b1;
                lru[saved_set] <= 1'b0;
              end

              // 1. After line is filled, if the write enable signal rises for the cache, write the input data to cache
              if (saved_is_write) begin  // write enable 
                if (!saved_victim_way)  // way 0 is invalid
                  datas0[saved_set][saved_word_idx] <= merge_bytes(
                      datas0[saved_set][saved_word_idx], saved_wdata, saved_mask
                  );
                else  // way 1 is invalid
                  datas1[saved_set][saved_word_idx] <= merge_bytes(
                      datas1[saved_set][saved_word_idx], saved_wdata, saved_mask
                  );

                // 2. Write-through to memory for the written word
                mem_addr_reg  <= {saved_addr[31:2], 2'b00};
                mem_wdata_reg <= merge_bytes(32'b0, saved_wdata, saved_mask);
                if (i_mem_ready)  // When memory is ready to be written, issue write enable signal 
                  mem_wen_reg <= 1'b1;
              end
              // Else, if it was a read miss, nothing more to do for cache line fill
              // Done: go back to cache
              state <= CACHE;
              mem_word_cnt <= 3'b00;
              store_word_cnt <= 2'b00;
              mem_ren_reg <= 1'b0;
            end  
        end 
        default: state <= CACHE;
      endcase
    end
  end

endmodule
`default_nettype wire