//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 03.02.2026 19:55:49
//// Design Name: 
//// Module Name: ALU_DECODER
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

////ADD,0000
////SUB,0001
////AND,0010
////OR,0011
////SLT (Set Less Than),0100
////SLL (Shift Left),0101
////SRL (Shift Right Log),0110
////SRA (Shift Right Arith),0111
////XOR 1000
////set less than signed

//module ALU_DECODER #(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
//        input op5,
//        input [2:0]funct3,
//        input funct7,
//        input [1:0]ALUOp,
//        output reg [3:0]ALUControl
//    );
//    always@(*)
//        begin      
//        if(ALUOp==2'b00)            // Generate add signals
//            ALUControl = 4'b0000;    
//        else if (ALUOp==2'b01)      // Generate sub signals
//            ALUControl = 4'b0001;
//        else if (ALUOp == 2'b11)
//        begin    
//            case(funct3)
//            3'b000:ALUControl = op5?(funct7?4'b1011:4'b1010):4'b1010;  //ADDW SUBW
//            3'b001:ALUControl = 4'b1100;                   //SLLW
//            3'b101:ALUControl = funct7?4'b1110:4'b1101;      //SRLW and //SRAW
//            default:ALUControl = 4'b0000;
//        endcase
//        end
        
//        else                       // Check for the other signals
//            begin
//                case(funct3)
//                    3'b000:ALUControl = op5?(funct7?4'b0001:4'b0000):4'b0000; // add for I type and add or sub for R type 
//                    3'b001:ALUControl = 4'b0101; // left shift
//                    3'b010:ALUControl = 4'b0100; // set less than signed
//                    3'b011:ALUControl = 4'b1001; // set less than unsigned
//                    3'b100:ALUControl = 4'b1000; // xor
//                    3'b101:ALUControl = funct7?4'b0111:4'b0110; //shift logical or shift right arithematic
//                    3'b110:ALUControl = 4'b0011; //or
//                    3'b111:ALUControl = 4'b0010; //and
//                  endcase 
//            end
//        end  
//endmodule


`timescale 1ns / 1ps

module ALU_DECODER (
    input  wire       op5,         // Instruction bit 5 (helps distinguish R-type from I-type)
    input  wire [2:0] funct3,      // Instruction bits [14:12]
    input  wire       funct7,      // Instruction bit 30 (often used for ADD vs SUB / SRA vs SRL)
    input  wire [4:0] funct5,      // Used for the AMO 
    input  wire [2:0] ALUOp,       // Control signal from Main Decoder
    output reg  [3:0] ALUControl,  // 4-bit output to the ALU
    output reg  [4:0] amo_alu_op   // 5-bit output to the AMO ALU
);
    
    //=========================================================================
    // ALU Control Codes (Local Parameters for Readability)
    // Matches the exact encoding you specified in your comments/code.
    //=========================================================================
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_SLT  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_XOR  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    
    // RV64 Word Operations
    localparam ALU_ADDW = 4'b1010;
    localparam ALU_SUBW = 4'b1011;
    localparam ALU_SLLW = 4'b1100;
    localparam ALU_SRLW = 4'b1101;
    localparam ALU_SRAW = 4'b1110;
    
    //AMO OPERATIONS
    // ──────────────────────────────────────────────────────
    // SEPARATE AMO ALU CONTROL SIGNALS — 5 bit
    // Used ONLY at the Data Memory / MEM stage
    // ──────────────────────────────────────────────────────
    
    // AMO WORD (W) — 32 bit operations (funct3 = 010)
    localparam AMO_SWAP_W  = 5'b00000;  //  0
    localparam AMO_ADD_W   = 5'b00001;  //  1
    localparam AMO_AND_W   = 5'b00010;  //  2
    localparam AMO_OR_W    = 5'b00011;  //  3
    localparam AMO_XOR_W   = 5'b00100;  //  4
    localparam AMO_MIN_W   = 5'b00101;  //  5 — signed
    localparam AMO_MAX_W   = 5'b00110;  //  6 — signed
    localparam AMO_MINU_W  = 5'b00111;  //  7 — unsigned
    localparam AMO_MAXU_W  = 5'b01000;  //  8 — unsigned
    
    // AMO DOUBLEWORD (D) — 64 bit operations (funct3 = 011)
    localparam AMO_SWAP_D  = 5'b01001;  //  9
    localparam AMO_ADD_D   = 5'b01010;  // 10
    localparam AMO_AND_D   = 5'b01011;  // 11
    localparam AMO_OR_D    = 5'b01100;  // 12
    localparam AMO_XOR_D   = 5'b01101;  // 13
    localparam AMO_MIN_D   = 5'b01110;  // 14 — signed
    localparam AMO_MAX_D   = 5'b01111;  // 15 — signed
    localparam AMO_MINU_D  = 5'b10000;  // 16 — unsigned
    localparam AMO_MAXU_D  = 5'b10001;  // 17 — unsigned
    
    //=========================================================================
    // ALU Decoder Logic
    //=========================================================================
    always @(*) begin
        ALUControl  = ALU_ADD;   // safe default
        amo_alu_op  = 5'b00000;  // safe default
        case (ALUOp)
            //-----------------------------------------------------------------
            // ALUOp = 00: Memory Access (Load/Store) -> Force Addition
            //-----------------------------------------------------------------
            3'b000: ALUControl = ALU_ADD;

            //-----------------------------------------------------------------
            // ALUOp = 01: Branch -> Force Subtraction
            //-----------------------------------------------------------------
            3'b001: ALUControl = ALU_SUB;

            //-----------------------------------------------------------------
            // ALUOp = 10: Standard R-Type or I-Type ALU Operations
            //-----------------------------------------------------------------
            3'b010: begin
                case (funct3)
                    // ADD or SUB (Subtract only if it's an R-type AND funct7 bit 30 is 1)
                    3'b000: ALUControl = (op5 & funct7) ? ALU_SUB : ALU_ADD;
                    3'b001: ALUControl = ALU_SLL;
                    3'b010: ALUControl = ALU_SLT;
                    3'b011: ALUControl = ALU_SLTU;
                    3'b100: ALUControl = ALU_XOR;
                    // SRL or SRA (Arithmetic shift if funct7 bit 30 is 1)
                    3'b101: ALUControl = funct7 ? ALU_SRA : ALU_SRL;
                    3'b110: ALUControl = ALU_OR;
                    3'b111: ALUControl = ALU_AND;
                    default: ALUControl = ALU_ADD; // Safe default
                endcase
            end

            //-----------------------------------------------------------------
            // ALUOp = 11: RV64 32-bit Word ALU Operations (ADDW, SUBW, etc.)
            //-----------------------------------------------------------------
            3'b011: begin
                case (funct3)
                    // ADDW or SUBW
                    3'b000: ALUControl = (op5 & funct7) ? ALU_SUBW : ALU_ADDW;
                    3'b001: ALUControl = ALU_SLLW;
                    // SRLW or SRAW
                    3'b101: ALUControl = funct7 ? ALU_SRAW : ALU_SRLW;
                    default: ALUControl = ALU_ADD; // Safe default
                endcase
            end
             3'b100: begin
                case ({funct5, funct3})
                // WORD
                {5'b00001, 3'b010}: amo_alu_op = AMO_SWAP_W;
                {5'b00000, 3'b010}: amo_alu_op = AMO_ADD_W;
                {5'b01100, 3'b010}: amo_alu_op = AMO_AND_W;
                {5'b01000, 3'b010}: amo_alu_op = AMO_OR_W;
                {5'b00100, 3'b010}: amo_alu_op = AMO_XOR_W;
                {5'b10000, 3'b010}: amo_alu_op = AMO_MIN_W;
                {5'b10100, 3'b010}: amo_alu_op = AMO_MAX_W;
                {5'b11000, 3'b010}: amo_alu_op = AMO_MINU_W;
                {5'b11100, 3'b010}: amo_alu_op = AMO_MAXU_W;
                // DOUBLEWORD
                {5'b00001, 3'b011}: amo_alu_op = AMO_SWAP_D;
                {5'b00000, 3'b011}: amo_alu_op = AMO_ADD_D;
                {5'b01100, 3'b011}: amo_alu_op = AMO_AND_D;
                {5'b01000, 3'b011}: amo_alu_op = AMO_OR_D;
                {5'b00100, 3'b011}: amo_alu_op = AMO_XOR_D;
                {5'b10000, 3'b011}: amo_alu_op = AMO_MIN_D;
                {5'b10100, 3'b011}: amo_alu_op = AMO_MAX_D;
                {5'b11000, 3'b011}: amo_alu_op = AMO_MINU_D;
                {5'b11100, 3'b011}: amo_alu_op = AMO_MAXU_D;
                
                default: amo_alu_op = 5'b0;
            endcase
            end
            //-----------------------------------------------------------------
            // Safe Default (Prevents inferred latches)
            //-----------------------------------------------------------------
            default: ALUControl = ALU_ADD; 
        endcase
    end
endmodule

