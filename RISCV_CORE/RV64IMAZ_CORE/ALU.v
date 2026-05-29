// `timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 02.02.2026 20:41:37
//// Design Name: 
//// Module Name: ALU
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


//module ALU #(parameter WIDTH=64,INSTRUCTION_WIDTH=32) ( // WIDTH is the data bus length or the word size;
//    input [WIDTH-1:0]SrcA,
//    input [WIDTH-1:0]SrcB,
//    input [6:0]Opcode,
//    input [2:0]funct3,
//    input [3:0]ALUControl,      // Control signal recieved form the control register;
//    output reg zero,                // zero flag generated when the result of ALU is 0;
//    output reg [WIDTH-1:0]ALUResult
//    );
    
////ADD,000
////SUB,001
////AND,010
////OR,011
////SLT (Set Less Than) //UNSIGNED,100
////SLL (Shift Left),101
////SRL (Shift Right Log),110
////SRA (Shift Right Arith),111 
//  /////////////////////// logic of the ALU goes below this ///////////////////////
//  wire [WIDTH-1:0] B_processed;
//  wire carry_in;
//  wire [WIDTH-1:0]adder;
//  reg [WIDTH-1:0]temp;       // Used for storing the difference required in the branch instruction 
//  wire [31:0]temp_SrcA;
//  wire [31:0]temp_SrcB;
//  wire [4:0]shift;
//  assign temp_SrcA = SrcA[31:0];
//  assign temp_SrcB = SrcB[31:0];
//  assign shift = SrcB[4:0];
  
//  wire [31:0] sllw_result = temp_SrcA << temp_SrcB[4:0];
//  wire [31:0] srlw_result = temp_SrcA >> temp_SrcB[4:0];
// // wire signed [WIDTH-1:0] sraw_result = $signed(temp_SrcA)>>>temp_SrcB[4:0];  
//  wire signed [WIDTH-1:0] sra_result = $signed(SrcA) >>> SrcB[5:0];                                
//  wire [WIDTH-1:0] sraw_result = $signed(temp_SrcA)>>>shift;
  
//  assign B_processed = SrcB^{WIDTH{ALUControl[0]}};
//  assign carry_in = ALUControl[0];
//  assign adder = SrcA+B_processed+carry_in;
  
//  always@(*)
//  begin
//        temp = adder;
//  end
  
//  always@(*)
//    begin
//        zero = 1'b0;    //Default value prevents latches
//        if(Opcode == 7'd99)
//            begin
//                case(funct3)
//                3'b000:zero = ~(|temp);                    // branch if equal
//                3'b001:zero = (|temp);                     // branch if unequal
//                3'b100:zero = $signed(SrcA)<$signed(SrcB); // brnach if set less than signed
//                3'b101:zero = ~($signed(SrcA)<$signed(SrcB));// branch if greater than equal signed
//                3'b110:zero = $unsigned(SrcA)<$unsigned(SrcB);// branch if set less than unsigned 
//                3'b111:zero = ~($unsigned(SrcA)<$unsigned(SrcB));// branch if greater than equal unsigned
//                endcase
//            end
   
//    end
//  always@(*)
//        begin
//        case(ALUControl)
//            4'b0000: ALUResult = adder;                           //Adder
//            4'b0001: ALUResult = adder;                           //Subtractor
//            4'b0010: ALUResult = SrcA&SrcB;                       //AND
//            4'b0011: ALUResult = SrcA|SrcB;                       //OR
//            4'b0100: ALUResult = $signed(SrcA)<$signed(SrcB);     //signed set less than
//            4'b0101: ALUResult = SrcA<<SrcB[5:0];                 // shift left
//            4'b0110: ALUResult = SrcA>>SrcB[5:0];                      //SRL
//            4'b0111: ALUResult = sra_result;            //SRA 
//            4'b1000: ALUResult = SrcA^SrcB;                       //xor operation
//            4'b1001: ALUResult = $unsigned(SrcA)<$unsigned(SrcB);     //unsigned set less than
//            4'b1010: ALUResult = {{32{adder[31]}},adder[31:0]};       //ADDW
//            4'b1011: ALUResult = {{32{adder[31]}},adder[31:0]};       //SUBW
//            4'b1100: ALUResult = {{32{sllw_result[31]}},{sllw_result}};//sllw
//            4'b1101: ALUResult = {{32{srlw_result[31]}},{srlw_result}};//srlw
//            4'b1110: ALUResult = $signed($signed(SrcA[31:0]) >>> SrcB[4:0]);
//            //4'b1011: ALUResult = SrcA^SrcB;
//            default: ALUResult = 64'd0;
//        endcase
//    end
//endmodule


`timescale 1ns / 1ps

module ALU #(
    parameter WIDTH = 64
)(
    input  wire [WIDTH-1:0] SrcA,
    input  wire [WIDTH-1:0] SrcB,
    input  wire [6:0]       Opcode,
    input  wire [2:0]       funct3,
    input  wire [3:0]       ALUControl, // Control signal received from the control register
    output reg              zero,       // zero flag generated for branch instructions
    output reg  [WIDTH-1:0] ALUResult
);

    // =========================================================================
    // 1. Internal Wires & Pre-computations
    // =========================================================================
    
    // 32-bit extractions for 'W' instructions (RV64)
    wire [31:0] srcA_32  = SrcA[31:0];
    wire [31:0] srcB_32  = SrcB[31:0];
    wire [4:0]  shift_32 = SrcB[4:0];
    wire [5:0]  shift_64 = SrcB[5:0];

    // Manual 2's Complement Adder/Subtractor Logic
    wire [WIDTH-1:0] b_processed = SrcB ^ {WIDTH{ALUControl[0]}};
    wire             carry_in    = ALUControl[0];
    wire [WIDTH-1:0] adder_out   = SrcA + b_processed + carry_in;

    // Shift operation pre-computations
    wire [31:0]              sllw_result = srcA_32 << shift_32;
    wire [31:0]              srlw_result = srcA_32 >> shift_32;
    wire signed [WIDTH-1:0]  sra_result  =  $signed($signed(SrcA) >>> shift_64); 

    // =========================================================================
    // 2. Branch Logic (Zero Flag Evaluation)
    // =========================================================================
    always @(*) begin
        zero = 1'b0; // Default value prevents latches
        
        // 7'd99 (7'b1100011) is the standard RISC-V Branch Opcode
        if (Opcode == 7'd99) begin
            case(funct3)
                3'b000: zero = ~(|adder_out);                           // BEQ (Branch if Equal)
                3'b001: zero = (|adder_out);                            // BNE (Branch if Not Equal)
                3'b100: zero = $signed(SrcA) < $signed(SrcB);           // BLT (Branch Less Than Signed)
                3'b101: zero = ~($signed(SrcA) < $signed(SrcB));        // BGE (Branch Greater/Equal Signed)
                3'b110: zero = $unsigned(SrcA) < $unsigned(SrcB);       // BLTU (Branch Less Than Unsigned)
                3'b111: zero = ~($unsigned(SrcA) < $unsigned(SrcB));    // BGEU (Branch Greater/Equal Unsigned)
                default: zero = 1'b0;
            endcase
        end
    end

    // =========================================================================
    // 3. ALU Result Multiplexer
    // =========================================================================
    always @(*) begin
        case(ALUControl)
            // Standard 64-bit Operations
            4'b0000: ALUResult = adder_out;                                      // ADD
            4'b0001: ALUResult = adder_out;                                      // SUB
            4'b0010: ALUResult = SrcA & SrcB;                                    // AND
            4'b0011: ALUResult = SrcA | SrcB;                                    // OR
            4'b0100: ALUResult = $signed(SrcA) < $signed(SrcB);                  // SLT (Signed Set Less Than)
            4'b0101: ALUResult = SrcA << shift_64;                               // SLL (Shift Left Logical)
            4'b0110: ALUResult = SrcA >> shift_64;                               // SRL (Shift Right Logical)
            4'b0111: ALUResult = sra_result;                                     // SRA (Shift Right Arithmetic)
            4'b1000: ALUResult = SrcA ^ SrcB;                                    // XOR
            4'b1001: ALUResult = $unsigned(SrcA) < $unsigned(SrcB);              // SLTU (Unsigned Set Less Than)
            
            // 32-bit Word Operations (Sign-Extended to 64-bit)
            4'b1010: ALUResult = {{32{adder_out[31]}}, adder_out[31:0]};         // ADDW
            4'b1011: ALUResult = {{32{adder_out[31]}}, adder_out[31:0]};         // SUBW
            4'b1100: ALUResult = {{32{sllw_result[31]}}, sllw_result};           // SLLW
            4'b1101: ALUResult = {{32{srlw_result[31]}}, srlw_result};           // SRLW
            4'b1110: ALUResult = $signed($signed((srcA_32)) >>> shift_32);         // SRAW
            
            // Fallback
            default: ALUResult = {WIDTH{1'b0}};
        endcase
    end

endmodule