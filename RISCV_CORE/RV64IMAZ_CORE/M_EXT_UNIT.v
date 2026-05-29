`timescale 1ns / 1ps

// ============================================================================
// Module      : RV64M_EXTENSION
// Description : Top-level wrapper for the RISC-V M-Extension (Integer 
//               Multiplication and Division). It instantiates and routes 
//               signals from the CPU's Execute stage to the dedicated 
//               Multiplier and Divider hardware units.
// ============================================================================
module RV64M_EXTENSION #(
    parameter WIDTH = 64                        // Width of the data buses
)(
    // ------------------------------------------------------------------------
    // System Signals
    // ------------------------------------------------------------------------
    input  wire             clk,
    input  wire             rst,
    
    // ------------------------------------------------------------------------
    // Control Signals (From CPU Pipeline - Execute Stage)
    // ------------------------------------------------------------------------
    input  wire             mul_valid,          // High to trigger a multiplication
    input  wire             div_valid,          // High to trigger a division
    input  wire [2:0]       op_sel,             // 3-bit operation selector (funct3 / mul_op_sel)
    input  wire             is_word,            // High for 32-bit operations (*W instructions)
    
    // ------------------------------------------------------------------------
    // Data Inputs (From Register File - Shared by both units)
    // ------------------------------------------------------------------------
    input  wire [WIDTH-1:0] rs1_data,           // Source 1: Multiplicand / Dividend
    input  wire [WIDTH-1:0] rs2_data,           // Source 2: Multiplier / Divisor

    // ------------------------------------------------------------------------
    // Outputs (Back to CPU Pipeline - Execute/Writeback Stage)
    // ------------------------------------------------------------------------
    // Multiplier Outputs
    output wire [WIDTH-1:0] mul_result,         // Final calculated product
    output wire             mul_ready,          // High when the multiplication is complete
    output wire             mul_busy,           // High when multiplier is actively computing
    
    // Divider Outputs
    output wire [WIDTH-1:0] div_result,         // Final calculated quotient/remainder
    output wire             div_ready,          // High when the division is complete
    output wire             div_busy            // High when divider is actively computing
);

    // =========================================================================
    // MULTIPLIER UNIT INSTANTIATION
    // =========================================================================
    // Handles all MUL, MULH, MULHSU, MULHU, and MULW instructions using 
    // a multi-cycle Radix-2 Booth's algorithm.
    MULTIPLIER_UNIT #(
        .WIDTH(WIDTH)            
    ) u_booth_multiplier (
        .clk      (clk),         
        .rst      (rst),         
        .start    (mul_valid),   
        .op_sel   (op_sel),      // Uses the op_sel (with MULW override) from Decoder
        .rs1_data (rs1_data),    
        .rs2_data (rs2_data),    
        
        .result   (mul_result),  
        .done     (mul_ready),
        .busy     (mul_busy)     
    );  

    // =========================================================================
    // DIVIDER UNIT INSTANTIATION
    // =========================================================================
    // Handles all DIV, DIVU, REM, REMU, DIVW, DIVUW, REMW, and REMUW 
    // instructions using a sequential shift-and-subtract algorithm.
    DIVIDER_UNIT #(
        .WIDTH(WIDTH)
    ) u_divider (
        .clk      (clk),
        .rst      (rst),
        .start    (div_valid),   // Wakes up the Divider FSM
        .is_word  (is_word),     // Flags a 32-bit operation
        .op_sel   (op_sel),      // Tells the Divider to do DIV, DIVU, REM, or REMU
        .rs1_data (rs1_data),    // Dividend
        .rs2_data (rs2_data),    // Divisor
        
        .result   (div_result),  // Routes to Execution 3-to-1 MUX
        .done     (div_ready),   // Routes to Hazard Unit
        .busy     (div_busy)
    );

endmodule


/* ==============================================================================
                            OLD/COMMENTED CODE
==============================================================================
//`timescale 1ns / 1ps

//module RV64M_EXTENSION #(
//    parameter WIDTH = 64
//)(
//    input  wire             clk,
//    input  wire             rst,
    
//    // Control signals from the CPU pipeline (Decode/Execute stage)
//    input  wire             mul_valid,  // High when a multiply instruction is detected
//    input  wire [2:0]       funct3,     // 3-bit operation selector from the instruction
    
//    // Data from the register file
//    input  wire [WIDTH-1:0] rs1_data,   // Source register 1 (Multiplicand)
//    input  wire [WIDTH-1:0] rs2_data,   // Source register 2 (Multiplier)

//    // Outputs back to the CPU pipeline (Writeback stage)
//    output wire [WIDTH-1:0] mul_result, // Final calculated result
//    output wire             mul_ready   // High when the math is done (tells CPU to un-stall)
//);

//    // =========================================================================
//    // MULTIPLIER UNIT INSTANTIATION
//    // =========================================================================
    
//    MULTIPLIER_UNIT #(
//        .WIDTH(WIDTH)            // Pass the parameter down to your unit
//    ) u_booth_multiplier (
//        .clk      (clk),         // System clock
//        .rst      (rst),         // Active-low reset
//        .start    (mul_valid),   // CPU tells the multiplier to start
//        .op_sel   (funct3),      // CPU tells the multiplier which op to run
//        .rs1_data (rs1_data),    // Feed in operand A
//        .rs2_data (rs2_data),    // Feed in operand B
        
//        .result   (mul_result),  // Catch the output into our module's port
//        .done     (mul_ready)    // Catch the done flag into our module's port
//    );  
//endmodule
*/
//`timescale 1ns / 1ps

//module RV64M_EXTENSION #(
//    parameter WIDTH = 64
//)(
//    input  wire             clk,
//    input  wire             rst,
    
//    // Control signals from the CPU pipeline (Execute stage)
//    input  wire             mul_valid,  // High when a multiply instruction is detected (start_mul)
//    input  wire             div_valid,  // High when a divide instruction is detected (start_div)
//    input  wire [2:0]       op_sel,     // 3-bit operation selector (funct3 / mul_op_sel)
//    input  wire             is_word,    // High for 32-bit operations (*W instructions)
//    // Data from the register file (Shared by both units!)
//    input  wire [WIDTH-1:0] rs1_data,   // Source register 1 (Multiplicand / Dividend)
//    input  wire [WIDTH-1:0] rs2_data,   // Source register 2 (Multiplier / Divisor)

//    // Outputs back to the CPU pipeline (Execute/Writeback stage)
//    output wire [WIDTH-1:0] mul_result, // Final calculated product
//    output wire             mul_ready,  // High when the multiplication is done
//    output wire             mul_busy,
//    output wire             div_busy,
    
//    output wire [WIDTH-1:0] div_result, // Final calculated quotient/remainder
//    output wire             div_ready   // High when the division is done
//);

//    // =========================================================================
//    // MULTIPLIER UNIT INSTANTIATION
//    // =========================================================================
//    MULTIPLIER_UNIT #(
//        .WIDTH(WIDTH)            
//    ) u_booth_multiplier (
//        .clk      (clk),         
//        .rst      (rst),         
//        .start    (mul_valid),   
//        .op_sel   (op_sel),      // Uses the op_sel (with MULW override) from your Decoder
//        .rs1_data (rs1_data),    
//        .rs2_data (rs2_data),    
        
//        .result   (mul_result),  
//        .done     (mul_ready),
//        .busy     (mul_busy)    
//    );  

////     =========================================================================
////     DIVIDER UNIT INSTANTIATION
////     =========================================================================
//    DIVIDER_UNIT #(
//        .WIDTH(WIDTH)
//    ) u_divider (
//        .clk      (clk),
//        .rst      (rst),
//        .start    (div_valid),   // Wakes up the Divider FSM
//        .is_word  (is_word),
//        .op_sel   (op_sel),      // Tells the Divider to do DIV, DIVU, REM, or REMU
//        .rs1_data (rs1_data),    // Dividend
//        .rs2_data (rs2_data),    // Divisor
        
//        .result   (div_result),  // Routes to your Execution 3-to-1 MUX
//        .done     (div_ready),    // Routes to your Hazard Unit
//        .busy     (div_busy)
//  );

//endmodule

////`timescale 1ns / 1ps

////module RV64M_EXTENSION #(
////    parameter WIDTH = 64
////)(
////    input  wire             clk,
////    input  wire             rst,
    
////    // Control signals from the CPU pipeline (Decode/Execute stage)
////    input  wire             mul_valid,  // High when a multiply instruction is detected
////    input  wire [2:0]       funct3,     // 3-bit operation selector from the instruction
    
////    // Data from the register file
////    input  wire [WIDTH-1:0] rs1_data,   // Source register 1 (Multiplicand)
////    input  wire [WIDTH-1:0] rs2_data,   // Source register 2 (Multiplier)

////    // Outputs back to the CPU pipeline (Writeback stage)
////    output wire [WIDTH-1:0] mul_result, // Final calculated result
////    output wire             mul_ready   // High when the math is done (tells CPU to un-stall)
////);

////    // =========================================================================
////    // MULTIPLIER UNIT INSTANTIATION
////    // =========================================================================
    
////    MULTIPLIER_UNIT #(
////        .WIDTH(WIDTH)            // Pass the parameter down to your unit
////    ) u_booth_multiplier (
////        .clk      (clk),         // System clock
////        .rst      (rst),         // Active-low reset
////        .start    (mul_valid),   // CPU tells the multiplier to start
////        .op_sel   (funct3),      // CPU tells the multiplier which op to run
////        .rs1_data (rs1_data),    // Feed in operand A
////        .rs2_data (rs2_data),    // Feed in operand B
        
////        .result   (mul_result),  // Catch the output into our module's port
////        .done     (mul_ready)    // Catch the done flag into our module's port
////    );  
////endmodule
