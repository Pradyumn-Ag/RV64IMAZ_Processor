`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2026 15:48:04
// Design Name: 
// Module Name: AMO_ALU
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


module AMO_ALU #(
    parameter WIDTH = 64
)(
    input  [WIDTH-1:0] RD2_M,         // RS2 - the operand
    input  [WIDTH-1:0] MemData_M,     // original mem[RS1] value
    input  [4:0]       amo_alu_op_M,  // operation select
    output reg [WIDTH-1:0] AMO_Result // value to write back to memory
);

    // AMO Operation Encodings (must match ALU_DECODER)
    localparam AMO_SWAP_W  = 5'b00000;
    localparam AMO_ADD_W   = 5'b00001;
    localparam AMO_AND_W   = 5'b00010;
    localparam AMO_OR_W    = 5'b00011;
    localparam AMO_XOR_W   = 5'b00100;
    localparam AMO_MIN_W   = 5'b00101;
    localparam AMO_MAX_W   = 5'b00110;
    localparam AMO_MINU_W  = 5'b00111;
    localparam AMO_MAXU_W  = 5'b01000;

    localparam AMO_SWAP_D  = 5'b01001;
    localparam AMO_ADD_D   = 5'b01010;
    localparam AMO_AND_D   = 5'b01011;
    localparam AMO_OR_D    = 5'b01100;
    localparam AMO_XOR_D   = 5'b01101;
    localparam AMO_MIN_D   = 5'b01110;
    localparam AMO_MAX_D   = 5'b01111;
    localparam AMO_MINU_D  = 5'b10000;
    localparam AMO_MAXU_D  = 5'b10001;

    wire [31:0] add_w_result = MemData_M[31:0] + RD2_M[31:0];
    wire [31:0] and_w_result = MemData_M[31:0] & RD2_M[31:0];
    wire [31:0] or_w_result  = MemData_M[31:0] | RD2_M[31:0];
    wire [31:0] xor_w_result = MemData_M[31:0] ^ RD2_M[31:0];

    always @(*) begin
        case (amo_alu_op_M)
            //---------------------------------------------
            // WORD operations (32-bit, sign extended to 64)
            //---------------------------------------------
            AMO_SWAP_W: AMO_Result = {{32{RD2_M[31]}},     RD2_M[31:0]};

            AMO_ADD_W:  AMO_Result = {{32{add_w_result[31]}}, add_w_result};
            
            AMO_AND_W:  AMO_Result = {{32{and_w_result[31]}}, and_w_result};
            
            AMO_OR_W:   AMO_Result = {{32{or_w_result[31]}},  or_w_result};
            
            AMO_XOR_W:  AMO_Result = {{32{xor_w_result[31]}}, xor_w_result};

            AMO_MIN_W:  AMO_Result = ($signed(MemData_M[31:0])< 
                                      $signed(RD2_M[31:0]))
                                      ? {{32{MemData_M[31]}}, MemData_M[31:0]}
                                      : {{32{RD2_M[31]}},     RD2_M[31:0]};

            AMO_MAX_W:  AMO_Result = ($signed(MemData_M[31:0]) >
                                      $signed(RD2_M[31:0]))
                                      ? {{32{MemData_M[31]}}, MemData_M[31:0]}
                                      : {{32{RD2_M[31]}},     RD2_M[31:0]};

            AMO_MINU_W: AMO_Result = (MemData_M[31:0] < RD2_M[31:0])
                                      ? {32'b0, MemData_M[31:0]}
                                      : {32'b0, RD2_M[31:0]};

            AMO_MAXU_W: AMO_Result = (MemData_M[31:0] > RD2_M[31:0])
                                      ? {32'b0, MemData_M[31:0]}
                                      : {32'b0, RD2_M[31:0]};

            //------------------------------------------------------------
            //            DOUBLEWORD operations (full 64-bit)
            //------------------------------------------------------------
            AMO_SWAP_D: AMO_Result = RD2_M;

            AMO_ADD_D:  AMO_Result = MemData_M + RD2_M;

            AMO_AND_D:  AMO_Result = MemData_M & RD2_M;

            AMO_OR_D:   AMO_Result = MemData_M | RD2_M;

            AMO_XOR_D:  AMO_Result = MemData_M ^ RD2_M;

            AMO_MIN_D:  AMO_Result = ($signed(MemData_M) < $signed(RD2_M))
                                      ? MemData_M : RD2_M;

            AMO_MAX_D:  AMO_Result = ($signed(MemData_M) > $signed(RD2_M))
                                      ? MemData_M : RD2_M;

            AMO_MINU_D: AMO_Result = (MemData_M < RD2_M)
                                      ? MemData_M : RD2_M;

            AMO_MAXU_D: AMO_Result = (MemData_M > RD2_M)
                                      ? MemData_M : RD2_M;

            default:    AMO_Result = MemData_M; // safe - no change
        endcase
    end

endmodule