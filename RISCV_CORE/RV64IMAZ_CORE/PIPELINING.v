`timescale 1ns / 1ps
//==============================================================================
// Module     : PIPELINING
// Description: RV64 5-Stage Pipelined Processor - FPGA Top Module
//              Includes Clock Wizard, ILA, Hazard Unit, M-Extension
// Fixes Applied:
//   1. wire rst declared
//   2. All ILA probe wires assigned to real internal signals
//   3. ILA probe widths corrected (no wrong padding)
//   4. Single assign Instr_D1 = Instr_F (duplicate removed)
//   5. PCTarget_EE stays wire only
//   6. ILA probe count = 23, widths match signal widths exactly
//==============================================================================

module PIPELINING #(
    parameter WIDTH             = 64,
    parameter INSTRUCTION_WIDTH = 32
)(
    input  wire                     clk,       // Raw 100MHz from FPGA board pin
    input  wire                     ext_rst,    // Active-LOW reset button
    
//    // --- Existing outputs (Change 'reg' to 'wire' if driven by submodules/assigns) ---
//    output wire                     MemWrite_M_tb,  // MEM stage - write enable
//    output wire [WIDTH-1:0]         ALUResult_M_tb, // MEM stage - ALU output
    
    // --- Missing WB Stage Signals required by TB ---
    output wire [WIDTH-1:0]         PC_W_tb,        // PC in WB stage
    output wire [4:0]               RD_W_tb,        // Destination register in WB stage
    output wire [WIDTH-1:0]         Result_W_tb,    // Final data to be written to RegFile
    output wire                     RegWrite_W_tb  // Register write enable in WB stage
    
//    // --- Missing MEM Stage Signals required by TB ---
//    output wire [WIDTH-1:0]         WriteData_M_tb, // Data to be written to memory
    
//    // --- Missing AMO/A-Extension Signals required by TB ---
//    output wire                     IsAMO_M_tb,     // Flag indicating an AMO instruction in MEM
//    output wire                     SC_Succ_M_tb ,  // Store Conditional success flag in MEM
//    output wire [6:0]               OpcodeM_tb
////    // --- Board I/O ---
//   //   output wire [3:0]               led          // Board LED indicators (No trailing comma)
);



    // Your internal wires, pipeline registers, and logic go here...
    // =========================================================================
    // CLOCK & RESET
    // =========================================================================
   // wire clk;           // Clean clock from Clock Wizard MMCM
   // wire pll_locked ;    // HIGH when MMCM is stable
    wire rst;         // Active-LOW reset (released after PLL locks)
    wire RegWrite_W_gated;
    
    // These were output ports - now internal signals only
    wire [WIDTH-1:0]             Result_W;
    reg  [WIDTH-1:0]             ReadData_W;
    reg  [WIDTH-1:0]             WriteData_M;
    reg                          MemWrite_M;
    wire  [WIDTH-1:0]             PC_F;        // Changed to reg
    reg  [WIDTH-1:0]             ALUResult_M;
    wire [INSTRUCTION_WIDTH-1:0] Instr_D1;    // Instruction from the IM
    
 

//   clk_wiz_0 u_clk_wiz (
//        .clk_in1  (clk1),       // 100 MHz raw board clock
//        .clk_out1 (clk),        // De-skewed output clock
//        .resetn   (ext_rst),    // Port is now resetn, connect directly to board pin
//        .locked   (pll_locked)
//    );
//    assign rst = pll_locked & ext_rst; // Release reset only after PLL locks

//   (* ASYNC_REG = "TRUE" *)reg rst_meta, rst_sync;
//   always @(posedge clk or negedge pll_locked) begin
//    if (!pll_locked) begin
//        rst_meta <= 1'b0;
//        rst_sync <= 1'b0;
//    end else begin
//        rst_meta <= ext_rst;
//        rst_sync <= rst_meta;
//    end
//end
//assign rst = rst_sync;

//(* ASYNC_REG = "TRUE" *) reg [7:0] rst_shift;  // 8-bit shift register

//always @(posedge clk or negedge pll_locked or negedge ext_rst) begin
//    if (!pll_locked || !ext_rst)
//        rst_shift <= 8'b0;          // assert reset immediately
//    else
//        rst_shift <= {rst_shift[6:0], 1'b1};  // ✅ shift 1s not ext_rst
//end

//assign rst = rst_shift[7];  // only goes high after 8 clean cycles

//     assign led[0] = pll_locked;
//     assign led[1] = rst;
//     assign led[2] = 1'b0;
//     assign led[3] = 1'b0;
     
assign rst = ext_rst;

    // =========================================================================
    // HAZARD UNIT WIRES
    // =========================================================================
    wire       Stall_F;
    wire       Stall_D;
    wire       Stall_E;
    wire       Stall_M;
    wire       Flush_D;
    wire       Flush_E;
    wire       Flush_MEM;
    wire [1:0] ForwardA_E;
    wire [1:0] ForwardB_E;

    // =========================================================================
    // ILA PROBE WIRES  (widths match real signal widths - no padding)
    // =========================================================================

    // IF Stage
    wire [WIDTH-1:0]             PC_F_probe;
    wire [INSTRUCTION_WIDTH-1:0] Instr_F_probe;

    // ID Stage
    wire [WIDTH-1:0]             PC_D_probe;
    wire [INSTRUCTION_WIDTH-1:0] Instr_D_probe;
    wire [WIDTH-1:0]             RD1_D_probe;
    wire [WIDTH-1:0]             RD2_D_probe;

    // EX Stage
    wire [WIDTH-1:0]             PC_E_probe;
    wire [WIDTH-1:0]             ALUResult_E_probe;
    wire [WIDTH-1:0]             SrcA_E_probe;
    wire [WIDTH-1:0]             SrcB_E_probe;
    wire [3:0]                   ALUControl_E_probe;
    wire [1:0]                   ForwardA_E_probe;
    wire [1:0]                   ForwardB_E_probe;

    // MEM Stage
    wire [WIDTH-1:0]             ALUResult_M_probe;
    wire [WIDTH-1:0]             WriteData_M_probe;
    wire                         MemWrite_M_probe;

    // WB Stage
    wire [WIDTH-1:0]             Result_W_probe;
    wire [4:0]                   RdW_probe;

    // Hazard & Control
    wire                         StallF_probe;
    wire                         StallD_probe;
    wire                         FlushE_probe;
    wire                         FlushD_probe;
    wire                         PCSrc_probe;
    
    // =========================================================================
    // BRANCH PREDICTOR WIRES
    // =========================================================================

    // IFU Side
   // wire [6:0]        instr_tag_ifu;
    wire              instr_tag_ifu_valid;
    wire [WIDTH-1:0]  bp_pc_out;
    wire              bp_dir;
    wire              bp_pc_out_valid;
 //   wire [6:0]        bp_instr_tag_out;
    
    // EXU Side
    wire [6:0]        instr_tag_exu;
    wire              exu_bp_strobe;
    wire              exu_br_dir;
    wire [WIDTH-1:0]  exu_pc_in;
    
    // PC Mux intermediate
    wire [WIDTH-1:0]  PCNext_bp;
    
    // Mispredict Detection
    wire              branch_actually_taken;
    wire              branch_actually_nt;
    wire              bp_mispredict_taken;
    wire              bp_mispredict_nt;
    wire              bp_mispredict;
    wire              PCSrc_corrected;
    reg               PCSrc_corrected_r;   // one-cycle delayed version of PCSrc_corrected

    // =========================================================================
    // =========================================================================
    // 1. FETCH STAGE (IF)
    // =========================================================================
    // =========================================================================

    wire [WIDTH-1:0]             PCNext_F;
    wire [WIDTH-1:0]             PCNext_normal;   // existing branch/jump result
    wire [INSTRUCTION_WIDTH-1:0] Instr_F;
    wire [WIDTH-1:0]             PCPlus4_F;
    wire [WIDTH-1:0]             PCTarget_EE;  // Driven by EX stage MUX m5 - wire only
  //  wire                         PCSrc_E;
    wire                         csr_pc_en;      // trap/mret → flush + PC redirect
    wire [WIDTH-1:0]             PC_Next_csr;    // redirect target

    // ── Single assignment of Instr_D1 ────────────────────────────────────────
    
    
    // =========================================================================
    // BRANCH PREDICTOR CONNECTIONS
    // =========================================================================
    
    // IFU Side
   // assign instr_tag_ifu       = PC_F[6:0];
    assign instr_tag_ifu_valid = ~Stall_F & ~Flush_D;
    
    
     // =========================================================================
     // BRANCH PREDICTOR INSTANTIATION
     // =========================================================================
    twob_predictor #(
    .addr_size   (7),
    .cache_depth (128),
    .XLEN        (64),       
    .BP_PC_WIDTH (32)       
    ) bp_unit (
        .clk                 (clk),
        .rst_n               (rst),
        // IFU side
        .instr_tag_ifu       (PC_F[6:0]),
        .instr_tag_ifu_valid (instr_tag_ifu_valid),
        .bp_pc_out           (bp_pc_out),
        .bp_dir              (bp_dir),
        .bp_pc_out_valid     (bp_pc_out_valid),
        //.bp_instr_tag_out    (bp_instr_tag_out),
        // EXU side
        .instr_tag_exu       (instr_tag_exu),
        .exu_br_dir          (exu_br_dir),
        .exu_pc_in           (exu_pc_in),
        .exu_bp_strobe       (exu_bp_strobe)
    );
    

    PC_1 p1 (
        .Enable (Stall_F ),
        .clk    (clk),
        .rst    (rst),
        .PCNext (PCNext_F),
        .PC     (PC_F)
    );

    ADDER a1 (
        .input1 (PC_F),
        .input2 (64'd4),
        .y      (PCPlus4_F)
    );

    INSTRUCTION_MEMORY IM1 (
        .PC    (PC_F),
        .clk(clk),
        .Stall_F(Stall_F),
        .Instr (Instr_F)  // Changing Instr_F to Instr_D1
      //  .PCSrc_corrected (PCSrc_corrected)
    );
    
    // NEW MUX 1: Branch Predictor selects between PC+4 and predicted target
    MUX_2x1 m_bp (
        .a0  (PCPlus4_F),
        .a1  (bp_pc_out),
        .sel (bp_dir & bp_pc_out_valid & ~PCSrc_corrected & ~csr_pc_en & ~Stall_F),
        .y   (PCNext_bp)
    );
        
        
 // ── Correction target selector ────────────────────────────
// bp_mispredict_nt: predicted T but actually NT → go to PCPlus4_E
// bp_mispredict_taken or Jump               → go to PCTarget_EE
wire [WIDTH-1:0] PCCorrect;


// MODIFIED m1: uses PCCorrect instead of PCTarget_EE directly
MUX_2x1 m1 (
    .a0  (PCNext_bp),       // normal flow (BP or PC+4)
    .a1  (PCCorrect),       // ← CHANGED from PCTarget_EE
    .sel (PCSrc_corrected),
    .y   (PCNext_normal)
);
    
//     // MODIFIED m1: Mispredict/Jump correction overrides BP output
//    MUX_2x1 m1 (
//        .a0  (PCNext_bp),        // CHANGED from PCPlus4_F
//        .a1  (PCTarget_EE),
//        .sel (PCSrc_corrected),  // CHANGED from PCSrc_E
//        .y   (PCNext_normal)
//    );

    // NEW: CSR redirect overrides everything
    MUX_2x1 m1_csr (
        .a0  (PCNext_normal),
        .a1  (PC_Next_csr),
        .sel (csr_pc_en),
        .y   (PCNext_F)        // this goes into PC_1
    );
    

//    MUX_2x1 m1 (
//        .a0  (PCPlus4_F),
//        .a1  (PCTarget_EE),
//        .sel (PCSrc_E),
//        .y   (PCNext_F)
//    );

    // ── IF/ID Pipeline Register ───────────────────────────────────────────────
    reg [INSTRUCTION_WIDTH-1:0] Instr_D;
    reg [WIDTH-1:0]             PC_D;
    reg [WIDTH-1:0]             PCPlus4_D;
    reg [4:0]                   Rd_W;
    reg                         RegWrite_W;
//    reg [1:0]                   count_F;


    // 1. Declare the delay register
    reg [63:0] PC_Delayed_F;
    reg bp_dir_Delayed_F;
    reg [63:0] PCPlus4_Delayed_F;

    
       // ── IF/ID new regs ─────────────────────────────────────────
    reg [6:0]  instr_tag_D_r;
    reg        bp_dir_D;
    
    
    
    
//    always @(posedge clk) begin
//    if (~rst) begin
//        PC_Delayed_F      <= 64'b0;
//        PCPlus4_Delayed_F <= 64'b0;
//        bp_dir_Delayed_F  <= 1'b0;
//    end
//    else if (csr_pc_en) begin
//        PC_Delayed_F      <= PC_Next_csr;       // CSR trap/mret redirect
//        PCPlus4_Delayed_F <= PC_Next_csr + 4;
//        bp_dir_Delayed_F  <= 1'b0;
//    end
//    else if (PCSrc_corrected) begin
//        PC_Delayed_F      <= PCTarget_EE;       // ← KEY FIX: use target, not 0
//        PCPlus4_Delayed_F <= PCTarget_EE + 4;
//        bp_dir_Delayed_F  <= 1'b0;
//    end
//    else if (~Stall_F) begin
//        PC_Delayed_F      <= PC_F;
//        PCPlus4_Delayed_F <= PCPlus4_F;
//        bp_dir_Delayed_F  <= bp_dir;
//    end
//end
    
    

// 2. Delay the PC by one clock cycle
always @(posedge clk ) begin // (Use negedge if your reset is active low)
    if (~rst || csr_pc_en || PCSrc_corrected) begin
        PC_Delayed_F <= 64'b0;
     //   Instr_F <= 64'b0;
    end else if(~Stall_F) begin
        PC_Delayed_F <= PC_F; // PC_F waits here for 1 cycle
       // Instr_F <= Instr_D1;  // Changed to this
    end
//    else begin
//        PC_Delayed_F <= PC_Delayed_F;// when stall 
//    end
end

    
    
    always @(posedge clk ) begin // (Use negedge if your reset is active low)
    if (~rst || csr_pc_en || PCSrc_corrected) begin
        bp_dir_Delayed_F <= 64'b0;
    end else if(~Stall_F) begin
        bp_dir_Delayed_F <= bp_dir; // PC_F waits here for 1 cycle
    end
//    else begin
//        PC_Delayed_F <= PC_Delayed_F;// when stall 
//    end
end



// 2. Delay the PC+4 by one clock cycle
always @(posedge clk ) begin // (Use negedge if your reset is active low)
    if (~rst || csr_pc_en || PCSrc_corrected) begin
        PCPlus4_Delayed_F <= 64'b0;
     end else if(~Stall_F) begin
        PCPlus4_Delayed_F  <= PCPlus4_F; // PC_F waits here for 1 cycle
    end
//    else begin
//        PCPlus4_Delayed_F <= PCPlus4_Delayed_F;
//    end
end

//    always @(posedge clk) begin
always @(posedge clk) begin

        if (~rst) begin
            Instr_D   <= {INSTRUCTION_WIDTH{1'b0}};
            PC_D      <= {WIDTH{1'b0}};
            PCPlus4_D <= {WIDTH{1'b0}};
//            count_F     <= 2'b00        ;
            //Branch Predictor
            instr_tag_D_r <= 7'b0;
            bp_dir_D      <= 1'b0;
           
        end
        else if (Flush_D  || PCSrc_corrected_r) begin
            Instr_D   <= {INSTRUCTION_WIDTH{1'b0}};
            PC_D      <= {WIDTH{1'b0}};
            PCPlus4_D <= {WIDTH{1'b0}};
//            count_F   <= 2'b00;
            //Branch Predictor
            instr_tag_D_r <= 7'b0;
            bp_dir_D      <= 1'b0;
           
        end
        else if (~Stall_D) begin //logic changed
            Instr_D   <= Instr_F;
            PC_D      <= PC_Delayed_F;
            PCPlus4_D <= PCPlus4_Delayed_F;
            //Branch prediction addition
            instr_tag_D_r <= PC_Delayed_F[6:0];   // tag = lower 7 bits of fetch PC
            bp_dir_D      <= bp_dir_Delayed_F;      // store what BP predicted
            
        end
    end

    // =========================================================================
    // =========================================================================
    // 2. DECODE STAGE (ID)
    // =========================================================================
    // =========================================================================

    wire [WIDTH-1:0] RD1_D;
    wire [WIDTH-1:0] RD2_D;
    wire [WIDTH-1:0] ImmExt_Wire;
    wire [WIDTH-1:0] ImmExt_D;
    wire [4:0]       Rd_D;
    wire [4:0]       Rs1_D;
    wire [4:0]       Rs2_D;
    wire [2:0]       ImmSrc_D;
    wire [3:0]       ALUControl_D;
    wire [1:0]       ResultSrc_D;
    wire             RegWrite_D;
    wire             Jump_D;
    wire             Branch_D;
    wire             MemWrite_D;
    wire             ALUSrc_D;

    // M-Extension control wires
    wire             start_mul_D;
    wire             start_div_D;
    wire [1:0]       Exec_Sel_D;
    wire [2:0]       mul_op_sel_D;
    wire             is_lr_D;
    wire             is_sc_D;
    wire             is_amo_D;
    wire [4:0]       amo_alu_op_D;
    wire             is_mem_read_D;
    
    // ── CSR wires ──────────────────────────────────────────────
    wire             csr_en_D,    csr_en_E;
    wire [1:0]       funct3b21_D, funct3b21_E;
    wire             wb_sel_csr_D, wb_sel_csr_E;
    wire [11:0]      csr_addr_E;     // inst[31:20] pipelined to EX
    wire [WIDTH-1:0] csr_rd;         // CSR old value → WB mux
    wire             illegal_instr;  // from CSR module
    // ───────────────────────────────────────────────────────────      

    assign Rs1_D   = Instr_D[19:15];
    assign Rs2_D   = Instr_D[24:20];
    assign Rd_D    = Instr_D[11:7];
    assign ImmExt_D = ImmExt_Wire;

    REGISTER_FILE RF1 (
        .clk      (clk),
        .rst      (rst),
        .RegWrite (RegWrite_W_gated),  // ← use gated version
        .A1       (Instr_D[19:15]),
        .A2       (Instr_D[24:20]),
        .A3       (Rd_W),
        .WD3      (Result_W),
        .RD1      (RD1_D),
        .RD2      (RD2_D)
    );

    EXTEND_UNIT EU (
        .Instr   (Instr_D[31:7]),
        .ImmSrc  (ImmSrc_D),
        .ImmExt  (ImmExt_Wire)
    );

    CONTROL_UNIT CU (
        .Instr      (Instr_D),
        .RegWrite   (RegWrite_D),
        .ResultSrc  (ResultSrc_D),
        .Jump       (Jump_D),
        .Branch     (Branch_D),
        .MemWrite   (MemWrite_D),
        .ALUControl (ALUControl_D),
        .ALUSrc     (ALUSrc_D),
        .ImmSrc     (ImmSrc_D),
        .start_mul  (start_mul_D),
        .start_div  (start_div_D),
        .Exec_Sel   (Exec_Sel_D),
        .mul_op_sel (mul_op_sel_D),
        .is_lr      (is_lr_D),
        .is_sc      (is_sc_D),
        .is_amo     (is_amo_D),
        .amo_alu_op (amo_alu_op_D),
        .is_mem_read(is_mem_read_D),
        .csr_en      (csr_en_D),
        .funct3b21   (funct3b21_D),
        .wb_sel_csr  (wb_sel_csr_D)
    );

    // ── ID/EX Pipeline Register ───────────────────────────────────────────────
    reg                        RegWrite_E;
    reg [1:0]                  ResultSrc_E;
    reg                        Jump_E;
    reg                        Branch_E;
    reg                        MemWrite_E;
    reg [3:0]                  ALUControl_E;
    reg                        ALUSrc_E;
    reg [WIDTH-1:0]            RD1_E;
    reg [WIDTH-1:0]            RD2_E;
    reg [WIDTH-1:0]            PC_E;
    reg [4:0]                  Rs1_E;
    reg [4:0]                  Rs2_E;
    reg [4:0]                  Rd_E;
    reg [WIDTH-1:0]            PCPlus4_E;
    reg [6:0]                  op_E;
    reg [2:0]                  funct3_E;
    reg [1:0]                  MemOffset_E;
    reg [WIDTH-1:0]            ImmExt_E;
    reg                        start_mul_E;
    reg                        start_div_E;
    reg [1:0]                  Exec_Sel_E;
    reg [2:0]                  mul_op_sel_E;
    reg                        is_word_E;
    reg                        is_lr_E;
    reg                        is_sc_E;
    reg                        is_amo_E;
    reg [4:0]                  amo_alu_op_E;
    reg                        is_mem_read_E;
    
    
    // ── NEW CSR pipeline regs ───────────────────────────────
    reg             csr_en_E_r;
    reg [1:0]       funct3b21_E_r;
    reg             wb_sel_csr_E_r;
    reg [11:0]      csr_addr_E_r;
    
    // ────────────────────────────────────────────────────────
    
    //Branch Predictor registers
    reg [6:0]  instr_tag_E_r;
    reg        bp_dir_E;        // prediction arrives at EX stage
  //  reg        bp_valid_E;      // was there a valid prediction?

//    always @(posedge clk) begin
always @(posedge clk) begin

        if (~rst || Flush_E) begin
            RegWrite_E      <= 1'b0;
            ResultSrc_E     <= 2'b00;
            MemWrite_E      <= 1'b0;
            Jump_E          <= 1'b0;
            Branch_E        <= 1'b0;
            ALUControl_E    <= 4'b0;
            ALUSrc_E        <= 1'b0;
            op_E            <= 7'b0;
            funct3_E        <= 3'b0;
            MemOffset_E     <= 2'b0;
            start_mul_E     <= 1'b0;
            start_div_E     <= 1'b0;
            Exec_Sel_E      <= 2'b0;
            mul_op_sel_E    <= 3'b0;
            is_word_E       <= 1'b0;
            is_lr_E         <= 1'b0;
            is_sc_E         <= 1'b0;
            is_amo_E        <= 1'b0;
            amo_alu_op_E    <= 5'b0;
            RD1_E           <= {WIDTH{1'b0}};
            RD2_E           <= {WIDTH{1'b0}};
            PC_E            <= {WIDTH{1'b0}};
            Rs1_E           <= 5'b0;
            Rs2_E           <= 5'b0;
            Rd_E            <= 5'b0;
            PCPlus4_E       <= {WIDTH{1'b0}};
            ImmExt_E        <= {WIDTH{1'b0}};
            is_mem_read_E   <= 1'b0;
            csr_en_E_r      <= 1'b0;
            funct3b21_E_r   <= 2'b0;
            wb_sel_csr_E_r  <= 1'b0;
            csr_addr_E_r    <= 12'b0;
            //Branch Predictor
            bp_dir_E      <= 1'b0;
        //    bp_valid_E    <= 1'b0;
            instr_tag_E_r <= 7'b0;
            
            
        end
        else if (~Stall_E) begin
            RegWrite_E     <= RegWrite_D;
            ResultSrc_E    <= ResultSrc_D;
            MemWrite_E     <= MemWrite_D;
            Jump_E         <= Jump_D;
            Branch_E       <= Branch_D;
            ALUControl_E   <= ALUControl_D;
            ALUSrc_E       <= ALUSrc_D;
            op_E           <= Instr_D[6:0];
            funct3_E       <= Instr_D[14:12];
            MemOffset_E    <= Instr_D[13:12];
            start_mul_E    <= start_mul_D;
            start_div_E    <= start_div_D;
            Exec_Sel_E     <= Exec_Sel_D;
            mul_op_sel_E   <= mul_op_sel_D;
            is_word_E      <= (Instr_D[6:0] == 7'b0111011);
            is_lr_E        <= is_lr_D;
            is_sc_E        <= is_sc_D;
            is_amo_E       <= is_amo_D;
            amo_alu_op_E   <= amo_alu_op_D;
            RD1_E          <= RD1_D;
            RD2_E          <= RD2_D;
            PC_E           <= PC_D;
            PCPlus4_E      <= PCPlus4_D;
            ImmExt_E       <= ImmExt_D;
            Rs1_E          <= Instr_D[19:15];
            Rs2_E          <= Instr_D[24:20];
            Rd_E           <= Instr_D[11:7];
            is_mem_read_E  <=is_mem_read_D;
            csr_en_E_r     <= csr_en_D;
            funct3b21_E_r  <= funct3b21_D;
            wb_sel_csr_E_r <= wb_sel_csr_D;
            csr_addr_E_r   <= Instr_D[31:20];   // CSR address
            //Branch Predictor
            bp_dir_E      <= bp_dir_D;
          //  bp_valid_E    <= bp_pc_out_valid; // was cache hit at fetch?
            instr_tag_E_r <= instr_tag_D_r;   // pass tag D→E
        end
    end
    
    
        assign csr_en_E     = csr_en_E_r;
        assign funct3b21_E  = funct3b21_E_r;
        assign wb_sel_csr_E = wb_sel_csr_E_r;
        assign csr_addr_E   = csr_addr_E_r;
        
        
        
    // =========================================================================
    // =========================================================================
    // 3. EXECUTE STAGE (EX)
    // =========================================================================
    // =========================================================================

    wire [WIDTH-1:0] SrcA_E;
    wire [WIDTH-1:0] SrcA_EE;
    wire [WIDTH-1:0] SrcB_E;
    wire [WIDTH-1:0] WriteData_E;
    wire [WIDTH-1:0] ALUResult_E;
    wire [WIDTH-1:0] PCTarget_E;
    wire [WIDTH-1:0] Output_m9;
    wire             Zero_E;

    // M-Extension outputs
    wire [WIDTH-1:0] Mul_Result_E;
    wire [WIDTH-1:0] Div_Result_E;
    wire             Mul_Done_E;
    wire             Div_Done_E;
    wire             Mul_Busy_E;
    wire             Div_Busy_E;
    // ── CSR data: zimm uses pipelined imm, RS1 uses forwarded value ──
    wire [WIDTH-1:0] csr_data_final;
    
    assign csr_data_final = funct3_E[2]                  // funct3[2]=1 means immediate variant
                        ? {59'b0, Rs1_E}   // zimm = lower 5 bits of csr_addr_E
                        : SrcA_EE;                    // RS1 = forwarded value from m7 mux
    
    // EXU Side
    assign instr_tag_exu  = instr_tag_E_r;    // from ID/EX pipeline reg
    assign exu_bp_strobe  = Branch_E;          // high when branch in EX
    assign exu_br_dir     = Zero_E & Branch_E; // actual outcome
    assign exu_pc_in      = PCTarget_EE;       // actual target (already exists)
    
    // =========================================================================
    // MISPREDICT DETECTION
    // =========================================================================
    assign branch_actually_taken = Branch_E &  Zero_E;
    assign branch_actually_nt    = Branch_E & ~Zero_E;
    
    assign bp_mispredict_taken   = Branch_E & branch_actually_taken & ~bp_dir_E;
    assign bp_mispredict_nt      = Branch_E & branch_actually_nt    &  bp_dir_E;
    assign bp_mispredict         = bp_mispredict_taken | bp_mispredict_nt;
    
    // Replaces old PCSrc_E for flush/redirect decisions
    assign PCSrc_corrected       = bp_mispredict | Jump_E;
    
    always @(posedge clk) begin
        if (~rst)
            PCSrc_corrected_r <= 1'b0;
        else
            PCSrc_corrected_r <= PCSrc_corrected;
    end
    
   // assign Instr_F = PCSrc_corrected ? 64'b0 : Instr_D1;
    
    assign PCCorrect = bp_mispredict_nt ? PCPlus4_E   // sequential fallthrough
                                    : PCTarget_EE; // actual branch/jump target
    
    
   // assign PCSrc_E = ((Jump_E || (Branch_E && Zero_E)) === 1'b1) ? 1'b1 : 1'b0;
    
    // ── CSR Register File ───────────────────────────────────
    CSR_Register_File #(
        .DATA_BUS_WIDTH (64)
    ) CSR_RF (
        .clk                 (clk),
        .reset               (rst),      
        .csr_en              (csr_en_E),
        .funct3b21           (funct3b21_E),
        .csr_addr            (csr_addr_E),
        .csr_data            (csr_data_final),
        .PC                  (PC_E),
        .illegal_instruction (illegal_instr),
        .pc_en               (csr_pc_en),
        .RD                  (csr_rd),
        .PC_Next             (PC_Next_csr)
    );
 
    ADDER PC_TARGET (
        .input1 (PC_E),
        .input2 (ImmExt_E),
        .y      (PCTarget_E)
    );

    MUX_2x1 m2 (
        .a0  (WriteData_E),
        .a1  (ImmExt_E),
        .sel (ALUSrc_E),
        .y   (SrcB_E)
    );

    ALU A (
        .SrcA       (SrcA_E),
        .SrcB       (SrcB_E),
        .funct3     (funct3_E),
        .Opcode     (op_E),
        .ALUControl (ALUControl_E),
        .zero       (Zero_E),
        .ALUResult  (ALUResult_E)
    );

    // JALR target vs branch target select
    MUX_2x1 m5 (
        .a0  (PCTarget_E),
        .a1  (ALUResult_E),
        .sel (op_E == 7'b1100111),
        .y   (PCTarget_EE)
    );

    // AUIPC / LUI select
    MUX_3x1 m6 (
        .a0  (SrcA_EE),
        .a1  (PC_E),
        .a2  ({WIDTH{1'b0}}),
        .sel ({(op_E == 7'd55), (op_E == 7'd23)}),
        .y   (SrcA_E)
    );

    // Forwarding MUX - SrcA
    MUX_3x1 m7 (
        .a0  (RD1_E),
        .a1  (Result_W),
        .a2  (ALUResult_M),
        .sel (ForwardA_E),
        .y   (SrcA_EE)
    );

    // Forwarding MUX - SrcB
    MUX_3x1 m8 (
        .a0  (RD2_E),
        .a1  (Result_W),
        .a2  (ALUResult_M),
        .sel (ForwardB_E),
        .y   (WriteData_E)
    );

    // ── M-Extension Block ─────────────────────────────────────────────────────
    RV64M_EXTENSION #(
        .WIDTH (64)
    ) m_ext_unit (
        .clk        (clk),
        .rst        (rst),
        .mul_valid  (start_mul_E),
        .div_valid  (start_div_E),
        .op_sel     (mul_op_sel_E),
        .is_word    (is_word_E),
        .rs1_data   (SrcA_E),
        .rs2_data   (SrcB_E),
        .mul_result (Mul_Result_E),
        .mul_ready  (Mul_Done_E),
        .mul_busy   (Mul_Busy_E),
        .div_busy   (Div_Busy_E),
        .div_result (Div_Result_E),
        .div_ready  (Div_Done_E)
    );

    // Execution result select: ALU / MUL / DIV
    MUX_3x1 m9 (
        .a0  (ALUResult_E),
        .a1  (Mul_Result_E),
        .a2  (Div_Result_E),
        .sel (Exec_Sel_E),
        .y   (Output_m9)
    );

    // ── EX/MEM Pipeline Register ──────────────────────────────────────────────
    reg [WIDTH-1:0] PC_M;
    reg [4:0]       Rd_M;
    reg [WIDTH-1:0] PCPlus4_M;
    reg             RegWrite_M;
    reg [1:0]       ResultSrc_M;
    reg [6:0]       op_M;
    reg [2:0]       funct3_M;
    reg [1:0]       MemOffset_M;
    reg [WIDTH-1:0] RD1_M;
    reg [WIDTH-1:0] RD2_M;
    reg             is_lr_M;
    reg             is_sc_M;
    reg             is_amo_M;
    reg [4:0]       amo_alu_op_M;
    reg             is_mem_read_M;
    reg             wb_sel_csr_M;
    reg [WIDTH-1:0] csr_rd_M;

//    always @(posedge clk) begin
always @(posedge clk) begin

        if (~rst || Flush_MEM || csr_pc_en) begin
            RegWrite_M    <= 1'b0;
            ResultSrc_M   <= 2'b00;
            MemWrite_M    <= 1'b0;
            op_M          <= 7'b0;
            funct3_M      <= 3'b0;
            MemOffset_M   <= 2'b0;
            is_lr_M       <= 1'b0;
            is_sc_M       <= 1'b0;
            is_amo_M      <= 1'b0;
            amo_alu_op_M  <= 5'b0;
            ALUResult_M   <= {WIDTH{1'b0}};
            WriteData_M   <= {WIDTH{1'b0}};
            Rd_M          <= 5'b0;
            PCPlus4_M     <= {WIDTH{1'b0}};
            RD1_M         <= {WIDTH{1'b0}};
            RD2_M         <= {WIDTH{1'b0}};
                          
            //Extra       
            PC_M          <= {WIDTH{1'b0}};
            is_mem_read_M <= 1'b0;
            wb_sel_csr_M  <= 1'b0;
            csr_rd_M      <= {WIDTH{1'b0}};
            
       end     
            
        else if (~Stall_E) begin
            RegWrite_M   <= RegWrite_E;
            ResultSrc_M  <= ResultSrc_E;
            MemWrite_M   <= MemWrite_E;
            op_M         <= op_E;
            funct3_M     <= funct3_E;
            MemOffset_M  <= MemOffset_E;
            is_lr_M      <= is_lr_E;
            is_sc_M      <= is_sc_E;
            is_amo_M     <= is_amo_E;
            amo_alu_op_M <= amo_alu_op_E;
            ALUResult_M  <= wb_sel_csr_E ? csr_rd : Output_m9; 
            WriteData_M  <= WriteData_E;
            Rd_M         <= Rd_E;
            PCPlus4_M    <= PCPlus4_E;
            RD1_M        <= SrcA_E;
            RD2_M        <= SrcB_E;
            
            //
            PC_M         <= PC_E;
            is_mem_read_M<= is_mem_read_E;
            wb_sel_csr_M <= wb_sel_csr_E;
            csr_rd_M     <= csr_rd;
            
        end
    end

    // =========================================================================
    // =========================================================================
    // 4. MEMORY STAGE (MEM)
    // =========================================================================
    // =========================================================================

    wire [WIDTH-1:0] ReadData_M;
    wire [WIDTH-1:0] Load_Mux_M;
    wire             valid;
    wire [WIDTH-1:0] reservation_reg;
    wire [WIDTH-1:0] add_M;
    wire [WIDTH-1:0] logic1_M;
    wire [WIDTH-1:0] ReadData_DM;
    wire [WIDTH-1:0] WriteData_DM;
    wire [WIDTH-1:0] AMO_Result_M;
    wire [1:0]       mux3_11;
    wire             amo_stall_done_M;
    wire             mem_read_M;
    
    assign mem_read_M =(is_amo_M && !amo_stall_done_M);

    
    assign mux3_11  = is_sc_M  ? 2'b01 :
                      is_amo_M ? 2'b10 : 2'b00;

    assign logic1_M = is_sc_M ?
                      ((valid && (RD1_M == reservation_reg)) ? 64'd0 : 64'd1) :
                      64'd0;

    RESERVATION_REGISTER RV (
        .clk             (clk),
        .Stall_M         (Stall_M),     
        .rst             (rst),
        .is_lr           (is_lr_M),
        .is_sc           (is_sc_M),
        .add             (RD1_M),
        .valid           (valid),
        .reservation_reg (reservation_reg)
    );

    DATA_MEMORY DM1 (
        .clk             (clk),
        .ALUResult       (add_M),
        .funct3          (funct3_M),
        .Opcode          (op_M),
        .WriteData       (WriteData_DM),
        .is_amo          (is_amo_M),
        .amo_stall_done  (amo_stall_done_M),
        .MemWrite        (MemWrite_M),
        .Offset          (MemOffset_M),
        .sc_store_valid  (is_sc_M && (valid && (RD1_M == reservation_reg))),
        .ReadData        (ReadData_DM)
    );

    AMO_ALU AA (
        .RD2_M        (RD2_M),
        .MemData_M    (ReadData_DM),
        .amo_alu_op_M (amo_alu_op_M),
        .AMO_Result   (AMO_Result_M)
    );

    MUX_8x1 m3 (
        .a0  ({{56{ReadData_DM[7]}},  ReadData_DM[7:0]}),   // LB
        .a1  ({{48{ReadData_DM[15]}}, ReadData_DM[15:0]}),  // LH
        .a2  ({{32{ReadData_DM[31]}}, ReadData_DM[31:0]}),  // LW
        .a3  (ReadData_DM),                                  // LD
        .a4  ({{56{1'b0}}, ReadData_DM[7:0]}),              // LBU
        .a5  ({{48{1'b0}}, ReadData_DM[15:0]}),             // LHU
        .a6  ({{32{1'b0}}, ReadData_DM[31:0]}),             // LWU
        .sel (funct3_M),
        .y   (Load_Mux_M)
    );

    MUX_2x1 m10 (
        .a0  (ALUResult_M),
        .a1  (RD1_M),
        .sel (is_lr_M || is_sc_M || is_amo_M),
        .y   (add_M)
    );

    MUX_3x1 m11 (
        .a0  (WriteData_M),
        .a1  (RD2_M),
        .a2  (AMO_Result_M),
        .sel (mux3_11),
        .y   (WriteData_DM)
    );

    MUX_2x1 m12 (
        .a0  (ReadData_DM),
        .a1  (logic1_M),
        .sel (is_sc_M),
        .y   (ReadData_M)
    );

    
    // ── MEM/WB Pipeline Register ──────────────────────────────────────────────
    reg [1:0]       ResultSrc_W;
    reg [WIDTH-1:0] ALUResult_W;
    reg [WIDTH-1:0] PCPlus4_W;
    reg [WIDTH-1:0] Load_Mux_W;
    reg [WIDTH-1:0] PC_W;
    reg             is_sc_W;
    reg             logic1_M_W;
    wire[WIDTH-1:0] ReadData_DM_W;
    reg             wb_sel_csr_W;
    reg [WIDTH-1:0] csr_rd_W;
    wire[WIDTH-1:0] Result_W_mux;
    
//    reg count;

    assign ReadData_DM_W = ReadData_DM;
    
//        wire mem_stall;
//    assign mem_read_M = 
//    // Standard loads
//    is_lb_M  || is_lh_M  || is_lw_M  || is_ld_M  ||
//    is_lbu_M || is_lhu_M || is_lwu_M ||
//    // Load-Reserved
//    is_lr_w_M || is_lr_d_M ||
//    // ALL AMO instructions (read-modify-write)
//    is_amo_M;
    
//    reg mem_stall_done;
//    always @(posedge clk) begin
//    if (~rst)
//        mem_stall_done <= 0;
//    else if (mem_read_M && !mem_stall_done)
//        mem_stall_done <= 1;   // second cycle - latch now
//    else
//        mem_stall_done <= 0;   // reset for next instruction
//end


// In your MEM/WB pipeline register, gate RegWrite for SC:
// SC should only write back ONCE - when sc_result is final

// Find where you generate RegWrite_W and add:


reg sc_already_written;
always @(posedge clk) begin
    if (~rst)
        sc_already_written <= 0;
    else if (is_sc_W && RegWrite_W)
        sc_already_written <= 1;
    else if (!is_sc_W)
        sc_already_written <= 0;
end


assign RegWrite_W_gated = RegWrite_W && !(is_sc_W && sc_already_written);
//    always @(posedge clk) begin
    always @(posedge clk) begin

        if (~rst) begin
            RegWrite_W  <= 1'b0;
            ResultSrc_W <= 2'b00;
            ALUResult_W <= {WIDTH{1'b0}};
            ReadData_W  <= {WIDTH{1'b0}};
            PCPlus4_W   <= {WIDTH{1'b0}};
            Rd_W        <= 5'b0;
            Load_Mux_W  <= {WIDTH{1'b0}};
            //
            PC_W        <= {WIDTH{1'b0}};   
            is_sc_W     <= 1'b0;
            logic1_M_W  <= 1'b0;
            wb_sel_csr_W<= 1'b0;
            csr_rd_W    <= {WIDTH{1'b0}};
//            count       <= 1'b0;
        end
         else if(~Stall_M)begin
            RegWrite_W  <= RegWrite_M;
            ResultSrc_W <= ResultSrc_M;
            ALUResult_W <= ALUResult_M;
            ReadData_W  <= ReadData_M;
            PCPlus4_W   <= PCPlus4_M;
            Rd_W        <= Rd_M;
            Load_Mux_W  <= Load_Mux_M;
            PC_W        <= PC_M;
            is_sc_W     <= is_sc_M;
            logic1_M_W  <= logic1_M;
            wb_sel_csr_W<= wb_sel_csr_M;
            csr_rd_W    <= csr_rd_M;
            
//            count       <= 1'b0;
        end
//        else begin
//            count <= 1'b1;
//        end
    end

    // =========================================================================
    // =========================================================================
    // 5. WRITEBACK STAGE (WB)
    // =========================================================================
    // =========================================================================

    MUX_4x1 m4 (
        .a0  (ALUResult_W),
        .a1  (ReadData_W),
        .a2  (PCPlus4_W),
        .a3  (Load_Mux_W),
        .sel (ResultSrc_W),
        .y   (Result_W_mux)
    );
  
  // CSR overrides normal WB result
    assign Result_W = wb_sel_csr_W ? csr_rd_W : Result_W_mux;
    
    // =========================================================================
    // =========================================================================
    // HAZARD UNIT
    // =========================================================================
    // =========================================================================

    HAZARD_UNIT HU (
        .clk         (clk),
        .rst         (rst),
        .rs1_D       (Rs1_D),
        .rs2_D       (Rs2_D),
        .rs1_E       (Rs1_E),
        .rs2_E       (Rs2_E),
        .rd_E        (Rd_E),
        .ResultSrc_E (ResultSrc_E),
        .PCSrc_E     (PCSrc_corrected),
        .Mul_Done_E  (Mul_Done_E),
        .Div_Done_E  (Div_Done_E),
        .Start_Mul_E (start_mul_D),
        .Start_Div_E (start_div_D),
        .Mul_Busy_E  (Mul_Busy_E),
        .Div_Busy_E  (Div_Busy_E),
        .rd_M        (Rd_M),
        .RegWrite_M  (RegWrite_M),
        .rd_W        (Rd_W),
        .RegWrite_W  (RegWrite_W),
        .ForwardA_E  (ForwardA_E),
        .ForwardB_E  (ForwardB_E),
        .Stall_F     (Stall_F),
        .Stall_D     (Stall_D),
        .Stall_E     (Stall_E),
        .Stall_M     (Stall_M),
        .Flush_D     (Flush_D),
        .Flush_E     (Flush_E),
        .Flush_MEM   (Flush_MEM),
        .is_amo_M    (is_amo_M),
        .amo_stall_done (amo_stall_done_M),
        .mem_read    (mem_read_M),
        .csr_pc_en   (csr_pc_en),
        .is_mem_read_M  (is_mem_read_M)
    );

    // =========================================================================
    // ILA PROBE ASSIGNMENTS
    // Directly wire internal signals to probe wires - no padding, exact widths
    // =========================================================================

    // IF Stage
    assign PC_F_probe         = PC_F;           // [63:0]
    assign Instr_F_probe      = Instr_F;        // [31:0]

    // ID Stage
    assign PC_D_probe         = PC_D;           // [63:0]
    assign Instr_D_probe      = Instr_D;        // [31:0]
    assign RD1_D_probe        = RD1_D;          // [63:0]
    assign RD2_D_probe        = RD2_D;          // [63:0]

    // EX Stage
    assign PC_E_probe         = PC_E;           // [63:0]
    assign ALUResult_E_probe  = ALUResult_E;    // [63:0]
    assign SrcA_E_probe       = SrcA_E;         // [63:0]
    assign SrcB_E_probe       = SrcB_E;         // [63:0]
    assign ALUControl_E_probe = ALUControl_E;   // [3:0]
    assign ForwardA_E_probe   = ForwardA_E;     // [1:0]
    assign ForwardB_E_probe   = ForwardB_E;     // [1:0]

    // MEM Stage
    assign ALUResult_M_probe  = ALUResult_M;    // [63:0]
    assign WriteData_M_probe  = WriteData_DM;    // [63:0]
    assign MemWrite_M_probe   = MemWrite_M;     // [1]

    // WB Stage
    assign Result_W_probe     = Result_W;       // [63:0]
    assign RdW_probe          = Rd_W;           // [4:0]

    // Hazard & Control
    assign StallF_probe       = Stall_F;        // [1]
    assign StallD_probe       = Stall_D;        // [1]
    assign FlushE_probe       = Flush_E;        // [1]
    assign FlushD_probe       = Flush_D;        // [1]
    assign PCSrc_probe        = PCSrc_corrected;        // [1]
    
    // =========================================================================
    // ILA INSTANTIATION
    // 23 probes - widths match signal widths EXACTLY as set in ILA IP config
    // =========================================================================
//    ila_0 u_ila (
//        .clk     (clk),

//        // IF Stage
//        .probe0  (PC_F_probe),           // [63:0]
//        .probe1  (Instr_F_probe),        // [31:0]

//        // ID Stage
//       // .probe2  (PC_D_probe),           // [63:0]
//       // .probe3  (Instr_D_probe),        // [31:0]
//        //.probe4  (RD1_D_probe),          // [63:0]
//        //.probe5  (RD2_D_probe),          // [63:0]

//        // EX Stage
//        //.probe6  (PC_E_probe),           // [63:0]
//        .probe7  (Output_m9),    // [63:0]
//        //.probe8  (SrcA_E_probe),         // [63:0]
//        //.probe9  (SrcB_E_probe),         // [63:0]
////        .probe10 (ALUControl_E_probe),   // [3:0]
////        .probe11 (ForwardA_E_probe),     // [1:0]
////        .probe12 (ForwardB_E_probe),     // [1:0]

//        // MEM Stage
//        .probe13 (ALUResult_M_probe),    // [63:0]
//        .probe14 (WriteData_M_probe),    // [63:0]
//        .probe15 (MemWrite_M_probe),     // [1:0]  → set width=1 in ILA IP

//        // WB Stage
//        .probe16 (Result_W_probe),       // [63:0]
//        .probe17 (RdW_probe),            // [4:0]  → set width=5 in ILA IP

//        // Hazard & Control
//        .probe18 (StallF_probe),         // [1:0]  → set width=1 in ILA IP
//        .probe19 (StallD_probe),         // [1:0]  → set width=1 in ILA IP
//        .probe20 (FlushE_probe),         // [1:0]  → set width=1 in ILA IP
//        .probe21 (FlushD_probe),         // [1:0]  → set width=1 in ILA IP
//        .probe22 (PCSrc_probe)           // [1:0]  → set width=1 in ILA IP
//    );
ila_0 u_ila (
    .clk     (clk),

    // IF Stage
    .probe0  (PC_F_probe),           // [63:0]
    .probe1  (Instr_F_probe),        // [31:0]

    // EX Stage
    .probe2  (Output_m9),            // [63:0]

    // MEM Stage
    .probe3  (ALUResult_M_probe),    // [63:0]
    .probe4  (WriteData_M_probe),    // [63:0]
    .probe5  (MemWrite_M_probe),     // [1:0]  -> set width=1 in ILA IP

    // WB Stage
    .probe6  (Result_W_probe),       // [63:0]
    .probe7  (RdW_probe),            // [4:0]  -> set width=5 in ILA IP

    // Hazard & Control
    .probe8  (StallF_probe),         // [1:0]  -> set width=1 in ILA IP
    .probe9  (StallD_probe),         // [1:0]  -> set width=1 in ILA IP
    .probe10 (FlushE_probe),         // [1:0]  -> set width=1 in ILA IP
    .probe11 (FlushD_probe),         // [1:0]  -> set width=1 in ILA IP
    .probe12 (PCSrc_probe),           // [1:0]  -> set width=1 in ILA IP
    .probe13 (rst),
    .probe14 (ext_rst)
);

    // =========================================================================
    // LED STATUS INDICATORS
    // =========================================================================
//    assign led[0] = pll_locked;         // PLL stable - board is alive
//    assign led[1] = MemWrite_M;         // Lights on any memory write
//    assign led[2] = PCSrc_E;            // Lights on branch/jump taken
//    assign led[3] = |Result_W[3:0];     // Lights if writeback result nonzero


wire SC_Succ_M = is_sc_M && valid && (RD1_M == reservation_reg);

//    assign MemWrite_M_tb    = MemWrite_M;
//    assign ALUResult_M_tb   = ALUResult_M;
    assign PC_W_tb          = PC_W;
    assign RD_W_tb          = Rd_W;
    assign Result_W_tb      = Result_W;
    assign RegWrite_W_tb = RegWrite_W_gated;  // ← use gated version
//    assign WriteData_M_tb   = WriteData_M;
//    assign IsAMO_M_tb       = is_amo_M;
//    assign SC_Succ_M_tb     = SC_Succ_M;
    
//    ///////////////
//     assign OpcodeM_tb = op_M;
     
     //
     
   

endmodule
