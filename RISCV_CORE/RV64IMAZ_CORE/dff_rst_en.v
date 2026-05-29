`timescale 1ns/1ps

module dff_rst_en #(
    parameter integer WIDTH = 1
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire [WIDTH-1:0] din,
    output reg  [WIDTH-1:0] dout
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= {WIDTH{1'b0}};
        end else if (en) begin
            dout <= din;
        end
    end

endmodule