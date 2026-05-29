`timescale 1ns / 1ps

// ============================================================================
// Module      : DIVIDER_UNIT
// Description : A multi-cycle sequential divider designed for the RISC-V 
//               RV64M extension. Supports 32-bit (word) and 64-bit signed 
//               and unsigned division and remainder operations. Handles 
//               RISC-V specific edge cases like divide-by-zero and overflow.
// ============================================================================
module DIVIDER_UNIT #(
    parameter WIDTH = 64                        // Width of the data buses
)(
    // System Signals
    input  wire             clk,
    input  wire             rst, 
    
    // Control and Data Inputs
    input  wire             start,              // Wakes up the Divider FSM
    input  wire             is_word,            // 1 = 32-bit operation, 0 = 64-bit operation
    input  wire [2:0]       op_sel,             // funct3: DIV, DIVU, REM, or REMU
    input  wire [WIDTH-1:0] rs1_data,           // Dividend
    input  wire [WIDTH-1:0] rs2_data,           // Divisor
    
    // Outputs
    output reg  [WIDTH-1:0] result,             // Final formatted quotient or remainder
    output reg              done,               // 1-bit flag signaling FSM completion
    output wire             busy                // High when unit is actively computing
); 
    
    // ------------------------------------------------------------------------
    // Pipeline Control
    // ------------------------------------------------------------------------
    assign busy = start & ~done;
    
    // ------------------------------------------------------------------------
    // FSM State Definitions
    // ------------------------------------------------------------------------
    localparam IDEAL     = 2'b00;               // Idle, wait for start 
    localparam CALC      = 2'b01;               // Shift-and-subtract math phase
    localparam FINAL     = 2'b10;               // Output formatting and sign application
    localparam EDGE_CASE = 2'b11;               // Handles Div-by-0 and Overflow instantly
    
    // ------------------------------------------------------------------------
    // Internal Registers
    // ------------------------------------------------------------------------
    reg [1:0] state;                            // Current FSM state 
    reg [6:0] count;                            // Iteration counter (32 or 64 loops)
    
    // Sign-tracking registers for post-calculation formatting
    reg sign_dividend;
    reg sign_divisor;
    
    // Working registers for division algorithm
    reg [WIDTH:0]   A;                          // ACCUMULATOR (65 bits for sign bit)
    reg [WIDTH:0]   M;                          // DIVISOR (65 bits for sign bit)
    reg [WIDTH-1:0] Q;                          // DIVIDEND/QUOTIENT (64 bits)
    
    // ------------------------------------------------------------------------
    // Combinational Math & Helper Wires
    // ------------------------------------------------------------------------
    // Two's complement formatting for 32-bit results
    wire [31:0] Q_32bit = ((sign_dividend ^ sign_divisor) ? ((~Q[31:0]) + 1) : (Q[31:0]));
    wire [31:0] A_32bit = sign_dividend ? (~A[31:0] + 1) : A[31:0];
    
    // --- COMBINATIONAL LOGIC FOR CALC STATE ---
    // 1. Shift [A, Q] left by 1. Q's MSB moves into A's LSB.
    wire [WIDTH:0] shifted_A = {A[WIDTH-1:0], Q[WIDTH-1]};

    // 2. Add or Subtract M based on the CURRENT sign of A (A[WIDTH] is the MSB)
    //    If A[WIDTH] is 1 (Negative), we ADD. If 0 (Positive), we SUBTRACT.
    wire [WIDTH:0] next_A = A[WIDTH] ? (shifted_A + M) : (shifted_A - M);

    // 3. Find the new Q0 bit. It's the inverted sign of the NEW A.
    wire q_bit = ~next_A[WIDTH];
    
    // --- RISC-V EDGE CASE DETECTION ---
    wire is_div_by_zero = (is_word) ? (rs2_data[31:0] == 32'd0) : (rs2_data == 0);
    
    wire is_overflow    = (is_word) ? 
        // 32-bit overflow: -2147483648 / -1
        ((rs1_data[31:0] == 32'h80000000) && (rs2_data[31:0] == 32'hFFFFFFFF)) :
        // 64-bit overflow: -9223372036854775808 / -1
        ((rs1_data == {1'b1, {(WIDTH-1){1'b0}}}) && (rs2_data == {WIDTH{1'b1}}));
        
    // Only signed instructions (DIV, REM) care about overflow. Unsigned cannot overflow.
    wire is_signed_op   = (op_sel == 3'b100) || (op_sel == 3'b110);


    // ------------------------------------------------------------------------
    // Sequential FSM Logic
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (~rst) begin
            result        <= {WIDTH{1'b0}};
            done          <= 1'b0;               
            state         <= IDEAL; 
            count         <= 7'd0; 
            A             <= {(WIDTH+1){1'b0}};  // 65 bits
            M             <= {(WIDTH+1){1'b0}};  // 65 bits
            Q             <= {WIDTH{1'b0}};      // 64 bits
            sign_dividend <= 1'b0;
            sign_divisor  <= 1'b0;
        end 
        else begin
            // FSM state execution
            case (state)
            
                // ============================================================
                // STATE: IDEAL (Initialization)
                // ============================================================
                IDEAL: begin
                    done <= 1'b0;
                    
                    if (start && !done) begin
                        // Check for RISC-V specified math exceptions immediately
                        if (is_div_by_zero || (is_overflow && is_signed_op)) begin
                            // Intercept the exception! Skip the 64-cycle math.
                            state <= EDGE_CASE;
                            done  <= 1'b0;
                        end else begin 
                            done  <= 1'b0;
                            state <= CALC;
                            A     <= {(WIDTH+1){1'b0}};
                            
                            // Set the iteration counter based on word vs double-word
                            if (is_word) begin
                                count <= 7'd32;
                            end else begin
                                count <= 7'd64;
                            end
                            
                            // Load registers based on instruction type
                            case (op_sel)
                                // --- SIGNED INSTRUCTIONS (DIV, REM) ---
                                3'b100, 3'b110: begin
                                    if (is_word) begin
                                        // 32-BIT SIGNED LOGIC
                                        sign_dividend <= rs1_data[31];
                                        sign_divisor  <= rs2_data[31];    
                                        Q <= rs1_data[31] ? {(~rs1_data[31:0] + 1), 32'd0} : {rs1_data[31:0], 32'd0};
                                        M <= rs2_data[31] ? {33'd0, (~rs2_data[31:0] + 1)} : {33'd0, rs2_data[31:0]};
                                    end else begin
                                        // 64-BIT SIGNED LOGIC
                                        sign_dividend <= rs1_data[63];
                                        sign_divisor  <= rs2_data[63];
                                        Q <= rs1_data[63] ? (~rs1_data + 1)      : rs1_data;
                                        M <= rs2_data[63] ? {1'b0, (~rs2_data + 1)} : {1'b0, rs2_data};
                                    end
                                end  
                                
                                // --- UNSIGNED INSTRUCTIONS (DIVU, REMU) ---
                                3'b101, 3'b111: begin
                                    // It's unsigned! Force the saved signs to 0.
                                    sign_dividend <= 1'b0; 
                                    sign_divisor  <= 1'b0;
                                    
                                    if (is_word) begin
                                        // 32-BIT UNSIGNED LOGIC
                                        Q <= {rs1_data[31:0], 32'd0}; // Load lower 32 bits, zero-pad top
                                        M <= {33'd0, rs2_data[31:0]}; // Load lower 32 bits into 65-bit M
                                    end else begin
                                        // 64-BIT UNSIGNED LOGIC
                                        Q <= rs1_data;
                                        M <= {1'b0, rs2_data};        // Pad the 65th bit with 0
                                    end
                                end
                                
                                default: begin
                                    state <= IDEAL; // Failsafe
                                    done  <= 1'b1;
                                end
                            endcase
                        end
                    end 
                end
                
                // ============================================================
                // STATE: CALC (Sequential Division Math)
                // ============================================================
                CALC: begin
                    if (count > 0) begin
                        // MATH PHASE: Perform shift and conditional add/sub
                        count <= count - 1;
                        A     <= next_A;
                        Q     <= {Q[WIDTH-2:0], q_bit};
                        state <= CALC;
                    end else begin
                        // RESTORE PHASE: Correct the remainder if it went negative
                        if (A[WIDTH]) begin
                            A <= A + M;  
                        end
                        // Move to formatting
                        state <= FINAL;  
                    end
                end 
                
                // ============================================================
                // STATE: FINAL (Formatting and Sign Restoration)
                // ============================================================
                FINAL: begin
                    done  <= 1'b1;
                    state <= IDEAL;
                    
                    case (op_sel)
                        // DIV (Signed Quotient)
                        3'b100: result <= is_word ? 
                                          {{32{Q_32bit[31]}}, Q_32bit} :
                                          ((sign_dividend ^ sign_divisor) ? (~Q + 1) : Q);
                                         
                        // DIVU (Unsigned Quotient) AND DIVUW
                        3'b101: result <= is_word ? 
                                          {{32{1'b0}}, Q[31:0]} :
                                          Q;
                        
                        // REM (Signed Remainder)
                        3'b110: result <= is_word ? 
                                          {{32{A_32bit[31]}}, A_32bit} :
                                          (sign_dividend ? (~A[WIDTH-1:0] + 1) : A[WIDTH-1:0]);
                        
                        // REMU (Unsigned Remainder)
                        3'b111: result <= is_word ? 
                                          {{32{1'b0}}, A[31:0]} :
                                          A[WIDTH-1:0];
                    endcase
                end
                
                // ============================================================
                // STATE: EDGE_CASE (Handling RISC-V defin  ed exceptions)
                // ============================================================
                EDGE_CASE: begin
                    done  <= 1'b1;     // Tell Hazard Unit we are finished!
                    state <= IDEAL;    // Go back to sleep next cycle
    
                    // RISC-V Spec dictates specific outputs based on exception type
                    if (is_div_by_zero) begin
                        case (op_sel)
                            // DIV / DIVU: Quotient is all 1s (-1)
                            3'b100, 3'b101: result <= {WIDTH{1'b1}}; 
                
                            // REM / REMU: Remainder is the Dividend (rs1_data)
                            3'b110, 3'b111: begin
                                if (is_word)
                                    result <= {{32{rs1_data[31]}}, rs1_data[31:0]}; // Sign-extend
                                else
                                    result <= rs1_data;
                            end
                            default: result <= {WIDTH{1'b0}};
                        endcase
                    end 
                    else if (is_overflow) begin
                        case (op_sel)
                            // DIV: Quotient is the most negative number
                            3'b100: begin
                                if (is_word)
                                    result <= {{32{1'b1}}, 32'h80000000}; // Sign-extended 32-bit max negative
                                else
                                    result <= {1'b1, {(WIDTH-1){1'b0}}};  // 64-bit max negative
                            end
                            
                            // REM: Remainder is 0
                            3'b110:  result <= {WIDTH{1'b0}}; 
                            
                            default: result <= {WIDTH{1'b0}};
                        endcase
                    end
                end
            endcase
        end
    end
endmodule

/* ==============================================================================
                            OLD/COMMENTED CODE
==============================================================================
//    wire [WIDTH:0] shifted_A = {A[WIDTH-1:0], Q[WIDTH-1]};
//    wire [WIDTH:0] next_A = A[WIDTH] ? (shifted_A + M) : (shifted_A - M);
//    wire q_bit = ~next_A[WIDTH];
//            CALC: begin
//                    count <= count - 1;
//                    A <= next_A;
//                    Q <= {Q[WIDTH-2:0],q_bit};
//                    if(count==0)begin
//                        if(A[WIDTH])begin
//                           A = A + M; 
//                           STATE<=FINAL;
//                        end
//                        else
//                        state<=FINAL;   
//                    end
//                    else
//                    state<=CALC;
//                  end  

//                    if(start) begin 
//                    if(is_word)
//                    begin
//                        count<= 7'd32;
//                        done <= 1'b0;
//                        state<= CALC;
//                        sign_dividend<=rs1_data[31];
//                        sign_divisor <=rs2_data[31];
//                        case(op_sel)
//                        3'b000:
//                    end   
//                    else begin
//                        count<= 7'd64;
//                        done <= 1'b0;
//                        state<= CALC;
//                        sign_dividend<=rs1_data[63];
//                        sign_divisor <=rs2_data[63];
//                    end
*/

//module DIVIDER_UNIT #(
//    parameter WIDTH = 64  // Width of the data buses being routed
//)(
//        input               clk,
//        input               rst, 
//        input               start,            // Wakes up the Divider FSM
//        input               is_word,
//        input [2:0]         op_sel,           // Tells the Divider to do DIV, DIVU, REM, or REMU
//        input [WIDTH-1:0]   rs1_data,         // Dividend
//        input [WIDTH-1:0]   rs2_data,         // Divisor
//        output reg [WIDTH-1:0] result,        // Routes to your Execution 3-to-1 MUX
//        output reg          done,              // 1-BIT FLAG! Routes to Hazard Unit
//        output wire         busy
//    ); 
    
//    assign busy = start & ~done;
    
//    localparam IDEAL = 2'b00;  
//    localparam CALC  = 2'b01;
//    localparam FINAL = 2'b10;
//    localparam EDGE_CASE = 2'b11;
    
//    reg  [6:0]   count;                  // count of the operations
//    reg  [1:0]   state;                  // Tells us about the current state 
    
//    // We need 1-bit registers to remember the original signs for the FINAL state!
//    reg sign_dividend;
//    reg sign_divisor;
    
//    reg [WIDTH:0]   A;                      // ACCUMULATOR (65 bits for sign!)
//    reg [WIDTH:0]   M;                      // DIVISOR (65 bits for sign!)
//    reg [WIDTH-1:0] Q;                      // DIVIDEND (64 bits)
    
//    wire [31:0] Q_32bit = ((sign_dividend^sign_divisor)?((~Q[31:0])+1):(Q[31:0]));
//    wire [31:0] A_32bit = sign_dividend ? (~A[31:0]+1) : A[31:0];
    
//    // --- COMBINATIONAL LOGIC FOR CALC STATE ---
//    // 1. Shift [A, Q] left by 1. We only care about A getting Q's MSB.
//    wire [WIDTH:0] shifted_A = {A[WIDTH-1:0], Q[WIDTH-1]};

//    // 2. Add or Subtract M based on the CURRENT sign of A (A[WIDTH] is the MSB)
//    // If A[WIDTH] is 1 (Negative), we ADD. If 0 (Positive), we SUBTRACT.
//    wire [WIDTH:0] next_A = A[WIDTH] ? (shifted_A + M) : (shifted_A - M);

//    // 3. Find the new Q0 bit. It's the inverted sign of the NEW A.
//    wire q_bit = ~next_A[WIDTH];
    
//    // --- EDGE CASE DETECTION ---
//    wire is_div_by_zero = (is_word) ? (rs2_data[31:0] == 32'd0) : (rs2_data == 0);
//    // Check for 0 value in both the cases depending on the type of instruction
//    wire is_overflow    = (is_word) ? 
//    // 32-bit overflow: -2147483648 / -1
//    ((rs1_data[31:0] == 32'h80000000) && (rs2_data[31:0] == 32'hFFFFFFFF)) :
//    // 64-bit overflow: -9223372036854775808 / -1
//    ((rs1_data == {1'b1, {(WIDTH-1){1'b0}}}) && (rs2_data == {WIDTH{1'b1}}));
//    // Only signed instructions (DIV, REM) care about overflow. Unsigned instructions don't overflow!
//    wire is_signed_op   = (op_sel == 3'b100) || (op_sel == 3'b110);


//    always @(posedge clk)
//    begin
//        if(~rst)
//        begin
//            result <= {WIDTH{1'b0}};
//            done   <= 1'b0;              // Reset to 0!
//            state  <= IDEAL; 
//            count  <= 7'd0; 
//            A      <= {(WIDTH+1){1'b0}}; // 65 bits
//            M      <= {(WIDTH+1){1'b0}}; // 65 bits
//            Q      <= {(WIDTH){1'b0}};   // 64 bits
//            sign_dividend <= 1'b0;
//            sign_divisor  <= 1'b0;
//        end
//        else 
//        begin
//            // The FSM is now free to run regardless of the 'start' signal
//            case(state)
            
//            IDEAL: begin
//                done<=0;
//                if(start && !done) begin
//                  if (is_div_by_zero || (is_overflow && is_signed_op)) begin
//            // Intercept the exception! Skip the 64-cycle math.
//            state <= EDGE_CASE;
//            done  <= 1'b0;
//               end else begin 
//                done  <= 1'b0;
//                state <= CALC;
//                A     <= {(WIDTH+1){1'b0}};
                
//                // setting the count 
//                if(is_word) begin
//                        count <= 7'd32;
//                    end else begin
//                        count <= 7'd64;
//                    end
                    
//                case(op_sel)
//                // --- SIGNED INSTRUCTIONS (DIV, REM) ---
//                      3'b100, 3'b110: begin
//                      if(is_word) begin
//               // 32-BIT SIGNED LOGIC
//                      sign_dividend <= rs1_data[31];
//                      sign_divisor  <= rs2_data[31];    
//                      Q <= rs1_data[31] ? { (~rs1_data[31:0] + 1),32'd0 } : {rs1_data[31:0],32'd0};
//                      M <= rs2_data[31] ? { 33'd0,(~rs2_data[31:0] + 1)} : {33'd0, rs2_data[31:0]};
                      
//                end
//                else begin
//                // 64-BIT SIGNED LOGIC
//                       sign_dividend <= rs1_data[63];
//                       sign_divisor  <= rs2_data[63];
//                       Q <= rs1_data[63] ? (~rs1_data + 1) : rs1_data;
//                       M <= rs2_data[63] ? {1'b0,(~rs2_data + 1)} : {1'b0,rs2_data};
                
                         
//                 end
//            end  
//                  3'b101, 3'b111: begin
//                            // It's unsigned! Force the saved signs to 0.
//                            sign_dividend <= 1'b0; 
//                            sign_divisor  <= 1'b0;
                            
//                            if(is_word) begin
//                                // 32-BIT UNSIGNED LOGIC
//                                Q <= { rs1_data[31:0],32'd0 }; // Load lower 32 bits, zero-pad the top
//                                M <= { 33'd0 ,rs2_data[31:0]}; // Load lower 32 bits into 65-bit M
//                            end else begin
//                                // 64-BIT UNSIGNED LOGIC
//                                Q <= rs1_data;
//                                M <= { 1'b0, rs2_data }; // Pad the 65th bit with 0
//                            end
//                        end
                        
//                        default: begin
//                            state <= IDEAL; // Failsafe
//                            done  <= 1'b1;
//                        end
//                    endcase
//              end
//           end 
//           end
           
//    wire [WIDTH:0] shifted_A = {A[WIDTH-1:0], Q[WIDTH-1]};
//    wire [WIDTH:0] next_A = A[WIDTH] ? (shifted_A + M) : (shifted_A - M);
//    wire q_bit = ~next_A[WIDTH];
//            CALC: begin
//                    count <= count - 1;
//                    A <= next_A;
//                    Q <= {Q[WIDTH-2:0],q_bit};
//                    if(count==0)begin
//                        if(A[WIDTH])begin
//                           A = A + M; 
//                           STATE<=FINAL;
//                        end
//                        else
//                        state<=FINAL;    
//                    end
//                    else
//                    state<=CALC;
//                  end  

//        CALC: begin
//        if (count > 0) begin
//        // MATH PHASE: Only do this if count is NOT zero
//        count <= count - 1;
//        A     <= next_A;
//        Q     <= {Q[WIDTH-2:0], q_bit};
//        state <= CALC;
        
//    end else begin
//        // RESTORE PHASE: Only do this when count IS zero
//        if (A[WIDTH]) begin
//            A <= A + M;  // Use <= instead of =
//        end
//        // Notice we DO NOT do A <= next_A here!
        
//        state <= FINAL;  // Use lowercase state
//    end
//end 
//            FINAL: begin
//                done  <= 1'b1;
//                state <= IDEAL;
//                case(op_sel)
//                3'b100:  result <= is_word ? 
//                                {{32{Q_32bit[31]}},Q_32bit}:
//                                ((sign_dividend^sign_divisor)?(~Q+1):Q);
                                 
//                3'b101:result <= is_word ? 
//                                {{32{Q[31]}},Q[31:0]}:
//                                Q ;
                
//                3'b110:  result <= is_word ? 
//                                {{32{A_32bit[31]}},A_32bit}:
//                                ((sign_dividend)?(~A[WIDTH-1:0]+1):A[WIDTH-1:0]);
                
//                3'b111:result <= is_word ? 
//                                {{32{A[31]}},A[31:0]}:
//                                 A[WIDTH-1:0] ;
                
//                endcase
//            end
//                EDGE_CASE: begin
//                done  <= 1'b1;     // Tell the Hazard Unit we are finished!
//                state <= IDEAL;    // Go back to sleep next cycle
    
//                // RISC-V Spec dictates specific outputs based on the operation and the exception
//                 if (is_div_by_zero) begin
//                 case(op_sel)
//                 // DIV / DIVU: Quotient is all 1s (-1)
//                 3'b100, 3'b101: result <= {WIDTH{1'b1}}; 
            
//                // REM / REMU: Remainder is the Dividend (rs1_data)
//                3'b110, 3'b111: begin
//                if (is_word)
//                    result <= {{32{rs1_data[31]}}, rs1_data[31:0]}; // Sign-extend 32-bit remainder
//                else
//                    result <= rs1_data;
//                end
//            default: result <= {WIDTH{1'b0}};
//        endcase
//    end 
//    else if (is_overflow) begin
//        case(op_sel)
//            // DIV: Quotient is the most negative number (Dividend)
//            3'b100: begin
//                if (is_word)
//                    result <= {{32{1'b1}}, 32'h80000000}; // Sign-extended 32-bit negative max
//                else
//                    result <= {1'b1, {(WIDTH-1){1'b0}}};  // 64-bit negative max
//            end
            
//            // REM: Remainder is 0
//            3'b110: result <= {WIDTH{1'b0}}; 
            
//            default: result <= {WIDTH{1'b0}};
//        endcase
//    end
//end
//           endcase
//        end
//      end
//endmodule
//                    if(start) begin 
//                    if(is_word)
//                    begin
//                        count<= 7'd32;
//                        done <= 1'b0;
//                        state<= CALC;
//                        sign_dividend<=rs1_data[31];
//                        sign_divisor <=rs2_data[31];
//                        case(op_sel)
//                        3'b000:
//                    end    
//                    else begin
//                        count<= 7'd64;
//                        done <= 1'b0;
//                        state<= CALC;
//                        sign_dividend<=rs1_data[63];
//                        sign_divisor <=rs2_data[63];
//                    end
                                       