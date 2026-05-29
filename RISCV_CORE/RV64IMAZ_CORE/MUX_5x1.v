//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 07.02.2026 01:56:13
//// Design Name: 
//// Module Name: MUX_8x1
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


//module MUX_8x1 #(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
//        input [WIDTH-1:0]a0,
//        input [WIDTH-1:0]a1,
//        input [WIDTH-1:0]a2,
//        input [WIDTH-1:0]a3,
//        input [WIDTH-1:0]a4,
//        input [WIDTH-1:0]a5,
//        input [WIDTH-1:0]a6,
//        input [2:0]sel,
//        output reg [WIDTH-1:0]y
//            );
    
//    always @(*)
//    begin
//        case(sel)
//             3'b000:y <= a0;
//             3'b001:y <= a1;
//             3'b010:y <= a2;
//             3'b011:y <= a3;
//             3'b100:y <= a4; 
//             3'b101:y <= a5;
//             3'b110:y <= a6;
//            default:y <= a3;
//            endcase
//    end
//endmodule

`timescale 1ns / 1ps

module MUX_8x1 #(
    parameter WIDTH = 64  // Width of the data buses being routed
)(
    input  wire [WIDTH-1:0] a0,   // Input 0 (Selected when sel == 3'b000)
    input  wire [WIDTH-1:0] a1,   // Input 1 (Selected when sel == 3'b001)
    input  wire [WIDTH-1:0] a2,   // Input 2 (Selected when sel == 3'b010)
    input  wire [WIDTH-1:0] a3,   // Input 3 (Selected when sel == 3'b011)
    input  wire [WIDTH-1:0] a4,   // Input 4 (Selected when sel == 3'b100)
    input  wire [WIDTH-1:0] a5,   // Input 5 (Selected when sel == 3'b101)
    input  wire [WIDTH-1:0] a6,   // Input 6 (Selected when sel == 3'b110)
//    input  wire [WIDTH-1:0] a7,   // Input 7 (Selected when sel == 3'b111) - ADDED
    input  wire [2:0]       sel,  // 3-bit select line
    output reg  [WIDTH-1:0] y     // Mux output (declared as reg for always block)
);

    //=========================================================================
    // Multiplexer Logic
    // Using blocking (=) assignments for proper combinational logic inference
    //=========================================================================
    always @(*) begin
        case(sel)
            3'b000:  y = a0;
            3'b001:  y = a1;
            3'b010:  y = a2;
            3'b011:  y = a3;
            3'b100:  y = a4; 
            3'b101:  y = a5;
            3'b110:  y = a6;
           // 3'b111:  y = a7;       // Handled the 8th state
            default: y = {WIDTH{1'bx}}; // Fail-safe default outputs 'X' to catch bugs
        endcase
    end
endmodule
