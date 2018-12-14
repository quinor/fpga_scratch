`timescale 1ns / 1ps


//sends 1-tick pulse on posedge (with some delay)
module denoise(
    input clk,
    input raw_signal,
    output reg single_pulse
    );

reg [31:0] cnt;

reg t0, t1, signal;

always @(posedge clk) begin
    t0 <= raw_signal;
    t1 <= t0;
    signal <= t1;
    if (signal) begin
        if (cnt == 32'd1<<17)
            single_pulse <= 1;
        else
            single_pulse <= 0;
        cnt <= cnt + 1;
    end else begin
        cnt <= 0;
        single_pulse <= 0;
    end
end

endmodule
