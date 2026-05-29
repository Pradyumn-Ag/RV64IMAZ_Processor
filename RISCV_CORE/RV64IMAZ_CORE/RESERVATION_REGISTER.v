`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.05.2026 20:03:48
// Design Name: 
// Module Name: RESERVATION_REGISTER
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


//module RESERVATION_REGISTER#(
//    parameter WIDTH = 64)(
//    input        clk,
//    input        rst,
//    input        is_lr,
//    input        is_sc,
//    input        [WIDTH-1:0]add,
//    output reg   valid ,                 //
//    output reg   [WIDTH-1:0]reservation_reg 
//    );
    
    
//    always @(posedge clk)begin
//        if(~rst)begin
//            reservation_reg <= 64'b0 ;
//            valid           <= 1'b0; 
//        end
//        else if(is_lr)begin
//            reservation_reg <= add ;
//            valid     <= 1'b1;
//        end
//        else if (is_sc)begin
//            valid     <= 1'b0;
//        end 
//    end
    
//endmodule

module RESERVATION_REGISTER#(
    parameter WIDTH = 64)(
    input        clk,
    input        rst,
    input        is_lr,
    input        is_sc,
    input        [WIDTH-1:0] add,
    input        Stall_M,
    output wire  valid,                // Changed to wire
    output wire  [WIDTH-1:0] reservation_reg // Changed to wire
    );
    
    // Internal sequential registers
    reg internal_valid;
    reg [WIDTH-1:0] internal_res_reg;
    
    // 1. Sequential Logic: Remembers the state for NEXT clock cycles
    always @(posedge clk)begin
        if(~rst)begin
            internal_res_reg <= {WIDTH{1'b0}};
            internal_valid   <= 1'b0; 
        end
        else if(is_lr && ~Stall_M)begin
            internal_res_reg <= add;
            internal_valid   <= 1'b1;
        end
        else if (is_sc && ~Stall_M)begin
            internal_valid   <= 1'b0;
        end 
    end
    
    // 2. Combinational Logic (Bypass): Updates IMMEDIATELY in the current cycle
    // If is_lr is high RIGHT NOW, output 1 immediately. 
    // If is_sc is high RIGHT NOW, output 0 immediately.
    // Otherwise, output whatever was stored in previous cycles.
    assign valid = is_lr ? 1'b1 : internal_valid;
    
    // Same for the address: if is_lr is high NOW, output the incoming address immediately.
    assign reservation_reg = is_lr ? add : internal_res_reg;
    
endmodule