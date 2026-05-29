`timescale 1ns / 1ps

module EXTEND_UNIT #(
    parameter WIDTH = 64,               // Target data width (e.g., 32 for RV32, 64 for RV64)
    parameter IMM_SRC_WIDTH = 3         // Width of the immediate source selector
)(
    input  wire [31:7]                Instr,  // Instruction bits containing immediate fields
    input  wire [IMM_SRC_WIDTH-1:0]   ImmSrc, // Control signal to select immediate type
    output reg  [WIDTH-1:0]           ImmExt  // The sign/zero-extended immediate
);
    
    //=========================================================================
    // Immediate Generation Logic
    // Using $signed() allows Verilog to automatically scale the sign extension
    // up to the defined 'WIDTH' without hardcoding replication counts.
    //=========================================================================
    always @(*) begin
        case(ImmSrc)
            // I-Type (e.g., addi, lw) -> 12-bit sign-extended
            3'b000: ImmExt = $signed(Instr[31:20]); 
            
            // S-Type (e.g., sw) -> 12-bit sign-extended
            3'b001: ImmExt = $signed({Instr[31:25], Instr[11:7]}); 
            
            // B-Type (e.g., beq) -> 13-bit sign-extended (LSB is always 0)
            3'b010: ImmExt = $signed({Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0}); 
            
            // U-Type (e.g., lui, auipc) -> 32-bit sign-extended (lower 12 bits are 0)
            3'b011: ImmExt = $signed({Instr[31:12], 12'b0}); 
            
            // J-Type (e.g., jal) -> 21-bit sign-extended (LSB is always 0)
            3'b100: ImmExt = $signed({Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0}); 
            
            // I-Type Alternate (Often identical to 3'b000 in RISC-V, used by specific decoders)
            3'b101: ImmExt = $signed(Instr[31:20]);
            
            // Z-Type / CSR / Shift Amount (e.g., slli, csrrwi) -> 5-bit ZERO-extended
            3'b110: ImmExt = { {(WIDTH-5){1'b0}}, Instr[24:20] }; 
            
            // Default -> Drive with 'X' to easily catch unhandled states in simulation
            default: ImmExt = {WIDTH{1'bx}};
        endcase
    end
endmodule
//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 02.02.2026 21:06:21
//// Design Name: 
//// Module Name: Extend_unit
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


//  module EXTEND_UNIT #(parameter WIDTH = 64,
//                     parameter EXTENDSGL = 3)(
//    input [31:7] Instr,
//    input [EXTENDSGL-1:0]ImmSrc,
//    output reg [WIDTH-1:0] ImmExt
//    );
    
//    always@(*)
//        begin
//            case(ImmSrc)
//            3'b000:ImmExt = {{52{Instr[31]}},Instr[31:20]}; //I-Type
//            3'b001:ImmExt = {{52{Instr[31]}},Instr[31:25],Instr[11:7]}; //S-Type
//            3'b010:ImmExt = {{52{Instr[31]}},Instr[7],Instr[30:25],Instr[11:8],1'b0}; //B-Type
//            3'b011:ImmExt = {{32{Instr[31]}}, Instr[31:12], 12'b0}; //U - Type
//            3'b100:ImmExt = {{44{Instr[31]}},Instr[19:12],Instr[20],Instr[30:21],{1'b0}}; //J-Type
//            3'b101:ImmExt = {{52{Instr[31]}},{Instr[31:20]}};
//            3'b110:ImmExt = {{59{1'b0}},Instr[24:20]};
//            default:ImmExt = 64'bx;
//        endcase
//    end
//endmodule

///////////////////////////////////////END OF SIGNEXTENDER/////////////////////////////////////////////
