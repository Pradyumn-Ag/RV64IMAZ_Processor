//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 03.02.2026 18:21:35
//// Design Name: 
//// Module Name: MUX_3x1
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


//module MUX_3x1 #(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
//        input [WIDTH-1:0] a0, // input0
//        input [WIDTH-1:0] a1, //input1
//        input [WIDTH-1:0] a2, //input2
//        input [1:0] sel, //select line
//        output [WIDTH-1:0] y  //output
//);
//assign y = sel[1]?a2:(sel[0]?a1:a0);
//endmodule


`timescale 1ns / 1ps

module MUX_3x1 #(
    parameter WIDTH = 64  // Width of the data buses being routed
)(
    input  wire [WIDTH-1:0] a0,   // Input 0 (Selected when sel == 2'b00)
    input  wire [WIDTH-1:0] a1,   // Input 1 (Selected when sel == 2'b01)
    input  wire [WIDTH-1:0] a2,   // Input 2 (Selected when sel == 2'b10)
    input  wire [1:0]       sel,  // 2-bit select line
    output wire [WIDTH-1:0] y     // Mux output
);

    //=========================================================================
    // Multiplexer Logic
    // Explicit matching prevents silent failures. If sel == 2'b11, it forces 
    // an 'X' state to easily catch control unit bugs during simulation.
    //=========================================================================
    assign y = (sel == 2'b00) ? a0 :
               (sel == 2'b01) ? a1 :
               (sel == 2'b10) ? a2 :
               {WIDTH{1'bx}}; // Safe default for unhandled 2'b11 state

endmodule