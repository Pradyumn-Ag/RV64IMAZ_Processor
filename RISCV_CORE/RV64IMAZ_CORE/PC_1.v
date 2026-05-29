`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.03.2026 18:20:42
// Design Name: 
// Module Name: PC_1
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


 module PC_1#(parameter WIDTH=64,INSTRUCTION_WIDTH=32)(
        input Enable,
        input [WIDTH-1:0]PCNext,  // new PC
        input clk,           // clk
        input rst,           // reset
        output reg [WIDTH-1:0]PC  // old PC
    );
        
        always@(posedge clk)
        begin
        if(~rst)
            PC <= {WIDTH{1'b0}}; 
        else if(~Enable)    
            PC <= PCNext;
        end 

endmodule