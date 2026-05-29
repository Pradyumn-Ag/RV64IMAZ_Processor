`timescale 1ns/1ps

module twob_predictor #(
    parameter integer addr_size   = 7,
    parameter integer cache_depth = 128,
    parameter integer XLEN        = 64,
    parameter integer BP_PC_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // ── IFU Interface ────────────────────────────────────────
    input  wire [addr_size-1:0]   instr_tag_ifu,
    input  wire                   instr_tag_ifu_valid,
    output wire [XLEN-1:0]        bp_pc_out,
    output wire                   bp_dir,
    output wire                   bp_pc_out_valid,
   // output wire [addr_size-1:0]   bp_instr_tag_out,

    // ── EXU Interface ────────────────────────────────────────
    input  wire [addr_size-1:0]   instr_tag_exu,
    input  wire                   exu_br_dir,
    input  wire [XLEN-1:0]        exu_pc_in,
    input  wire                   exu_bp_strobe
);

    // =========================================================
    // Cache Memory
    // Each entry = BP_PC_WIDTH + 3 bits
    //
    //  [BP_PC_WIDTH+2 : 3] = Target PC  (BP_PC_WIDTH bits)
    //  [2]                 = CTR MSB
    //  [1]                 = CTR LSB
    //  [0]                 = Valid bit
    //
    // IMPORTANT: Three separate write paths, no conflicts:
    //   Path 1 (gen_btb)   → writes [BP_PC_WIDTH+2:3] and [0]
    //                         only on NEW entry (CTR==00)
    //   Path 2 (ctr_block) → writes [2:1] only
    //                         every cycle after branch resolves
    //   Path 3 (rst)       → resets ALL bits to 0
    // =========================================================
    reg [BP_PC_WIDTH+2:0] cache [0:cache_depth-1];

//    // =========================================================
//    // Internal Wires - IFU read path (combinational)
//    // =========================================================
//    wire [XLEN-1:0]      bp_pc_out_i;
//    wire                 bp_dir_i;
//    wire                 bp_pc_out_valid_i;
//    wire [addr_size-1:0] bp_instr_tag_out_i;

    // =========================================================
    // Internal Wires - Counter update path
    // =========================================================
    wire [1:0]           ctr_nxt_stt;
   // wire                 load_ctr;
  //  wire [addr_size-1:0] instr_tag_ctr;

    // =========================================================
    // Internal Reg - debug flag
    // =========================================================
    reg                  ctr_updated;

    // =========================================================
    // IFU Read Path - Pure Combinational
    //
    // All outputs gated by instr_tag_ifu_valid:
    //   valid=0 → outputs forced to 0 (stall/bubble safety)
    //   valid=1 → read from cache normally
    //
    // bp_dir = valid AND CTR_MSB
    //   CTR=00 → MSB=0 → predict NT
    //   CTR=01 → MSB=0 → predict NT
    //   CTR=10 → MSB=1 → predict T  ← threshold
    //   CTR=11 → MSB=1 → predict T
    // =========================================================
    assign bp_pc_out =
        instr_tag_ifu_valid ?
            {{(XLEN-BP_PC_WIDTH){1'b0}},
              cache[instr_tag_ifu][BP_PC_WIDTH+2:3]}
        : {XLEN{1'b0}};

    assign bp_dir =
        instr_tag_ifu_valid ?
            (cache[instr_tag_ifu][0] & cache[instr_tag_ifu][2])
        : 1'b0;

    assign bp_pc_out_valid =
        instr_tag_ifu_valid ?
            cache[instr_tag_ifu][0]
        : 1'b0;

//    assign bp_instr_tag_out =
//        instr_tag_ifu_valid ?
//            instr_tag_ifu
//        : {addr_size{1'b0}};

         //  bp_instr_tag_out  same as instr_tag_ifu

    // =========================================================
    // EXU Write Path - Generate Block
    //
    // FIX: Only drives cache[i][BP_PC_WIDTH+2:3] (target PC)
    //      and cache[i][0] (valid bit)
    //      Does NOT touch cache[i][2:1] (CTR) - avoids
    //      multiple-driver conflict with counter write-back
    //
    // Enable condition - ALL three must be true:
    //   1. exu_bp_strobe=1  → confirmed branch in EXU
    //   2. cache[i][2:1]==00 → entry is FRESH/EMPTY
    //   3. instr_tag_exu==i → tag matches this row
    //
    // If CTR != 00 entry already exists - PC not overwritten
    // Counter update handles existing entries separately
    // =========================================================
    genvar i;
    generate
        for (i = 0; i < cache_depth; i = i + 1) begin : gen_btb

            // ── Entry-level enable ────────────────────────────
            wire entry_en;
            assign entry_en =   exu_bp_strobe
                              & ~(|(cache[i][2:1]))
                              & (instr_tag_exu == i);

            // ── Write PC bits [BP_PC_WIDTH+2:3] ──────────────
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    cache[i][BP_PC_WIDTH+2:3] <= {BP_PC_WIDTH{1'b0}};
                end else if (entry_en) begin
                    cache[i][BP_PC_WIDTH+2:3] <= exu_pc_in[BP_PC_WIDTH-1:0];
                end
            end

            // ── Write Valid bit [0] ───────────────────────────
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    cache[i][0] <= 1'b0;
                end else if (entry_en) begin
                    cache[i][0] <= 1'b1;
                end
            end

            

        end
    endgenerate

        // REPLACE your counter write-back block with this:
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctr_updated <= 1'b0;
            // Single driver resets ALL CTR bits here
            for (j = 0; j < cache_depth; j = j + 1) begin
                cache[j][2:1] <= 2'b00;
            end
        end else begin
            if (exu_bp_strobe) begin
                cache[instr_tag_exu][2:1] <= ctr_nxt_stt;
                ctr_updated               <= 1'b1;
            end else begin
                ctr_updated <= 1'b0;
            end
        end
    end

    // =========================================================
    // Sub-module: twob_ctr
    //
    // Computes next saturating counter state combinationally
    // Registers output on posedge clk when strobe=1
    //
    // State transitions:
    //   00 + T  → 01    00 + NT → 00 (saturate)
    //   01 + T  → 10    01 + NT → 00
    //   10 + T  → 11    10 + NT → 01
    //   11 + T  → 11    11 + NT → 10 (saturate)
    // =========================================================
    twob_ctr counter (
//        .clk      (clk),
//        .rst_n    (rst_n),
//        .strobe   (exu_bp_strobe),
        .ctr      (exu_br_dir),
        .crnt_stt (cache[instr_tag_exu][2:1]),
        .next_stt (ctr_nxt_stt)
    );

    // =========================================================
    // Sub-module: load_flop
    //
    // Delays {exu_bp_strobe, instr_tag_exu} by exactly 1 cycle
    // This ensures counter write-back hits the correct cache
    // row one cycle after the branch resolves in EXU
    //
    // Cycle N  : din  = {exu_bp_strobe, instr_tag_exu}
    // Cycle N+1: dout = {load_ctr,      instr_tag_ctr}
    // =========================================================
//    dff_rst #(.WIDTH(1 + addr_size)) load_flop (
//        .clk   (clk),
//        .rst_n (rst_n),
//        .din   ({exu_bp_strobe,  instr_tag_exu}),
//        .dout  ({load_ctr,       instr_tag_ctr})
//    );

    // =========================================================
    // Sub-module: ifu_flop
    //
    // Registers all four IFU prediction outputs by 1 cycle
    // Aligns prediction with the fetch stage pipeline timing
    //
    // Bit packing (MSB to LSB):
    //   [XLEN+addr_size+1 : addr_size+2] = bp_pc_out
    //   [addr_size+1]                    = bp_dir
    //   [addr_size]                      = bp_pc_out_valid
    //   [addr_size-1 : 0]                = bp_instr_tag_out
    // =========================================================
//    dff_rst_vector #(.WIDTH(XLEN + 2 + addr_size)) ifu_flop (
//        .clk       (clk),
//        .rst_n     (rst_n),
//        .reset_val ({(XLEN + 2 + addr_size){1'b0}}),
//        .din       ({bp_pc_out_i,
//                     bp_dir_i,
//                     bp_pc_out_valid_i,
//                     bp_instr_tag_out_i}),
//        .dout      ({bp_pc_out,
//                     bp_dir,
//                     bp_pc_out_valid,
//                     bp_instr_tag_out})
//    );

endmodule