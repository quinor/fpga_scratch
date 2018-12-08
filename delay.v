`timescale 1ns / 1ps


module delay #(
    parameter BITS = 1,
    parameter DELAY = 1
) (
    input clk,
    output [BITS-1:0] delayed_signal,
    input [BITS-1:0] signal
    );

reg [BITS-1:0] buffer[DELAY-1:0];

assign delayed_signal = buffer[DELAY-1];

always @(posedge clk) begin
    buffer[0] <= signal;
    for (int i = 0; i < DELAY-1; i = i + 1) begin
        buffer[i+1] <= buffer[i];
    end
end

endmodule
