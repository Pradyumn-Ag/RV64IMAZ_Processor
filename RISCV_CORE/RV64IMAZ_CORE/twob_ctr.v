`timescale 1ns/1ps

module twob_ctr (
//    input  wire        clk,
//    input  wire        rst_n,
//    // Control signal
//    input  wire        strobe,
    // Input
    input  wire        ctr,
    input  wire [1:0]  crnt_stt,
    // Output
    output wire [1:0]  next_stt
);

 //   wire [1:0] din_i;

    assign next_stt[1] = (crnt_stt[1] &  crnt_stt[0]) |
                      ((crnt_stt[1] ^  crnt_stt[0]) & ctr);

    assign next_stt[0] = (crnt_stt[1] & ~crnt_stt[0]) |
                      ((crnt_stt[1] ^ ~crnt_stt[0]) & ctr);

//    dff_rst_en #(.WIDTH(2)) flop (
//        .clk   (clk),
//        .rst_n (rst_n),
//        .en    (strobe),
//        .din   (din_i),
//        .dout  (next_stt)
//    );

endmodule