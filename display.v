`timescale 1ns / 1ps

//commands:
// 4'h0 - NOP
// 4'h1 - SCROLL 64'd0
// 4'h2 - NUMBER {32'd0, number}

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
    output ready,
    output [15:0] led
    );

(* ASYNC_REG = "TRUE" *) reg [5:0] offset;

reg [12:0] write_addr;
reg [31:0] write_value;
reg write_enable;

vga vga(
    hclk,
    vgaRed, vgaGreen, vgaBlue,
    Vsync, Hsync,
    clk, write_addr, write_value, write_enable,
    offset
);


reg dabbler_enable;
wire [39:0] bcd;
wire [3:0] bcd_digits[9:0];
wire sign;
wire dabbler_ready;


bin_to_bcd dabbler(
    clk,
    dabbler_enable, data[31:0],
    bcd, sign, dabbler_ready
);

genvar i;
generate
    for (i=0; i<10; i = i+1) begin: bcd_to_digits
        assign bcd_digits[i] = bcd[i*4 + 3 : i*4];
    end
endgenerate

assign led = {bcd_digits[3], bcd_digits[2], bcd_digits[1], bcd_digits[0]};

localparam UNDEF        = 16'bxxxxxxxxxxxxxxxx;
localparam READY        = 16'b1 << 0;
localparam CLEAR_LINE   = 16'b1 << 1;
localparam NUMBER_WAIT  = 16'b1 << 2;
localparam NUMBER_WRITE = 16'b1 << 3;

reg [15:0] state = READY;
reg [15:0] countdown;


// all of the commands that run for >1 cycle should be here
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
                4'h2: begin     // NUMBER
                    dabbler_enable <= 1;
                    state <= NUMBER_WAIT;
                end
                default:    state <= READY;
            endcase

        CLEAR_LINE: begin
            if (countdown == 16'd0) state <= READY;
            else                    state <= CLEAR_LINE;

            write_addr <= (offset == 6'd0 ? 6'd44 : (offset - 6'd1)) * 13'd160 + countdown;
            write_value <= 32'd0;
            write_enable <= 1'b1;
        end

        NUMBER_WAIT:
            if (dabbler_ready) begin
                write_addr <= (offset == 6'd0 ? 6'd44 : (offset - 6'd1)) * 13'd160 + 0;
                write_value <= {12'hfff, 12'd0, sign ? 8'd45 : 8'd32};
                write_enable <= 1'b1;
                countdown <= 9;
                state <= NUMBER_WRITE;
            end else
                state <= NUMBER_WAIT;

        NUMBER_WRITE: begin
            if (countdown == 16'd0) state <= READY;
            else                    state <= NUMBER_WRITE;

            write_addr <= (offset == 6'd0 ? 6'd44 : (offset - 6'd1)) * 13'd160 + 1 + countdown;
            write_value <= {12'hfff, 12'd0, (8'd48 + bcd_digits[countdown[3:0]])};
            write_enable <= 1'b1;
        end

        default: state <= UNDEF; // unreachable
    endcase
end

endmodule
