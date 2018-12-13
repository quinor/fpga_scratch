`timescale 1ns / 1ps

//commands:
// 4'h0 - NOP
// 4'h1 - SCROLL 64'd0
// 4'h2 - POS CLEAR {16'd0, 8'x, 8'y, 32'd0}
// 4'h3 - NUMBER {16'd0, 8'x, 8'y, 32'num}

module display(
    input hclk,
    input clk,
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    output Vsync,
    output Hsync,
    input [3:0] cmd,
    input [63:0] data,
    output ready
    );

reg [5:0] offset = 0;

reg [7:0] write_posx;
reg [5:0] write_posy;
reg [31:0] write_value;
reg write_enable;

vga vga(
    hclk,
    vgaRed, vgaGreen, vgaBlue,
    Vsync, Hsync,
    clk, write_posx, write_posy, write_value, write_enable,
    offset
);


reg dabbler_enable;
wire [39:0] bcd;
wire [3:0] bcd_digits[9:0];
wire sign;
wire dabbler_ready;

wire [7:0] dx, dy;
wire [31:0] num;
wire [7:0] number_px;
wire [7:0] number_py;

assign {dx, dy, num} = data[47:0];

bin_to_bcd dabbler(
    clk,
    dabbler_enable, num,
    bcd, sign, dabbler_ready
);

genvar i;
generate
    for (i=0; i<10; i = i+1) begin: bcd_to_digits
        assign bcd_digits[i] = bcd[i*4 + 3 : i*4];
    end
endgenerate

localparam UNDEF        = 16'bxxxxxxxxxxxxxxxx;
localparam READY        = 16'b1 << 0;
// scroll
localparam CLEAR_LINE   = 16'b1 << 1;
// pos clearing
localparam POS_CLEAR    = 16'b1 << 2;
// number writing
localparam NUMBER_WAIT  = 16'b1 << 3;
localparam NUMBER_WRITE = 16'b1 << 4;
localparam NUMBER_SIGN  = 16'b1 << 5;

reg [15:0] state = READY;
reg [15:0] countdown;

simplemod #(.BITS(8), .MOD(160)) modx (number_px, dx*8'd12 + countdown);
simplemod #(.BITS(8), .MOD(45)) mody (number_py, dy + offset);


assign ready = (state == READY && cmd == 4'h0);

always @(posedge clk) begin
    write_enable <= 0;
    dabbler_enable <= 0;
    if (countdown != 16'd0)
        countdown <= countdown - 1;
    case(state)
        READY:
            case(cmd) // decoder, +1 cycle
                4'h0:           // NOP
                    state <= READY;
                4'h1: begin     // SCROLL
                    if (offset == 44)   offset <= 0;
                    else                offset <= offset + 1;
                    countdown <= 16'd159;
                    state <= CLEAR_LINE;
                end
                4'h2: begin     // POS CLEAR
                    countdown <= 16'd10;
                    state <= POS_CLEAR;
                end
                4'h3: begin     // NUMBER
                    dabbler_enable <= 1;
                    state <= NUMBER_WAIT;
                end
                default:    state <= READY;
            endcase

        CLEAR_LINE: begin
            if (countdown == 16'd0) state <= READY;
            else                    state <= CLEAR_LINE;

            write_posy <= (offset == 6'd0 ? 6'd44 : (offset - 6'd1));
            write_posx <= countdown;
            write_value <= 32'd0;
            write_enable <= 1'b1;
        end

        POS_CLEAR: begin
            if (countdown == 16'd0) state <= READY;
            else                    state <= POS_CLEAR;

            write_posy <= number_py;
            write_posx <= number_px;
            write_value <= 32'd0;
            write_enable <= 1'b1;
        end

        NUMBER_WAIT:
            if (dabbler_ready) begin
                countdown <= 10;
                state <= NUMBER_WRITE;
            end else
                state <= NUMBER_WAIT;

        NUMBER_WRITE: begin
            if (countdown == 16'd1 || bcd_digits[10-countdown[3:0]+1] == 0)
                state <= NUMBER_SIGN;
            else
                state <= NUMBER_WRITE;

            write_posy <= number_py;
            write_posx <= number_px;
            write_value <= {12'hfff, 12'd0, 8'd48 + bcd_digits[10-countdown[3:0]]};
            write_enable <= 1'b1;
        end

        NUMBER_SIGN: begin
            state <= READY;
            countdown <= 0;

            write_posy <= number_py;
            write_posx <= number_px;
            write_value <= {12'hfff, 12'd0, sign ? 8'd45 : 8'd32};
            write_enable <= 1'b1;
        end

        default: state <= UNDEF; // unreachable
    endcase
end

endmodule
