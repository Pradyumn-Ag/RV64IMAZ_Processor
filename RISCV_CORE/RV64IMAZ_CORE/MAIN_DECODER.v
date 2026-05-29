//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 03.02.2026 19:55:11
//// Design Name: 
//// Module Name: MAIN_DECODER
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////


//module MAIN_DECODER #(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
//        input [6:0]op,
//        output  Branch,
//        output  Jump,
//        output  [1:0]ResultSrc,
//        output  MemWrite,
//        output  ALUSrc,
//        output  [2:0]ImmSrc,
//        output  RegWrite,
//        output  [1:0]ALUOp
//    );
//    reg [11:0]controls;
    
//    assign {RegWrite,ImmSrc,ALUSrc,MemWrite,ResultSrc,Branch,ALUOp,Jump}=controls;
   
//   always@(*)
//   begin
//    case (op)
////RegWrite(1),ImmSrc(3),ALUSrc(1),MemWrite(1),ResultSrc(2),Branch,ALUOp(2),Jump
//        7'd3: controls = 12'b1_000_1_0_11_0_00_0;  //I type (3)
//        7'd19:controls = 12'b1_000_1_0_00_0_10_0;  //I type (19)
//        7'd27:controls = 12'b1_101_1_0_00_0_11_0;  //(27)
//        7'd51:controls = 12'b1_xxx_0_0_00_0_10_0;  // R type 
//        7'd59:controls = 12'b1_xxx_0_0_00_0_11_0;  //ADDW , SUBW
//        7'd35:controls = 12'b0_001_1_1_00_0_00_0;  //S type
//        7'd99:controls = 12'b0_010_0_0_xx_1_01_0;  //B type ALUOp is fixed to subtraction 
//        7'd103:controls = 12'b1_000_1_0_10_0_00_1; //Jalr 
//        7'd111:controls = 12'b1_100_x_0_10_0_xx_1; //Jal J type
//        7'd23:controls = 12'b1_011_1_0_00_0_00_0;  //Utype (lui)
//        7'd55:controls = 12'b1_011_1_0_00_0_00_0;  //Utype (auipc)  
//    endcase
//    end
    
//endmodule


`timescale 1ns / 1ps

    module MAIN_DECODER (
    input  wire [6:0] op,         // 7-bit RISC-V Opcode
    input  wire [6:0] funct7,
    input  wire [2:0] funct3,
    output wire       Branch,
    output wire       Jump,
    output wire [1:0] ResultSrc,
    output wire       MemWrite,
    output wire       ALUSrc,
    output wire [2:0] ImmSrc,
    output wire       RegWrite,
    output wire [2:0] ALUOp,
    
    output wire       start_mul,  // Goes to Hazard Unit and Execute Stage
    output wire       start_div,  // Goes to Hazard Unit and Execute Stage
    output wire [1:0] Exec_Sel,   // Goes to Execute Stage (Controls the 3x1 Mux)
    output wire [2:0] mul_op_sel,  // Goes to the Multiplier Unit (Overrides funct3 for MULW)

    output wire is_lr,             //For LR instruction
    output wire is_sc,              //For SC instruction
    output wire is_amo,
    output wire is_mem_read,
    
    // ── NEW CSR PORTS ──────────────────────────────────────
    output wire       csr_en,       // CSR instruction active
    output wire [1:0] funct3b21,    // funct3[2:1] → encodes CSRRW/RS/RC vs priv
    output wire       wb_sel_csr    // writeback from CSR RD, not ALU
    
);
    wire is_rtype   = (op == 7'b0110011); // Opcode 51
    wire is_rtype_w = (op == 7'b0111011); // Opcode 59
    
    wire is_m_ext   = (is_rtype | is_rtype_w) & (funct7 == 7'b0000001);
    
    wire is_mul     = is_m_ext & (~funct3[2]);
    wire is_div     = is_m_ext & (funct3[2]);
    

    // ---------------------------------------------------------
    // DRIVING THE OUTPUT PORTS
    // ---------------------------------------------------------
    assign start_mul  = is_mul;
    
    assign start_div  = is_div;
    
    assign Exec_Sel   = (is_div) ? 2'b10 : 
                        (is_mul) ? 2'b01 : 
                                   2'b00 ; 
                                   
    assign mul_op_sel = (is_rtype_w & is_mul) ? 3'b100 : funct3;

    assign is_lr = (op == 7'd47)?((funct7[6:2]==5'b00010)?1'b1:1'b0):1'b0;
    
    assign is_sc = (op == 7'd47)?((funct7[6:2]==5'b00011)?1'b1:1'b0):1'b0;
    
    assign is_amo= (op == 7'd47)?((funct7[3]==1'b0)?1'b1:1'b0):1'b0;
    
    assign is_mem_read = ( ResultSrc == 2'b11 | is_lr | is_amo ) ;
    

    //=========================================================================
    // RISC-V Opcodes (Local Parameters for Readability)
    // Makes the case statement self-documenting instead of using raw decimals
    //=========================================================================
    localparam OPCODE_LOAD     = 7'd3;   // 7'b0000011 (I-Type Load)
    localparam OPCODE_I_ALU    = 7'd19;  // 7'b0010011 (I-Type ALU)
    localparam OPCODE_I_ALUW   = 7'd27;  // 7'b0011011 (I-Type ALU RV64)
    localparam OPCODE_R_ALU    = 7'd51;  // 7'b0110011 (R-Type)
    localparam OPCODE_R_ALUW   = 7'd59;  // 7'b0111011 (R-Type RV64)
    localparam OPCODE_R_ATOMIC = 7'd47;// 7'b0101111 (Atomic Extension)
    localparam OPCODE_STORE    = 7'd35;  // 7'b0100011 (S-Type)
    localparam OPCODE_BRANCH   = 7'd99;  // 7'b1100011 (B-Type)
    localparam OPCODE_JALR     = 7'd103; // 7'b1100111 (J-Type JALR)
    localparam OPCODE_JAL      = 7'd111; // 7'b1101111 (J-Type JAL)
    localparam OPCODE_AUIPC    = 7'd23;  // 7'b0010111 (U-Type AUIPC)
    localparam OPCODE_LUI      = 7'd55;  // 7'b0110111 (U-Type LUI)
    localparam OPCODE_SYSTEM   = 7'd115; // 7'b1110011 (CSR opcode)
    
    
    // CSR Assignment //
    
    wire is_system = (op == OPCODE_SYSTEM);
    wire is_csr    = is_system && (funct3 != 3'b000); // CSRRW/RS/RC/I variants
    wire is_priv   = is_system && (funct3 == 3'b000); // ecall/ebreak/mret

    assign csr_en    = is_csr | is_priv;
    assign funct3b21 = funct3[1:0];   // [1]=imm variant flag, [0]=set/clear
    assign wb_sel_csr = is_csr;       // only CSR R/W instructions write RD
    
    
    reg [12:0] controls;

    //=========================================================================
    // Output Mapping
    // Mapped directly to match the user's defined order:
    // {RegWrite(1), ImmSrc(3), ALUSrc(1), MemWrite(1), ResultSrc(2), Branch(1), ALUOp(2), Jump(1)}
    //=========================================================================
    assign {RegWrite, ImmSrc, ALUSrc, MemWrite, ResultSrc, Branch, ALUOp, Jump} = controls;

    //=========================================================================
    // Main Control Logic
    //=========================================================================
    always @(*) begin
        case (op)
            OPCODE_LOAD:   controls = 13'b1_000_1_0_11_0_000_0; 
            OPCODE_I_ALU:  controls = 13'b1_000_1_0_00_0_010_0; 
            OPCODE_I_ALUW: controls = 13'b1_101_1_0_00_0_011_0; 
            OPCODE_R_ALU:  controls = (funct7==7'b0000001) ? 13'b1_000_0_0_00_0_000_0 : 13'b1_000_0_0_00_0_010_0; 
            OPCODE_R_ALUW: controls = (funct7==7'b0000001) ? 13'b1_000_0_0_00_0_000_0 : 13'b1_000_0_0_00_0_011_0; 
            OPCODE_R_ATOMIC:   begin
                               case(funct7[6:2])
                               5'b00010: controls = 13'b1_xxx_0_0_11_0_xxx_0;  // LR
                               5'b00011: controls = 13'b1_xxx_0_1_01_0_xxx_0;  // SC
                               default : controls = 13'b1_xxx_0_1_11_0_100_0;  // AMO
                               endcase
                               end
            OPCODE_STORE:  controls = 13'b0_001_1_1_00_0_000_0; 
            OPCODE_BRANCH: controls = 13'b0_010_0_0_00_1_001_0;  // Result Src changed to 00
            OPCODE_JALR:   controls = 13'b1_000_1_0_10_0_000_1; 
            OPCODE_JAL:    controls = 13'b1_100_x_0_10_0_xxx_1; 
            OPCODE_AUIPC:  controls = 13'b1_011_1_0_00_0_000_0; 
            OPCODE_LUI:    controls = 13'b1_011_1_0_00_0_000_0; 
            
             // ── NEW ──────────────────────────────────────────
            // CSR: RegWrite=1 if is_csr, ResultSrc=2'b00 (overridden
            // by wb_sel_csr in WB mux), ALUSrc=0, MemWrite=0
            // ImmSrc doesn't matter for CSR (addr from inst[31:20])
            // We just need RegWrite=1 for CSRRW/RS/RC
            // For ecall/ebreak/mret (is_priv): RegWrite=0
            OPCODE_SYSTEM:   controls = is_csr ?
                                        13'b1_000_0_0_00_0_000_0 :  // CSR read/write
                                        13'b0_000_0_0_00_0_000_0;   // priv (ecall etc)
            // ─────────────────────────────────────────────────
            
            // CRITICAL: Default case prevents inferred latches during synthesis!
            // If an unsupported instruction hits the decoder, everything shuts down safely.
            default:       controls = 13'b0_000_0_0_00_0_000_0; 
        endcase
    end
    
endmodule