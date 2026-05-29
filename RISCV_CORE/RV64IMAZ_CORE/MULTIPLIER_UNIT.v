`timescale 1ns / 1ps

// ============================================================================
// Module      : MULTIPLIER_UNIT
// Description : A multi-cycle Radix-2 Booth Multiplier designed for the 
//               RISC-V RV64M extension. It handles signed, unsigned, and 
//               mixed-sign 64-bit multiplications.
// ============================================================================
module MULTIPLIER_UNIT #(
    parameter WIDTH = 64                        // Width of the data buses
)(  
    // System Signals
    input  wire             clk,                // System clock
    input  wire             rst,                // Active-low synchronous reset
    
    // Control and Data Inputs
    input  wire             start,              // Trigger to begin multiplication
    input  wire [2:0]       op_sel,             // funct3 from the RISC-V instruction
    input  wire [WIDTH-1:0] rs1_data,           // Multiplicand (Source Register 1)
    input  wire [WIDTH-1:0] rs2_data,           // Multiplier (Source Register 2)
    
    // Outputs
    output reg  [WIDTH-1:0] result,             // Final formatted 64-bit product
    output reg              done,               // High when FSM completes computation
    output wire             busy                // High when unit is actively computing
);

    // ------------------------------------------------------------------------
    // Pipeline Control
    // ------------------------------------------------------------------------
    // The pipeline is stalled if a MUL is in the EX stage, UNLESS it is done.
    assign busy = start & ~done;

    // ------------------------------------------------------------------------
    // FSM State Definitions
    // ------------------------------------------------------------------------
    localparam IDEAL = 2'b00;                   // Wait for start signal
    localparam CALC  = 2'b01;                   // Perform Booth's shift-and-add
    localparam FINAL = 2'b10;                   // Format output based on instruction
    localparam WAIT  = 2'b11;                   // Optional wait state (currently unused)
    
    // ------------------------------------------------------------------------
    // Internal Registers
    // ------------------------------------------------------------------------
    reg [6:0]     count;                        // Iteration counter for shift operations
    reg [1:0]     state;                        // Current FSM state 
    
    // Booth's Algorithm Working Registers (Width + 1 for sign extension/overflow)
    reg [WIDTH:0] A;                            // Accumulator (Upper half of product)
    reg [WIDTH:0] M;                            // Multiplicand
    reg [WIDTH:0] Q;                            // Multiplier (Lower half of product)
    reg           Q_1;                          // Extra bit for Booth's inspection
    
    // ------------------------------------------------------------------------
    // Combinational ALU
    // ------------------------------------------------------------------------
    // Continuously calculates addition and subtraction for Booth's algorithm
    wire [WIDTH:0] sum  = A + M;
    wire [WIDTH:0] diff = A + (~M + 1'b1);      // Two's complement subtraction
            
    // ------------------------------------------------------------------------
    // Sequential FSM Logic
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (~rst) begin
            // Reset all outputs and internal registers
            result <= {WIDTH{1'b0}};
            done   <= 1'b0;  
            state  <= IDEAL;                    // CRITICAL: Reset the FSM state!
            count  <= 7'd0;
            A      <= {(WIDTH+1){1'b0}};
            M      <= {(WIDTH+1){1'b0}};
            Q      <= {(WIDTH+1){1'b0}};
        end 
        else begin
            // The FSM runs independently of the 'start' signal once triggered
            case (state)
            
                // ============================================================
                // STATE: IDEAL (Initialization)
                // ============================================================
                IDEAL: begin
                    done <= 1'b0;
                    
                    // Only trigger if 'start' is high AND 'done' is low.
                    // This prevents re-triggering on an old instruction before 
                    // the pipeline advances.
                    if (start && !done) begin
                        
                        Q_1   <= 1'b0;      
                        count <= 7'd65;         // Set iteration count
                        state <= CALC;        
                        done  <= 1'b0;          // Lower flag while calculating
                        
                        // Load working registers based on the specific RISC-V instruction
                        case (op_sel)
                            3'b000, 3'b001: begin // MUL and MULH (Signed x Signed)
                                M <= {rs1_data[WIDTH-1], rs1_data};
                                Q <= {rs2_data[WIDTH-1], rs2_data};
                                A <= {(WIDTH+1){1'b0}}; 
                            end
                            3'b010: begin         // MULHSU (Signed x Unsigned)
                                M <= {rs1_data[WIDTH-1], rs1_data}; // Sign-extend rs1
                                Q <= {1'b0, rs2_data};              // Zero-extend rs2
                                A <= {(WIDTH+1){1'b0}};
                            end
                            3'b011: begin         // MULHU (Unsigned x Unsigned)
                                M <= {1'b0, rs1_data};
                                Q <= {1'b0, rs2_data};
                                A <= {(WIDTH+1){1'b0}};
                            end        
                            3'b100: begin         // MULW (32-bit operation, sign-extended inputs)
                                M <= {{33{rs1_data[31]}}, rs1_data[31:0]}; 
                                Q <= {{33{rs2_data[31]}}, rs2_data[31:0]}; 
                                A <= {(WIDTH+1){1'b0}};
                            end
                            default: begin        // Prevent Latches (Default to Signed)
                                M <= {rs1_data[WIDTH-1], rs1_data};
                                Q <= {rs2_data[WIDTH-1], rs2_data};
                                A <= {(WIDTH+1){1'b0}};
                            end
                        endcase
                    end
                end
                    
                // ============================================================
                // STATE: CALC (Booth's Shift and Add)
                // ============================================================
                CALC: begin
                    // Inspect the current LSB of Q and the history bit (Q_1)
                    // Performs math and arithmetic right shift simultaneously
                    case ({Q[0], Q_1}) 
                        2'b10: begin // Transition from 0 to 1: SUBTRACT and Shift
                            A   <= { diff[WIDTH], diff[WIDTH:1] };
                            Q   <= { diff[0],     Q[WIDTH:1] };
                            Q_1 <= Q[0];
                        end
                        2'b01: begin // Transition from 1 to 0: ADD and Shift
                            A   <= { sum[WIDTH], sum[WIDTH:1] };
                            Q   <= { sum[0],     Q[WIDTH:1] };   
                            Q_1 <= Q[0];
                        end
                        default: begin // 00 or 11: Just Shift (Arithmetic Right Shift)
                            A   <= { A[WIDTH], A[WIDTH:1] };
                            Q   <= { A[0],     Q[WIDTH:1] };
                            Q_1 <= Q[0];
                        end
                    endcase
                    
                    count <= count - 7'd1;
                    
                    // Check if count IS 1 (meaning it WILL become 0 on the next clock edge)
                    // Non-blocking assignment means count is evaluated before it updates
                    if (count == 7'd1)   
                        state <= FINAL;
                    else
                        state <= CALC;         
                end
        
                // ============================================================
                // STATE: FINAL (Output Formatting)
                // ============================================================
                FINAL: begin
                    // Extract the correct portion of the 128-bit product (A, Q) 
                    // depending on the requested RISC-V instruction.
                    case (op_sel)
                        // MUL: Lower 64 bits of the product
                        3'b000:  result <= Q[WIDTH-1:0]; 
                        
                        // MULH: Upper 64 bits (Signed)
                        3'b001:  result <= {A[WIDTH-2:0], Q[WIDTH]}; 
                        
                        // MULHSU: Upper 64 bits (Mixed)
                        3'b010:  result <= {A[WIDTH-2:0], Q[WIDTH]}; 
                        
                        // MULHU: Upper 64 bits (Unsigned)
                        3'b011:  result <= {A[WIDTH-2:0], Q[WIDTH]}; 
                        
                        // MULW: Lower 32 bits, explicitly sign-extended to 64 bits
                        3'b100:  result <= {{32{Q[31]}}, Q[31:0]}; 
                        
                        // Default fallback
                        default: result <= Q[WIDTH-1:0];
                    endcase  
                    
                    done  <= 1'b1;              // Signal completion to pipeline
                    state <= IDEAL;             // Return to idle to await next instruction
                end
                
                // ============================================================
                // STATE: WAIT (Currently disabled/commented out)
                // ============================================================
//              WAIT: begin
//                  // Keep 'done' high so the Hazard Unit knows we are still finished
//                  done <= 1'b1; 
//                  
//                  // Wait here until the pipeline actually moves and drops the start signal
//                  if (~start) begin 
//                      state <= IDEAL; // Safe to reset and wait for new instruction
//                  end
//              end
                
                // ============================================================
                // Default State (Safety Catch)
                // ============================================================
                default: state <= IDEAL;
            endcase 
        end
    end
endmodule 
//`timescale 1ns / 1ps

//module MULTIPLIER_UNIT#(
//    parameter WIDTH = 64                // Width of the data buses being routed
//)(  input  wire          clk,
//    input  wire          rst,
//    input  wire          start,
//    input  wire [2:0]    op_sel,        // funct3 from the instruction
//    input  wire [WIDTH-1:0] rs1_data,   // Multiplicand
//    input  wire [WIDTH-1:0] rs2_data,   // Multiplier
    
//    output reg  [WIDTH-1:0] result,     // Final selected 64-bit chunk
//    output reg           done,          // High when FSM is finished
//    output wire          busy
//);

//// The pipeline is stalled if a MUL is in EX, UNLESS the multiplier is done.
// assign busy = start & ~done;

//    // 1. Define State Machine Parameters
//    localparam IDEAL = 2'b00;  
//    localparam CALC  = 2'b01;
//    localparam FINAL = 2'b10;
//    localparam WAIT  = 2'b11;
    
//    reg  [6:0]   count;                  // count of the operations
//    reg  [1:0]   state;                  // Tells us about the current state 
    
//    reg [WIDTH:0] A;                     // ACCUMULATOR
//    reg [WIDTH:0] M;                     // MULTIPLICAND
//    reg [WIDTH:0] Q;                     // MULTIPLIER
//    reg Q_1;
    
//    // Combinational math wires (Calculates continuously)
//    wire [WIDTH:0] sum  = A + M;
//    wire [WIDTH:0] diff = A + (~M + 1'b1);
           
//    always @(posedge clk)
//    begin
//        if(~rst)
//        begin
//            result <= {WIDTH{1'b0}};
//            done   <= 1'b0;  
//            state  <= IDEAL; // CRITICAL: Reset the FSM state!
//            count  <= 7'd0;
//            A      <= {(WIDTH+1){1'b0}};
//            M      <= {(WIDTH+1){1'b0}};
//            Q      <= {(WIDTH+1){1'b0}};
//        end
//        else 
//        begin
//            // The FSM is now free to run regardless of the 'start' signal
//            case(state)
            
//            IDEAL: begin
//                    done <= 1'b0;
//                // Only trigger if 'start' is high AND 'done' is currently low.
//                // This prevents the FSM from accidentally re-triggering on the OLD 
//                // instruction's start signal before the pipeline has a chance to advance.
//                if(start && !done) begin
                    
//                    Q_1   <= 1'b0;      
//                    count <= 7'd65;     
//                    state <= CALC;        
//                    done  <= 1'b0; // Lower the done flag while calculating
                    
//                    case(op_sel)
//                    3'b000,3'b001: begin // MUL and MULH 
//                            M <= {rs1_data[WIDTH-1],rs1_data};
//                            Q <= {rs2_data[WIDTH-1],rs2_data};
//                            A <= {(WIDTH+1){1'b0}}; // <-- Fully parameterized!
//                            end
//                    3'b010: begin // MULHSU
//                            M <= {rs1_data[WIDTH-1],rs1_data};
//                            Q <= {1'b0,rs2_data};
//                            A <= {(WIDTH+1){1'b0}};
//                            end
//                    3'b011: begin // MULHU
//                            M <= {1'b0,rs1_data};
//                            Q <= {1'b0,rs2_data};
//                            A <= {(WIDTH+1){1'b0}};
//                            end        
//                    3'b100: begin // MULW
//                            M <= {{33{rs1_data[31]}}, rs1_data[31:0]}; 
//                            Q <= {{33{rs2_data[31]}}, rs2_data[31:0]}; 
//                            A <= {(WIDTH+1){1'b0}};
//                            end
//                    default: begin // Prevent Latches
//                            M <= {rs1_data[WIDTH-1],rs1_data};
//                            Q <= {rs2_data[WIDTH-1],rs2_data};
//                            A <= {(WIDTH+1){1'b0}};
//                            end
//                    endcase
//                end
//            end
                   
//            CALC: begin
//                // Fixed Double-Assignment Bug: Do Math and Shift on the exact same line
//                case({Q[0], Q_1}) // Standardized to look at Q[0] first
//                    2'b10: begin // Start of 1s: SUBTRACT and Shift
//                        A   <= { diff[WIDTH], diff[WIDTH:1] };
//                        Q   <= { diff[0], Q[WIDTH:1] };
//                        Q_1 <= Q[0];
//                    end
//                    2'b01: begin // End of 1s: ADD and Shift
//                        A   <= { sum[WIDTH], sum[WIDTH:1] };
//                        Q   <= { sum[0], Q[WIDTH:1] };    
//                        Q_1 <= Q[0];
//                    end
//                    default: begin // 00 or 11: Just Shift (Sign-extended)
//                        A   <= { A[WIDTH], A[WIDTH:1] };
//                        Q   <= { A[0], Q[WIDTH:1] };
//                        Q_1 <= Q[0];
//                    end
//                endcase
                
//                count <= count - 7'd1;
//                // Check if count IS 1 (meaning it WILL become 0 on the next clock edge)
//                if(count == 7'd1)     //As we are using non-blocking assignment thus the count inituilly will be seen as 1 by whole state and will go to 0 after that
//                    state <= FINAL;
//                else
//                    state <= CALC;         
//            end
        
//            FINAL: begin
//                case(op_sel)
//                    // MUL: Lower 64 bits of the product
//                    3'b000:  result <= Q[WIDTH-1:0]; 
                    
//                    // MULH: Upper 64 bits (Signed)
//                    3'b001:  result <= {A[WIDTH-2:0], Q[WIDTH]}; 
                    
//                    // MULHSU: Upper 64 bits (Mixed)
//                    3'b010:  result <= {A[WIDTH-2:0], Q[WIDTH]}; 
                    
//                    // MULHU: Upper 64 bits (Unsigned)
//                    3'b011:  result <= {A[WIDTH-2:0], Q[WIDTH]}; 
                    
//                    // MULW: Lower 32 bits, sign-extended to 64 bits
//                    3'b100:  result <= {{32{Q[31]}}, Q[31:0]}; 
                    
//                    // Default fallback
//                    default: result <= Q[WIDTH-1:0];
//                endcase  
//                done  <= 1'b1;
//                state <= IDEAL ;
//            end
               
////            WAIT: begin
////                // Keep 'done' high so the Hazard Unit knows we are still finished
////                done <= 1'b1; 
                
////                // Wait here until the pipeline actually moves and drops the start signal
////                if (~start) begin 
////                    state <= IDEAL; // Now it is safe to reset and wait for a new instruction
////                end
////            end
//               default: state <= IDEAL;
//            endcase 
//        end
//    end
//endmodule

//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 02.04.2026 20:53:13
//// Design Name: 
//// Module Name: MULTIPLIER_UNIT
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


//module MULTIPLIER_UNIT#(
//    parameter WIDTH = 64  // Width of the data buses being routed
//)(  input  wire        clk,
//    input  wire        rst,
//    input  wire        start,
//    input  wire [2:0]  op_sel,     // funct3 from the instruction
//    input  wire [WIDTH-1:0] rs1_data,   // Multiplicand
//    input  wire [WIDTH-1:0] rs2_data,   // Multiplier
    
//    output reg  [WIDTH-1:0] result,     // Final selected 64-bit chunk
//    output reg         done        // High when FSM is finished
//);

//           reg  [6:0]   count = 7'd65;          //count of the operations
//           reg  [2:0]   state;                  //tells u what kind of operation we are doing
           
//           reg [WIDTH:0] A;                   //ACCUMULATOR
//           reg [WIDTH:0] M;                   //MULTIPLICAND
//           reg [WIDTH:0] Q;                   //MULTIPLIER
//           reg Q_1;
          
//    always @(posedge clk)
//    begin
//        if(~rst)
//        begin
//            result <= {WIDTH{1'b0}};
//            done   <= 1'b1;
//            state  <= IDEAL;       
//        end
//        else if(start)
//        begin
//            case(state)
//            IDEAL: begin
//                   Q_1   <= 1'b0;      // Reset the temp bit
//                   count <= 7'd65;     // Set loop count for 65-bit registers
//                   state <= CALC;        // Move to CALC state next clock cycle
                   
//                   case(op_sel)
//                   3'b000: begin //MUL                                //MUL and MULHU
//                           M <= {rs1_data[WIDTH-1],rs1_data};
//                           Q <= {rs2_data[WIDTH-1],rs2_data};
//                           A <= 65'b0;
//                           end
//                   3'b001: begin //MULH
//                           M <= {rs1_data[WIDTH-1],rs1_data};
//                           Q <= {rs2_data[WIDTH-1],rs2_data};
//                           A <= 65'b0;
//                           end
//                   3'b010: begin //MULHSU
//                           M <= {rs1_data[WIDTH-1],rs1_data};
//                           Q <= {1'b0,rs2_data};
//                           A <= 65'b0;
//                           end
//                   3'b011: begin //MULHU
//                           M <= {1'b0,rs1_data};
//                           Q <= {1'b0,rs2_data};
//                           A <= 65'b0;
//                           end        
//                   3'b100: begin // MULW
//                           // Extract lower 32 bits, and sign-extend them to fill all 65 bits
//                           M <= {{33{rs1_data[31]}}, rs1_data[31:0]}; 
//                           Q <= {{33{rs2_data[31]}}, rs2_data[31:0]}; 
//                           A <= 65'b0;
//                           end
//                   endcase 
//                   end
                   
//            CALC:begin
//                    case({Q_1,Q[0]})
//                        2'b01:A <= A + (~M) + 1;
//                        2'b10:A <= A + M;
//                        default: A<=A;
//                 endcase
//                             A  <= A >>> 1;
//                             Q  <= {A[0],Q[WIDTH-1:1]};
//                             Q_1<= Q[0];
//                             count <= count -1;
//                        if(count==65'b0)
//                            state <= FINAL;
//                        else
//                            state <= CALC;         
//                 end
        
//            FINAL:begin
//                    case(op_sel)
//                        3'b000:result <= Q[WIDTH-1:0]; 
//                        3'b100:result <= {{32{Q[31]}},Q[31:0]};
//                       default:result <= {A[WIDTH-2:0],Q[WIDTH]};
//                    endcase
                        
//                    done <= 1'b1;
//                    state <= IDEAL;
//                  end
//        end
//    end
    
//endmodule