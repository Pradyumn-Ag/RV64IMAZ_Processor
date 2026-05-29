
`timescale 1ns / 1ps

module REGISTER_FILE #(
    parameter WIDTH = 64,           // Data bus width (e.g., 64-bit for RV64)
    parameter ADDR_WIDTH = 5,       // Address width (5 bits gives 32 registers)
    parameter NUM_REGS = 32         // Total number of registers
)(
    input  wire                   clk,       // Clock
    input  wire                   rst,       // Active-low reset
    input  wire                   RegWrite,  // Write enable control signal
    input  wire [ADDR_WIDTH-1:0]  A1,        // Read address 1
    input  wire [ADDR_WIDTH-1:0]  A2,        // Read address 2
    input  wire [ADDR_WIDTH-1:0]  A3,        // Write address
    input  wire [WIDTH-1:0]       WD3,       // Data to be written
    output wire [WIDTH-1:0]       RD1,       // Read data 1 output
    output wire [WIDTH-1:0]       RD2        // Read data 2 output
);

    //=========================================================================
    // Register Memory Array
    //=========================================================================
    reg [WIDTH-1:0] rf_mem [NUM_REGS-1:0]; 
    integer i;
    integer j;
    
    //=========================================================================
    // Simulation Initialization
    //=========================================================================
    initial begin
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            rf_mem[i] = {WIDTH{1'b0}};
        end
    end

    //=========================================================================
    // Asynchronous Read with Internal Forwarding
    //=========================================================================
    // Generalized {32{1'bx}} to {WIDTH{1'bx}}
    assign RD1 = ((A3 === A1 && A3 != {ADDR_WIDTH{1'b0}}) ? ((WD3 !== {WIDTH{1'bx}}) ? WD3 : rf_mem[A1]) : rf_mem[A1]);
    assign RD2 = ((A3 === A2 && A3 != {ADDR_WIDTH{1'b0}}) ? ((WD3 !== {WIDTH{1'bx}}) ? WD3 : rf_mem[A2]) : rf_mem[A2]); 

    /*
    assign RD1 = (
    (A3 === A1          // Write address == Read address 1?
    && 
    A3 != {ADDR_WIDTH{1'b0}})  // Not writing to x0?
    ?                           // IF both true:
        (WD3 !== {WIDTH{1'bx}} // Is write data valid (not X)?
        ? WD3                  // YES → forward write data
        : rf_mem[A1])          // NO  → read from memory
    :                          // ELSE (no conflict):
        rf_mem[A1]             // read normally from register file
);

    ## Step by Step Decision Tree

                        Is A3 == A1?
                        (write addr == read addr 1?)
                             │
                  ┌──────────┴──────────┐
               YES                   NO
               │                     │
        Is A3 == x0?              RD1 = rf_mem[A1]
     (writing to zero reg?)    (normal read)
              │
     ┌─────────┴─────────┐
   YES                  NO
    │                    │
RD1 = rf_mem[A1]    Is WD3 valid?
(x0 always 0,       (not X/undefined?)
 no forward)               │
                  ┌────────┴────────┐
                 YES               NO
                  │                 │
            RD1 = WD3         RD1 = rf_mem[A1]
            (FORWARD!)        (use old value)
      
    */

    //=========================================================================
    // Synchronous Write and Asynchronous Reset
    //=========================================================================
    always @(posedge clk) begin
        if (~rst) begin
            // Clear all registers to 0 on reset
            for (j = 0; j < NUM_REGS; j = j + 1) begin
                rf_mem[j] <= {WIDTH{1'b0}};
            end
        end else begin
            // Synchronous write (with protection for Register 0)
            if (RegWrite && A3 != {ADDR_WIDTH{1'b0}}) begin
                rf_mem[A3] <= WD3;
            end
            // Note: The "else rf_mem[A3] <= rf_mem[A3];" from your original 
            // code is not needed. In Verilog, registers automatically hold 
            // their previous value if not explicitly updated.
        end
    end 
endmodule

//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 03.02.2026 17:48:23
//// Design Name: 
//// Module Name: REGISTER_FILE
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


//    module REGISTER_FILE #(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
//        input clk,         // clock
//        input rst,         // reset 
//        input RegWrite,    // control signal for write in register file coming from control unit
//        input [4:0]A1,     // input address of RD1
//        input [4:0]A2,     // input address of RD2
//        input [4:0]A3,     // input address to write in register file
//        input [WIDTH-1:0]WD3,   // contains the data to be written in the register file
//        output [WIDTH-1:0]RD1,  // reads output
//        output [WIDTH-1:0]RD2   // reads output
//    );
    
//    reg [WIDTH-1:0]rf_mem[31:0];   // 32 register memory of word size 32bits.
//    integer i;
    
//    initial 
//    begin
//    rf_mem[0] <= {WIDTH{1'b0}} ;
//    end
//    assign RD1 = ((A3===A1 && A3!==0)? ((WD3 !== {32{1'bx}})?WD3:rf_mem[A1][WIDTH-1:0]) : rf_mem[A1][WIDTH-1:0]);          // reading must be asynchronous 
//    assign RD2 = ((A3===A2 && A3!==0)? ((WD3 !== {32{1'bx}})?WD3:rf_mem[A2][WIDTH-1:0]) : rf_mem[A2][WIDTH-1:0]);          // asynchronous read
//    always @(posedge clk)
//    begin
//    if(~rst)begin
//        // loading 0 in the memory of the register   
//        for ( i = 0; i < 64; i = i + 1) begin
//            rf_mem[i] <= {WIDTH{1'b0}};
//        end
//   end
//   else
//        begin
//        if(RegWrite)
//            rf_mem[A3] <= WD3;
//        else
//            rf_mem[A3]<= rf_mem[A3];
//    end
//  end 
//endmodule


