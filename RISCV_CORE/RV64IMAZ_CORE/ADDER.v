`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.02.2026 18:41:28
// Design Name: 
// Module Name: ADDER
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ADDER#(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
        input [WIDTH-1:0]input1,
        input [WIDTH-1:0]input2,
        output [WIDTH-1:0]y
    );
    
    assign y = input1+input2;
endmodule
