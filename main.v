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
    input [15:0] sw,
    output [15:0] led
    );

wire feedback, clk, clk_4;

PLLE2_BASE #(
    .CLKFBOUT_MULT(8), // Multiply value for all CLKOUT, (2-64)
    .CLKIN1_PERIOD(10.0), // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
    .CLKOUT0_DIVIDE(5),
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
wire [3:0] display_cmd;
wire [63:0] display_param;

display display (
    hclk, clk,
    vgaRed, vgaGreen, vgaBlue,
    Vsync, Hsync,
    display_cmd, display_param, display_ready
    );

reg [31:0] calc_instr_queue[3:0];
reg [1:0] calc_write_head;
wire [1:0] calc_read_head;
wire [8:0] stack_height;
reg instr_ready;

wire [15:0] pc;

calc calc (
    clk,
    display_cmd, display_param, display_ready,
    calc_instr_queue,
    calc_write_head,
    calc_read_head,
    stack_height,
    pc
);

// assign led[8:0] = stack_height;
assign led = pc;

wire btnC_pulse, btnU_pulse, btnL_pulse, btnR_pulse, btnD_pulse;
denoise btnC_denoise (clk, btnC, btnC_pulse);
denoise btnU_denoise (clk, btnU, btnU_pulse);
denoise btnL_denoise (clk, btnL, btnL_pulse);
denoise btnR_denoise (clk, btnR, btnR_pulse);
denoise btnD_denoise (clk, btnD, btnD_pulse);


localparam I_ADD    = {4'h1};
localparam I_SUB    = {4'h2};
localparam I_MUL    = {4'h3};
localparam I_DIV    = {4'h4};
localparam I_MOD    = {4'h5};
localparam I_NOP    = {32'd0};
localparam I_PUSH   = {4'b1000, 24'd0};
localparam I_POP    = {4'b1001, 24'd0};
localparam I_SHIFT  = {4'b1010, 24'd0};
localparam I_SETL   = {4'b1011};
localparam I_PRINT  = {4'b1100, 24'd0};
localparam I_CLEAR  = {4'b1101, 28'd0};


//  instrs:
//  ADD/SUB/MUL/DIV/MOD:
//      pop 4'h0
//      clear
//      pop 4'h1
//      clear
//      <arithmetic> 4'h2 = 4'h1 # 4'h0
//      print 4'h2
//      push 4'h2
//  POP
//      pop 4'h0
//      clear
//  DUP
//      pop 4'h0
//      push 4'h0
//      print 4'h0
//      push 4'h0
//  SWAP
//      pop 4'h0
//      clear
//      pop 4'h1
//      clear
//      print 4'h0
//      push 4'h0
//      print 4'h1
//      push 4'h1
//  PUSHL
//      sub 4'h0 = 4'h0 - 4'h0
//      setl 4'h0 sw
//      print 4'h0
//      push 4'h0
//  SHIFT
//      pop 4'h0
//      clear
//      shift 4'h0
//      setl 4'h0 sw
//      print 4'h0
//      push 4'h0


// L: PUSHL
// R: SHIFT
// C: ARITHMETIC: ADD/SUB/MUL/DIV/MOD/POP
// U: DUP
// D: SWAP


localparam UNDEF            = 16'bxxxxxxxxxxxxxxxx;
localparam READY            = 16'b1 << 0;
localparam SHIFT_1          = 16'b1 << 1;
localparam SWAP_1           = 16'b1 << 2;
localparam ARITHMETIC_1     = 16'b1 << 3;

reg [15:0] state = READY;
reg [127:0] rollbuf;
reg [3:0] arithmetic_instr;
reg is_arithmetic;

always @(posedge clk) begin
    if (rollbuf) begin
        if (calc_write_head + 2'b1 != calc_read_head) begin
            calc_write_head <= calc_write_head + 1;
            calc_instr_queue[calc_write_head] <= rollbuf[31:0];
            rollbuf <= rollbuf >> 32;
        end
    end else begin
        case(state)
            READY: begin
                case(1)
                    btnU_pulse: begin // DUP
                        if (stack_height > 0 && stack_height < 512)
                            rollbuf <= {
                                I_PUSH, 4'h0,
                                I_PRINT, 4'h0,
                                I_PUSH, 4'h0,
                                I_POP, 4'h0
                            };
                        state <= READY;
                    end
                    btnL_pulse: begin // PUSHL
                        if (stack_height < 512)
                            rollbuf <= {
                                I_PUSH, 4'h0,
                                I_PRINT, 4'h0,
                                I_SETL, sw, 8'd0, 4'h0,
                                I_SUB, 16'd0, 4'h0, 4'h0, 4'h0
                            };
                        state <= READY;
                    end
                    btnC_pulse: begin // ARITHMETIC+POP
                        is_arithmetic = 1;
                        case(sw[15:10])
                        6'b100000: arithmetic_instr <= I_ADD;
                        6'b010000: arithmetic_instr <= I_SUB;
                        6'b001000: arithmetic_instr <= I_MUL;
                        6'b000100: arithmetic_instr <= I_DIV;
                        6'b000010: arithmetic_instr <= I_MOD;
                        default: begin
                            arithmetic_instr <= 4'h0;
                            is_arithmetic = 0;
                        end
                        endcase
                        if (is_arithmetic) begin
                            if (stack_height > 1) begin
                                rollbuf <= {
                                    I_CLEAR,
                                    I_POP, 4'h1,
                                    I_CLEAR,
                                    I_POP, 4'h0
                                };
                                state <= ARITHMETIC_1;
                            end
                            else state <= READY;
                        end else begin
                            if (sw[15:10] == 6'b000001 && stack_height > 0)
                                rollbuf <= {
                                    I_NOP,
                                    I_NOP,
                                    I_CLEAR,
                                    I_POP, 4'h0
                                };
                            else
                                rollbuf <= 0;
                            state <= READY;
                        end
                    end
                    btnR_pulse: begin // SHIFT
                        if (stack_height > 0) begin
                            rollbuf <= {
                                I_SETL, sw, 8'd0, 4'h0,
                                I_SHIFT, 4'h0,
                                I_CLEAR,
                                I_POP, 4'h0
                            };
                            state <= SHIFT_1;
                        end else
                            state <= READY;
                    end
                    btnD_pulse: begin // SWAP
                        if (stack_height > 1) begin
                            rollbuf <= {
                                I_CLEAR,
                                I_POP, 4'h1,
                                I_CLEAR,
                                I_POP, 4'h0
                            };
                            state <= SWAP_1;
                        end else
                            state <= READY;
                    end
                endcase
            end
            SHIFT_1: begin
                rollbuf <= {
                    I_NOP,
                    I_NOP,
                    I_PUSH, 4'h0,
                    I_PRINT, 4'h0
                };
                state <= READY;
            end
            SWAP_1: begin
                rollbuf <= {
                    I_PUSH, 4'h1,
                    I_PRINT, 4'h1,
                    I_PUSH, 4'h0,
                    I_PRINT, 4'h0
                };
                state <= READY;
            end
            ARITHMETIC_1: begin
                rollbuf <= {
                    I_NOP,
                    I_PUSH, 4'h2,
                    I_PRINT, 4'h2,
                    arithmetic_instr, 4'h0, 4'h1, 4'h2
                };
                state <= READY;
            end
            default:    state <= UNDEF;
        endcase
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
