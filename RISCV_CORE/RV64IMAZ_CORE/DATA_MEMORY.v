`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.02.2026 18:48:48
// Design Name: 
// Module Name: DATA_MEMORY
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

module DATA_MEMORY #(
    parameter WORD_SIZE   = 64,
    parameter MEMORY_SIZE = 128
)(
    input                       clk,
    input [6:0]                 Opcode,
    input [2:0]                 funct3,
    input [WORD_SIZE-1:0]       ALUResult,
    input [WORD_SIZE-1:0]       WriteData,
    input                       is_amo,
    input                       amo_stall_done,
    input                       MemWrite,
    input [1:0]                 Offset,
    input                       sc_store_valid,
    output wire [WORD_SIZE-1:0] ReadData  // Changed back to wire, driven by IP
);

    // Address and Shift Logic
    wire [WORD_SIZE-4:0] word_addr   = ALUResult[WORD_SIZE-1:3];
    wire [2:0]           byte_offset = ALUResult[2:0];
    
    // 8-bit Write Enable Mask
    reg [7:0] we_mask;

    // Shift the input data so it aligns with the correct bytes in the 64-bit word
    wire [63:0] aligned_data = WriteData << {byte_offset, 3'b000};

    // =========================================================
    // WRITE MASK GENERATION (Replaces your case statement)
    // =========================================================
    always @(*) begin
        we_mask = 8'b00000000; // Default: Write nothing

        if ((Opcode == 7'd35 && MemWrite == 1'b1) || sc_store_valid) begin
            case(funct3)
                3'b000: we_mask = 8'b00000001 << byte_offset; // SB: 1 byte
                3'b001: we_mask = 8'b00000011 << byte_offset; // SH: 2 bytes
                3'b010: we_mask = 8'b00001111 << byte_offset; // SW: 4 bytes
                3'b011: we_mask = 8'b11111111;                // SD: 8 bytes
                default: we_mask = 8'b00000000;
            endcase
        end else if (is_amo && amo_stall_done) begin
            we_mask = 8'b11111111; // AMO writes full word
        end
    end

    // =========================================================
    // BRAM IP INSTANTIATION
    // =========================================================
    // Generate this IP in Vivado: 
    // Single Port RAM, 64-bit width, 128 depth, 
    // Byte Write Enable ON (8-bit), Primitives Output Reg OFF
    
    data_ram_64bit your_data_bram (
        .clka(clk),
        .wea(we_mask),         // Feed the 8-bit mask here
        .addra(word_addr),     // Word aligned address
        .dina(aligned_data),   // The shifted 64-bit data
        .douta(ReadData)       // Data out
    );

endmodule

//THIS IS THE CODE FOR THE SYNCHRONOUS READ AND SYNCHRONOUS WRITE//

//module DATA_MEMORY #(
//    parameter WORD_SIZE   = 64,
//    parameter MEMORY_SIZE = 128
//)(
//    input                       clk,
//    input [6:0]                 Opcode,
//    input [2:0]                 funct3,
//    input [WORD_SIZE-1:0]       ALUResult,
//    input [WORD_SIZE-1:0]       WriteData,
//    input                       is_amo,
//    input                       amo_stall_done,
//    input                       MemWrite,
//    input [1:0]                 Offset,
//    input                       sc_store_valid,

//    // Changed to reg because synchronous read
//    output reg [WORD_SIZE-1:0]  ReadData
//);

//    // Memory Array
//    reg [WORD_SIZE-1:0] mem [0:MEMORY_SIZE-1];

//    // Address Decode
//    wire [WORD_SIZE-4:0] word_addr   = ALUResult[WORD_SIZE-1:3];
//    wire [2:0]           byte_offset = ALUResult[2:0];

//    // Bit shift = byte_offset * 8
//    wire [5:0]           bit_shift   = {byte_offset, 3'b000};

//    integer j;

//    // Memory Initialization
//    initial
//    begin
//        for(j = 0; j < MEMORY_SIZE; j = j + 1)
//        begin
//            mem[j] = 64'h0000000000000000;
//        end
//    end


//    // =========================================================
//    // SYNCHRONOUS READ + WRITE LOGIC
//    // =========================================================
//    always @(posedge clk)
//    begin

//        // =====================================================
//        // SYNCHRONOUS READ
//        // =====================================================
//        ReadData <= mem[word_addr] >> bit_shift;


//        // =====================================================
//        // STORE INSTRUCTIONS
//        // =====================================================
//        if ((Opcode == 7'd35 && MemWrite == 1'b1) || sc_store_valid)
//        begin

//            case(funct3)

//                // SB : Store Byte
//                3'b000:
//                    mem[word_addr][bit_shift +: 8]
//                        <= WriteData[7:0];


//                // SH : Store Half Word
//                3'b001:
//                    mem[word_addr][bit_shift +: 16]
//                        <= WriteData[15:0];


//                // SW : Store Word
//                3'b010:
//                    mem[word_addr][bit_shift +: 32]
//                        <= WriteData[31:0];


//                // SD : Store Double Word
//                3'b011:
//                    mem[word_addr]
//                        <= WriteData;


//                default:
//                    mem[word_addr]
//                        <= mem[word_addr];

//            endcase

//        end


//        // =====================================================
//        // AMO WRITE
//        // =====================================================
//        else if (is_amo && amo_stall_done)
//        begin
//            mem[word_addr] <= WriteData;
//        end

//    end

//endmodule


 
///////EARLIER RUNNING CODE IS STARTING HERE////////////////  
////LOAD_STORE_UNIT //
//module DATA_MEMORY#(parameter WORD_SIZE = 64,
//                    parameter MEMORY_SIZE = 128)(
//        input                   clk,
//        input [6:0]             Opcode,
//        input [2:0]             funct3,
//        input [WORD_SIZE-1:0]   ALUResult,
//        input [WORD_SIZE-1:0]   WriteData,
//        input                   is_amo,
//        input                   amo_stall_done,
//        input                   MemWrite,
//        input [1:0]             Offset,
//        input                   sc_store_valid,
//        output [WORD_SIZE-1:0]  ReadData
//    );
    
////    reg [WORD_SIZE-1:0] mem [0:MEMORY_SIZE-1];
////   // wire [1:0]Offset;
    
////    //assign Offset = ALUResult[1:0];
////    // Memory Array
//    reg [WORD_SIZE-1:0] mem [0:MEMORY_SIZE-1];
    
////    blk_mem_gen_0 your_instance_name (
////  .clka(clka),           // input wire clka
////  .rsta(rsta),           // input wire rsta
////  .wea(wea),             // input wire [0 : 0] wea
////  .addra(addra),         // input wire [11 : 0] addra
////  .dina(dina),           // input wire [63 : 0] dina
////  .douta(douta),         // output wire [63 : 0] douta
////  .rsta_busy(rsta_busy)  // output wire rsta_busy
////);

//    // Decode Addresses
//    // For 64-bit words, the word address is ALUResult[63:3]
//    // The byte offset within that word is ALUResult[2:0]
//    wire [WORD_SIZE-4:0] word_addr   = ALUResult[WORD_SIZE-1:3];  // Decides the address of the row
//    wire [2:0]           byte_offset = ALUResult[2:0];            // Descide the column
    
//    // Multiply offset by 8 to get the bit shift amount (e.g., offset 1 = 8 bits)
//    wire [5:0]           bit_shift   = {byte_offset, 3'b000}; 

//    // Initialization
   
//    integer j;
//    initial 
//        begin
//            for( j = 0;j<MEMORY_SIZE;j= j+1)
//                mem[j] = 64'h00000000;                   //allocating initial value of memory as 0
//        end
    
//    //  assign ReadData = mem[ALUResult[WORD_SIZE-1:3]];
    
//    assign ReadData = mem[word_addr] >> bit_shift;
//    //ERROR///
    
    
//    always@(posedge clk)
//    begin
////       case(MemWrite)
////            4'b1111:mem[ALUResult[WORD_SIZE-1:2]] <= WriteData ;                        // for storing word 
////      //      4'b0111:mem[ALUResult[WORD_SIZE-1:2]] <= {mem[ALUResult[WORD_SIZE-1:2][31:24]],WriteData[23:0]};
////            4'b0011:mem[ALUResult[WORD_SIZE-1:2]] <= {mem[ALUResult[WORD_SIZE-1:2]][31:16],WriteData[15:0]};  // for storing half
////            4'b0001:mem[ALUResult[WORD_SIZE-1:2]] <= {mem[ALUResult[WORD_SIZE-1:2]][31:8],WriteData[7:0]};    //for storing byte   
////       endcase

//    if((Opcode==7'd35 && MemWrite==1) || sc_store_valid)
   
//    begin
//        case(funct3)
////            3'b000:     begin
////                        mem[ALUResult[WORD_SIZE-1:3]][7:0]<= WriteData[7:0];   
//////                        case(Offset)
//////                        2'b00:mem[ALUResult[WORD_SIZE-1:2]][7:0]<=  WriteData[7:0];
//////                        2'b01:mem[ALUResult[WORD_SIZE-1:2]][15:8]<=  WriteData[7:0];
//////                        2'b10:mem[ALUResult[WORD_SIZE-1:2]][23:16]<=  WriteData[7:0];
//////                        2'b11:mem[ALUResult[WORD_SIZE-1:2]][31:24]<=  WriteData[7:0];        //STORING IN THE UPPER BYTE
//////                        endcase
////                        end
                        
////            3'b001:     begin
////                       mem[ALUResult[WORD_SIZE-1:3]][15:0]<= WriteData[15:0];
//////                        case(Offset)
//////                        2'b00:mem[ALUResult[WORD_SIZE-1:2]][15:0]<= WriteData[15:0]; 
//////                        2'b10:mem[ALUResult[WORD_SIZE-1:2]][31:16]<= WriteData[15:0];
//////                        endcase
////                        end
////            3'b010:mem[ALUResult[WORD_SIZE-1:3]][31:0] <= WriteData[31:0];
////            3'b011:mem[ALUResult[WORD_SIZE-1:3]] <= WriteData;
////           default:mem[ALUResult[WORD_SIZE-1:3]] <= mem[ALUResult[WORD_SIZE-1:3]];
////     
//        // SB: Store Byte (8 bits)
//                3'b000: mem[word_addr][bit_shift +: 8]  <= WriteData[7:0];
                
//                // SH: Store Half-word (16 bits)
//                3'b001: mem[word_addr][bit_shift +: 16] <= WriteData[15:0];
                
//                // SW: Store Word (32 bits)
//                3'b010: mem[word_addr][bit_shift +: 32] <= WriteData[31:0];
                
//                // SD: Store Double-word (64 bits)
//                3'b011: mem[word_addr]                  <= WriteData;
                
//                default: mem[word_addr] <= mem[word_addr];
//       endcase
//    end
//    else if (is_amo && amo_stall_done) begin
//        mem[word_addr] <= WriteData; // WriteData_DM = AMO_Result at this point
//    end

//    end
    
    
//endmodule
    
    
 
/////EARLIER RUNNING CODE IS ENDING HERE////////////////    
    
//    `timescale 1ns / 1ps

//module DATA_MEMORY #(
//    parameter WORD_SIZE = 64,       // Datapath width (32 for RV32, 64 for RV64)
//    parameter MEMORY_SIZE = 64      // Total number of addressable words
//)(
//    input  wire                     clk,
//    input  wire [2:0]               funct3,     // Determines size: SB, SH, SW, SD
//    input  wire [WORD_SIZE-1:0]     ALUResult,  // Acts as the memory address
//    input  wire [WORD_SIZE-1:0]     WriteData,  // Data to write
//    input  wire                     MemWrite,   // Write enable from Control Unit
//    output wire [WORD_SIZE-1:0]     ReadData    // Data read out
//);

//    //=========================================================================
//    // Internal Memory Array
//    //=========================================================================
//    reg [WORD_SIZE-1:0] mem [MEMORY_SIZE-1:0];
    
//    //=========================================================================
//    // Address & Offset Decoding
//    // $clog2(WORD_SIZE/8) automatically calculates how many bits the offset needs.
//    // For 64-bit (8 bytes), offset is 3 bits. For 32-bit (4 bytes), offset is 2 bits.
//    //=========================================================================
//    localparam OFFSET_BITS = $clog2(WORD_SIZE/8);
    
//    wire [OFFSET_BITS-1:0] byte_offset = ALUResult[OFFSET_BITS-1:0];
//    wire [31:0]            word_addr   = ALUResult >> OFFSET_BITS;

//    //=========================================================================
//    // Simulation Initialization
//    //=========================================================================
//    integer j;
//    initial begin
//        for(j = 0; j < MEMORY_SIZE; j = j + 1) begin
//            mem[j] = {WORD_SIZE{1'b0}}; // Generalized reset to 0
//        end
//    end

//    //=========================================================================
//    // Asynchronous Read
//    // Note: Sign-extension for loads (LB vs LBU) usually happens in a separate 
//    // extension module or datapath logic, so we just output the raw word here.
//    //=========================================================================
//    assign ReadData = mem[word_addr];

//    //=========================================================================
//    // Synchronous Write with Dynamic Sub-Word Masking
//    //=========================================================================
//    always @(posedge clk) begin
//        if (MemWrite) begin
//            case(funct3)
//                // SB: Store Byte
//                // Syntax [starting_bit +: width] targets the exact byte without wiping the rest
//                3'b000: mem[word_addr][byte_offset*8 +: 8]  <= WriteData[7:0];
                
//                // SH: Store Half-word (16 bits)
//                3'b001: mem[word_addr][byte_offset*8 +: 16] <= WriteData[15:0];
                
//                // SW: Store Word (32 bits)
//                3'b010: mem[word_addr][byte_offset*8 +: 32] <= WriteData[31:0];
                
//                // SD: Store Double-word (64 bits - used in RV64 only)
//                3'b011: mem[word_addr]                      <= WriteData; 
                
//                // Safe default
//                default: mem[word_addr]                     <= WriteData;
//            endcase
//        end
//    end
    
//endmodule