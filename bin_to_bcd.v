`timescale 1ns / 1ps

//commands:
// 4'h0 - NOP
// 4'h1 - SCROLL
// 4'h2 - NUMBER

module bin_to_bcd(
    input clk,
    input start,
    input signed [31:0] bin,
    output reg [39:0] bcd,
    output reg sign,
    output ready
    );


localparam UNDEF        = 2'bxx;
localparam READY        = 2'b1 << 0;
localparam DABBLE       = 2'b1 << 1;

reg [1:0] state = READY;
reg [7:0] countdown;
reg [31:0] num;

wire [39:0] bcd_plus3;
genvar i;
generate
    for (i=0; i<10; i=i+1) begin: gen_plus3
        assign bcd_plus3[4*i+3:4*i] = bcd[4*i+3:4*i] >= 5 ? bcd[4*i+3:4*i] + 3 : bcd[4*i+3:4*i];
    end
endgenerate

assign ready = (state == READY && !start);

always @(posedge clk) begin
    if (countdown != 0)
        countdown <= countdown - 1;
    case(state)
        READY:
            if(start) begin
                if (bin < 0) begin
                    num <= -bin;
                    sign <= 1;
                end else begin
                    num <= bin;
                    sign <= 0;
                end
                bcd <= 0;
                state <= DABBLE;
                countdown <= 31;
            end else
                state <= READY;
        DABBLE: begin
            bcd <= {bcd_plus3[38:0], num[countdown]};
            if (countdown != 0)
                state <= DABBLE;
            else
                state <= READY;
        end
        default: state <= UNDEF;
    endcase
end

endmodule
