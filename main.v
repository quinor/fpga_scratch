`timescale 1ns / 1ps


module main(
    input hclk,
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    output Vsync,
    output Hsync,
    input btnC,
    input btnU,
    input btnL,
    input btnR,
    input btnD,
    output [15:0] led
    );

wire feedback, clk, clk_4;

PLLE2_BASE #(
    .CLKFBOUT_MULT(8), // Multiply value for all CLKOUT, (2-64)
    .CLKIN1_PERIOD(10.0), // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
    .CLKOUT0_DIVIDE(8),
    .CLKOUT1_DIVIDE(32),
    .DIVCLK_DIVIDE(1),
    .STARTUP_WAIT("TRUE") // Delay DONE until PLL Locks, ("TRUE"/"FALSE")
) PLLE2_BASE_inst (
    .CLKOUT0(clk),
    .CLKOUT1(clk_4),
    .CLKFBOUT(feedback), // 1-bit output: Feedback clock
    .CLKIN1(hclk),
    .CLKFBIN(feedback) // 1-bit input: Feedback clock
);

wire display_ready;
reg [3:0] display_cmd;

display display (
    hclk, clk,
    vgaRed, vgaGreen, vgaBlue,
    Vsync, Hsync,
    display_cmd, {32'd0, 32'd134159}, display_ready,
    led
    );

reg [7:0] v_pos, h_pos;


wire btnC_pulse, btnU_pulse, btnL_pulse, btnR_pulse, btnD_pulse;
denoise btnC_denoise (clk, btnC, btnC_pulse);
denoise btnU_denoise (clk, btnU, btnU_pulse);
denoise btnL_denoise (clk, btnL, btnL_pulse);
denoise btnR_denoise (clk, btnR, btnR_pulse);
denoise btnD_denoise (clk, btnD, btnD_pulse);

always @(posedge clk) begin
    display_cmd <= 4'h0;
    if (display_ready) begin
        if (btnC_pulse)
            display_cmd <= 4'h1;
        else if (btnU_pulse)
            display_cmd <= 4'h2;
    end
end


// reg [31:0] cnt;
// always @(posedge base_clk) begin
//     cnt <= cnt + 1;
//     if (h_pos == 160-1) begin
//         h_pos <= 0;
//         if (v_pos == 45-1)
//             v_pos <= 0;
//         else
//             v_pos <= v_pos + 1;
//     end else
//         h_pos <= h_pos + 1;
// end


// assign write_addr = h_pos + v_pos * 13'd160;
// assign write_enable = 1'b1;
// assign write_value[19:0] = {12'h0, h_pos};

// wire [7:0] h, s, v;

// assign h = ((h_pos * 11'd13) >> 3) + cnt[27:20];
// assign s = v_pos * 8'd5;
// assign v = 255;

// hsv_to_rgb(base_clk, h, s, v, write_value_f[31:20]); // background

// delay #(.BITS(13), .DELAY(2)) (base_clk, write_addr_f, write_addr);
// delay #(.BITS(20), .DELAY(2)) (base_clk, write_value_f[19:0], write_value[19:0]);
// delay #(.BITS(1), .DELAY(2)) (base_clk, write_enable_f, write_enable);

endmodule
