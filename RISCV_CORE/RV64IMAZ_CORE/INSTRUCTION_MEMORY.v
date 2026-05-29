//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 03.02.2026 18:48:01
//// Design Name: 
//// Module Name: INSTRUCTION_MEMORY
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


//module INSTRUCTION_MEMORY #(parameter MEMORY_SIZE = 512,
//                            parameter WORD_SIZE = 64)(
//            input [WORD_SIZE-1:0]PC,                    //pointer(address) 
//            output [WORD_SIZE-1:0]Instr                 //Instruction 
//    );
    
//    reg [WORD_SIZE -1 :0] mem [MEMORY_SIZE-1:0];        //Creating memory 
////    $readmemh("instructionhex.mem",mem);
//    integer i;
//    initial 
//        begin
        
//            //for( i = 0;i<MEMORY_SIZE;i= i+1)
//              //  mem[i] = 32'h00000000;                   //allocating initial value of memory as 0
//            $readmemh("instructionhex.mem",mem);    
//        end
    
//    assign Instr = mem[PC[WORD_SIZE -1:2]];              // allocating data to output 
//endmodule
//////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name  : INSTRUCTION_MEMORY
// Description  : Instruction Memory for RISC-V 64-bit Processor
//                - Word-addressable (4-byte aligned)
//                - Initialized from hex file
//                - Read-only (ROM behavior)
//                - Supports RV32I and RV64I instruction sets
//////////////////////////////////////////////////////////////////////////////////

//module INSTRUCTION_MEMORY #(
//    parameter MEMORY_SIZE       = 512,      // Total number of 64-bit words
//    parameter WORD_SIZE         = 64,       // Data bus width (64-bit for RV64)
//    parameter INSTR_SIZE        = 32,       // RISC-V instruction is always 32-bit
//    parameter MEM_FILE          = "instructionhex.mem" // Hex file path
//)(
//    input  wire [WORD_SIZE-1:0]  PC,        // Program Counter (byte addressed)
//    output wire [INSTR_SIZE-1:0] Instr      // 32-bit instruction output
//);

//    //=========================================================================
//    // Memory Declaration
//    // - Stored as 32-bit words (each instruction is 32-bit in RISC-V)
//    // - Size = MEMORY_SIZE words = MEMORY_SIZE * 4 bytes
//    //=========================================================================
    
//    reg [INSTR_SIZE-1:0] mem [0:MEMORY_SIZE-1];

//    //=========================================================================
//    // Memory Initialization
//    // - Load instructions from hex file at simulation start
//    // - Each line in hex file = one 32-bit instruction
//    //=========================================================================
//    initial begin: initialize_mem
//        // Initialize all memory to NOP (addi x0, x0, 0)
//        integer i;
//        for (i = 0; i < MEMORY_SIZE; i = i + 1)
//            mem[i] = 32'h00000013;          // NOP = addi x0, x0, 0

//        // Overwrite with actual instructions from hex file
//        $readmemh(MEM_FILE, mem);

//        // Display confirmation
//        $display("-----------------------------------------------");
//        $display("  Instruction Memory Initialized");
//        $display("  Memory Size : %0d words (%0d bytes)", 
//                  MEMORY_SIZE, MEMORY_SIZE*4);
//        $display("  First Instr : 0x%08h (PC=0x00)", mem[0]);
//        $display("  Hex File    : %s",    MEM_FILE);
//        $display("-----------------------------------------------");
//    end

//    //=========================================================================
//    // Instruction Fetch
//    // - PC is byte-addressed
//    // - Instructions are 4-byte (word) aligned
//    // - PC[1:0] should always be 2'b00 (enforced by hardware)
//    // - Index into memory using PC[MSB:2] to convert byte→word address
//    //=========================================================================
//    assign Instr = mem[PC[WORD_SIZE-1:2]];

//    //=========================================================================
//    // Alignment Check (Simulation Only)
//    // - RISC-V requires PC to always be 4-byte aligned
//    // - Flags a warning if misaligned access is detected
//    //=========================================================================
//    always @(PC) begin
//        if (PC[1:0] != 2'b00) begin
//            $display("WARNING: Misaligned PC detected! PC = 0x%0h", PC);
//            $display("         PC[1:0] must be 2'b00 for word alignment");
//        end

//        // Out of bounds check
//        if (PC[WORD_SIZE-1:2] >= MEMORY_SIZE) begin
//            $display("WARNING: PC out of bounds! PC = 0x%0h", PC);
//            $display("         Max address = 0x%0h", (MEMORY_SIZE-1)*4);
//        end
//    end

//endmodule 

module INSTRUCTION_MEMORY #(
    parameter WORD_SIZE = 64,       // Data bus width
    parameter INSTR_SIZE = 32        // Instruction width
)(
    input  wire                 clk,   // NEW: BRAM requires a clock
    input  wire [WORD_SIZE-1:0] PC,    // Program Counter (byte addressed)
    input  wire            Stall_F,
   // input  wire            PCSrc_corrected,
    output wire [INSTR_SIZE-1:0] Instr // 32-bit instruction output
);

    //=========================================================================
    // BRAM ROM Instantiation
    // - Memory Initialization is now handled by the .coe file in the IP
    // - The 'initial' block and 'reg mem' are no longer needed
    //=========================================================================

    instr_rom_32bit u_instr_rom (
        .clka(clk),                  // Clock signal
        .addra(PC[11:2]),            // Address: Bit-shift PC to get word index
                                     // [11:2] assumes a 1024 depth ROM
        .douta(Instr),               // Data Output
        .ena (~Stall_F)
    );


    //=========================================================================
    // Alignment Check (Simulation Only)
    //=========================================================================
    always @(posedge clk) begin
        if (PC[1:0] != 2'b00) begin
            $display("WARNING: Misaligned PC detected! PC = 0x%0h", PC);
        end
    end

endmodule