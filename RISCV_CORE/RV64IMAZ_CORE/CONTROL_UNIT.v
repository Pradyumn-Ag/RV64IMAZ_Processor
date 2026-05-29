//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 03.02.2026 19:44:14
//// Design Name: 
//// Module Name: CONTROL_UNIT
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


//module CONTROL_UNIT #(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
//        input [WIDTH-1:0]Instr,
////        input zero,
//        output PCSrc,
//        output [1:0]ResultSrc,
//        output MemWrite,
//        output [3:0]ALUControl,
//        output ALUSrc,
//        output [2:0]ImmSrc,
//        output RegWrite,
//        output wire Branch,
//        output wire Jump
//    );
//    wire [1:0]ALUOp;
    
//    assign Jump = Instr[2]&&Instr[6];
////    assign PCSrc = zero&&Branch || Jump;
    
    
//    MAIN_DECODER MD(Instr[6:0],Branch,Jump,ResultSrc,MemWrite,ALUSrc,ImmSrc,RegWrite,ALUOp);
//    ALU_DECODER AD(Instr[5],Instr[14:12],Instr[30],ALUOp,ALUControl);
    
//endmodule


`timescale 1ns / 1ps

module CONTROL_UNIT #(
    // RISC-V instructions are rigidly 32 bits, even in RV64 architectures.
    parameter INSTR_WIDTH = 32 
)(
    input  wire [INSTR_WIDTH-1:0] Instr,
    output wire [1:0]             ResultSrc,
    output wire                   MemWrite,
    output wire [3:0]             ALUControl,
    output wire                   ALUSrc,
    output wire [2:0]             ImmSrc,
    output wire                   RegWrite,
    output wire                   Branch,
    output wire                   Jump,
    
    //M-Extension Ports
    output wire                   start_mul,  
    output wire                   start_div,  
    output wire [1:0]             Exec_Sel, 
    output wire [2:0]             mul_op_sel,
    output wire [4:0]             amo_alu_op,
    output wire                   is_lr,     
    output wire                   is_sc, 
    output wire                   is_amo,
    output wire                   is_mem_read,
    
     // ── NEW CSR PORTS ──────────────────────────────────────
    output wire                   csr_en,       // to pipeline reg → CSR module
    output wire [1:0]             funct3b21,    // to pipeline reg → CSR module
    output wire                   wb_sel_csr    // to pipeline reg → WB mux
    // ───────────────────────────────────────────────────────
);

    //=========================================================================
    // Internal Wires
    //=========================================================================
    wire [2:0] ALUOp;
    
    //=========================================================================
    // Program Counter Source Logic
    //=========================================================================
    // Standard RISC-V logic for PCSrc requires the 'Zero' flag from the ALU.
    // I left this commented out as a placeholder. Once you route the Zero flag 
    // from your ALU into this module, uncomment the actual logic below.
    
     //assign PCSrc = (Zero & Branch) | Jump;
     assign PCSrc = 1'b0; // Temporary placeholder to prevent floating output warnings
    
    //=========================================================================
    // Main Decoder Instantiation
    // Using explicit named mapping to prevent misaligned connections!
    //=========================================================================
    
    MAIN_DECODER MD (
        .op         (Instr[6:0]),
        .funct7     (Instr[31:25]),
        .funct3     (Instr[14:12]),
        .Branch     (Branch),
        .Jump       (Jump),
        .ResultSrc  (ResultSrc),
        .MemWrite   (MemWrite),
        .ALUSrc     (ALUSrc),
        .ImmSrc     (ImmSrc),
        .RegWrite   (RegWrite),
        .ALUOp      (ALUOp),
        .start_mul  (start_mul),
        .start_div  (start_div),
        .Exec_Sel   (Exec_Sel),
        .mul_op_sel (mul_op_sel),
        .is_lr      (is_lr),
        .is_sc      (is_sc),
        .is_amo     (is_amo),
        .is_mem_read(is_mem_read),
        .csr_en      (csr_en),
        .funct3b21   (funct3b21),
        .wb_sel_csr  (wb_sel_csr)
    );

    //=========================================================================
    // ALU Decoder Instantiation
    // Extracts specific opcode, funct3, and funct7 bits to determine ALU action
    //=========================================================================
    
    ALU_DECODER AD (
        .op5        (Instr[5]),
        .funct3     (Instr[14:12]),
        .funct7     (Instr[30]),
        .funct5     (Instr[31:27]),
        .ALUOp      (ALUOp),
        .ALUControl (ALUControl),
        .amo_alu_op (amo_alu_op)
    );
    
endmodule