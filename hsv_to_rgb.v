`timescale 1ns / 1ps


module hsv_to_rgb (
    input clk,
    input [7:0] hi,
    input [7:0] si,
    input [7:0] vi,
    output [11:0] rgb // delayed 2
    );

reg [7:0] h, s, v;

delay #(.BITS(8),  .DELAY(1)) (clk, h, hi);
delay #(.BITS(8),  .DELAY(1)) (clk, s, si);
delay #(.BITS(8),  .DELAY(1)) (clk, v, vi);

reg [7:0] r1, g1, b1;

wire [7:0] r, g, b;
wire [7:0] m, x, c, xm, c_imm;

wire [10:0] lh, lh_imm;


assign c_imm = ({8'h0, v} * s) >> 8;
assign lh_imm = 6 * h;

delay #(.BITS(8),  .DELAY(1)) (clk, c, c_imm);
delay #(.BITS(8),  .DELAY(1)) (clk, m, v - c_imm);
delay #(.BITS(11), .DELAY(1)) (clk, lh, lh_imm);
delay #(.BITS(8),  .DELAY(1)) (clk, xm, (lh_imm & 9'h100 ? ~(lh_imm[7:0]) : lh_imm[7:0]));

assign x = ({8'h0, c} * xm) >> 8;

always @(c, x, lh) begin
    case(lh >> 8)
        3'b000: {r1, g1, b1} <= {c, x, 8'h0};
        3'b001: {r1, g1, b1} <= {x, c, 8'h0};
        3'b010: {r1, g1, b1} <= {8'h0, c, x};
        3'b011: {r1, g1, b1} <= {8'h0, x, c};
        3'b100: {r1, g1, b1} <= {x, 8'h0, c};
        3'b101: {r1, g1, b1} <= {c, 8'h0, x};
        default: {r1, g1, b1} <= {8'h0, 8'h0, 8'h0}; // never
    endcase
end

assign r = r1 + m;
assign g = g1 + m;
assign b = b1 + m;

assign rgb = {r[7:4], g[7:4], b[7:4]};

endmodule
