//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 21.03.2026 16:29:05
//// Design Name: 
//// Module Name: HAZARD_UNIT
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


//module HAZARD_UNIT #(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
//        // Inputs from Decode Stage
//        input [4:0] rs1_D,
//        input [4:0] rs2_D,
        
//        // Inputs from Execute Stage
//        input [4:0] rs1_E,
//        input [4:0] rs2_E,
//        input [4:0] rd_E,
//        input [1:0] ResultSrc_E, // Assuming 2'b01 means Load Memory
//        input       PCSrc_E,     // 1 if a branch or jump is TAKEN in EX stage
        
//        // Inputs from Memory Stage
//        input [4:0] rd_M,
//        input       RegWrite_M,
        
//        // Inputs from Writeback Stage
//        input [4:0] rd_W,
//        input       RegWrite_W,
        
//        // Outputs to MUXes and Pipeline Registers
//        output reg [1:0] ForwardA_E,
//        output reg [1:0] ForwardB_E,
//        output reg       Stall_F,
//        output reg       Stall_D,
//        output reg       Flush_D,
//        output reg       Flush_E
//    );
//    // Internal signal for Load-Use Stall detection
//    reg lwStall;

//    always @(*) begin
//        // ==========================================
//        // 1. DATA HAZARDS: Forwarding Logic (EX Stage)
//        // ==========================================
        
//        // Forwarding for ALU Input A (rs1)
//        if (((rs1_E == rd_M) && RegWrite_M) && (rd_M != 5'b0)) 
//        /* If the register that is to be used in the execute stage is being 
//         updated in the data memory then the data is transfered from the data
//         memory to the execute stage.
         
//         The ALUResult_M is moved into the input of the ALU for execute
        
//         Also we are checking that the address must not be of x0 
//         */
         
//            ForwardA_E = 2'b10; // Forward from Memory stage
  
//        else if (((rs1_E == rd_W) && RegWrite_W) && (rd_W != 5'b0)) 
//        /* Similarly to the previous case if the next to next instruction 
//           has the updated value of the register that is going to be used 
//           in the execute stage we take that value as the input*/
        
//            ForwardA_E = 2'b01; // Forward from Writeback stage
//        else 
//            ForwardA_E = 2'b00; // No hazard, use normal register value
            
//        // Forwarding for ALU Input B (rs2)
//        if (((rs2_E == rd_M) && RegWrite_M) && (rd_M != 5'b0)) 
//            ForwardB_E = 2'b10; // Forward from Memory stage
//        else if (((rs2_E == rd_W) && RegWrite_W) && (rd_W != 5'b0)) 
//            ForwardB_E = 2'b01; // Forward from Writeback stage
//        else 
//            ForwardB_E = 2'b00; // No hazard, use normal register value

//        // ==========================================
//        // 2. LOAD-USE HAZARDS: Stall Logic
//        // ==========================================
        
//        // Detect if the instruction in EX is a Load (ResultSrc_E == 01) 
//        // AND its destination matches a source register in Decode
//        if ((ResultSrc_E == 2'b11) && ((rs1_D == rd_E) || (rs2_D == rd_E))) 
//            lwStall = 1'b1;
//        else 
//            lwStall = 1'b0;

//        // ==========================================
//        // 3. CONTROL HAZARDS: Flush & Stall Assignments
//        // ==========================================
        
//        // Freeze PC and Decode stage if there is a Load-Use hazard
//        Stall_F = lwStall;
//        Stall_D = lwStall;
        
//        // Flush Decode stage if a branch/jump is taken
//        Flush_D = PCSrc_E;
        
//        // Flush Execute stage if a branch/jump is taken OR if there is a Load-Use stall
//        // (If we stall D, we must flush E to insert a bubble/NOP)
//        Flush_E = lwStall | PCSrc_E;
        
//    end
//endmodule

`timescale 1ns / 1ps

module HAZARD_UNIT (
    input wire        clk,
    input wire        rst,
    
    // Inputs from Decode Stage
    input  wire [4:0] rs1_D,
    input  wire [4:0] rs2_D,
    
    // Inputs from Execute Stage
    input  wire [4:0] rs1_E,
    input  wire [4:0] rs2_E,
    input  wire [4:0] rd_E,
    input  wire [1:0] ResultSrc_E, // 2'b01 = Load Memory (Double check your Control Unit!)
    input  wire       PCSrc_E,     // 1 if a branch/jump is TAKEN in EX stage
    //M-Extension Inputs
    input wire        Mul_Done_E,
    input wire        Div_Done_E,
    input wire        Start_Mul_E,
    input wire        Start_Div_E,
    input wire        Mul_Busy_E,
    input wire        Div_Busy_E,
    
    // Inputs from Memory Stage
    input  wire [4:0] rd_M,
    input  wire       RegWrite_M,
    
    // Inputs from Writeback Stage
    input  wire [4:0] rd_W,
    input  wire       RegWrite_W,
    
    // Forwarding Outputs to MUXes
    output reg  [1:0] ForwardA_E,
    output reg  [1:0] ForwardB_E,
    
    // Stall and Flush Control Signals
    output wire       Stall_F,
    output wire       Stall_D,
    output wire       Stall_E,
    output wire       Stall_M,
    output wire       Flush_D,
    output wire       Flush_E,
    output wire       Flush_MEM,
    
    //Stall logic for AMO Instructions
    input wire        is_amo_M,
    output reg        amo_stall_done,
    
    // Mem_read input
    input wire        mem_read,
    input wire        is_mem_read_M,
    
    // FROM CSR module: trap/mret redirect
    input wire        csr_pc_en    
);

   reg count;
   reg count1;
    
 // assign count = mem_read ? 1'b1 : 1'b0;
    
    always @(posedge clk)begin
        if(~rst) begin
            count <= 1'b0;
        end
        else if (count == 1'b1) begin
            count <= 1'b0;
        end
        else if (mem_read) begin 
            count <= 1'b1;
        end
    end
    
    always @(posedge clk)begin
        if(~rst) begin
            count1 <= 1'b0;
        end
        else if (count1 == 1'b1) begin
            count1 <= 1'b0;
        end
        else if (is_mem_read_M) begin 
            count1 <= 1'b1;
        end
    end
    
    // logic for identification of the Math instruction multiplication or divison
//    wire Math_Stall = Start_Mul_E | Start_Div_E | 
//                  (Start_Mul_E & ~Mul_Done_E) | 
//                  (Start_Div_E & ~Div_Done_E);

//    wire mul_busy = 1'b0;
//    wire div_busy = 1'b0;
    
//    assign mul_busy = (Start_Mul_E && !mul_busy)?1'b1:1'b0;
//    assign div_busy = (Start_Div_E && !div_busy)?1'b1:1'b0;
    
//    wire Math_Stall = (mul_busy & ~Mul_Done_E) | 
//                  (div_busy & ~Div_Done_E);

      //  wire Math_Stall =  ((Start_Mul_E & ~Mul_Done_E) |(Start_Div_E & ~Div_Done_E));
    //=========================================================================
    // 1. DATA HAZARDS: Forwarding Logic (EX Stage)
    // Priority is implicitly given to the Memory stage over Writeback 
    // because it is evaluated first in the if-else chain.
    //=========================================================================
    always @(*) begin
        // Forwarding for ALU Input A (rs1)
        if (RegWrite_M && (rd_M != 0) && (rd_M == rs1_E)) 
            ForwardA_E = 2'b10; // Forward from Memory stage
        else if (RegWrite_W && (rd_W != 0) && (rd_W == rs1_E)) 
            ForwardA_E = 2'b01; // Forward from Writeback stage
        else 
            ForwardA_E = 2'b00; // No hazard, use normal register value
            
        // Forwarding for ALU Input B (rs2)
        if (RegWrite_M && (rd_M != 0) && (rd_M == rs2_E)) 
            ForwardB_E = 2'b10; // Forward from Memory stage
        else if (RegWrite_W && (rd_W != 0) && (rd_W == rs2_E)) 
            ForwardB_E = 2'b01; // Forward from Writeback stage
        else 
            ForwardB_E = 2'b00; // No hazard, use normal register value
    end
    //=========================================================================
    // 2. DETECTION OF AMO INSTRUCTION IN MEM STAGE
    //=========================================================================
    
    // Stall counter - AMO needs exactly 1 extra cycle
    
    always @(posedge clk) begin
        if (~rst)
            amo_stall_done <= 1'b0;
        else if (is_amo_M && !amo_stall_done)
            amo_stall_done <= 1'b1;   // mark that stall cycle is served
        else if (!is_amo_M)
        amo_stall_done <= 1'b0;   // ONLY clear when AMO has LEFT MEM stage
    end
    
    // Stall is active only during the FIRST cycle of AMO in MEM
    wire amo_stall = is_amo_M && !amo_stall_done;
    //=========================================================================
    // 2. LOAD-USE HAZARDS & CONTROL HAZARDS
    // Moved to continuous assignments for cleaner hardware inference
    //=========================================================================
    
    // Detect if the instruction in EX is a Load AND its destination matches a source in Decode
    wire lwStall;
   
    assign lwStall = ((ResultSrc_E == 2'b01) || (ResultSrc_E == 2'b11)) && ((rs1_D == rd_E) || (rs2_D == rd_E));

    // Freeze PC (Fetch) and Decode stage if there is a Load-Use hazard
    assign Stall_F = lwStall |  Mul_Busy_E | Div_Busy_E | amo_stall | (count != 1'b1 && mem_read) | (count1 != 1'b1 && is_mem_read_M) ;
    assign Stall_D = lwStall |  Mul_Busy_E | Div_Busy_E | amo_stall | (count != 1'b1 && mem_read) | (count1 != 1'b1 && is_mem_read_M);
    assign Stall_E = Mul_Busy_E | Div_Busy_E | amo_stall| (count != 1'b1 && mem_read) | (count1 != 1'b1 && is_mem_read_M);
    assign Stall_M = (count != 1'b1  && mem_read) | (count1 != 1'b1 && is_mem_read_M);
    // Flush Decode stage if a branch/jump is taken
    assign Flush_D = PCSrc_E | csr_pc_en;
    
    // Flush Execute stage if a branch/jump is taken OR if there is a Load-Use stall
    // (If we stall D, we must flush E to insert a bubble/NOP)
    assign Flush_E = lwStall | PCSrc_E | csr_pc_en;
    assign Flush_MEM = (Mul_Busy_E | Div_Busy_E) && !amo_stall; //AMO blocks flush *****
    

endmodule