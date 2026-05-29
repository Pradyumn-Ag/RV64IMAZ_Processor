//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 03.02.2026 18:27:37
//// Design Name: 
//// Module Name: MUX_2x1
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


//module MUX_2x1#(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
//        input [WIDTH-1:0] a0,  // input(0) of mux
//        input [WIDTH-1:0] a1,  // input(1) of mux
//        input sel,        // select line of mux
//        output [WIDTH-1:0] y   // output 
//    );
    
//    assign y = sel?a1:a0;

//endmodule


`timescale 1ns / 1ps

module MUX_2x1 #(
    parameter WIDTH = 64  // Width of the data buses being routed
)(
    input  wire [WIDTH-1:0] a0,   // Input 0 (Selected when sel == 0)
    input  wire [WIDTH-1:0] a1,   // Input 1 (Selected when sel == 1)
    input  wire             sel,  // Select line
    output wire [WIDTH-1:0] y     // Mux output
);

    //=========================================================================
    // Multiplexer Logic
    // Uses the ternary operator for clean, synthesizable combinational logic
    //=========================================================================
    assign y = sel ? a1 : a0;

endmodule