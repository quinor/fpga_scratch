`timescale 1ns / 1ps

module simplemod #(
    parameter BITS = 8,
    parameter MOD = 1
) (
    output reg [BITS-1:0] out,
    input [BITS-1:0] in
    );


wire [BITS-1:0] val;

always @(in) begin
    case(1)
        in >= 2*MOD: out <= in-2*MOD;
        in >= MOD: out <= in-MOD;
        default: out <= in;
    endcase
end

endmodule
