`timescale 1ns / 1ps


module calc(
    input clk,
    output reg [3:0] display_cmd,
    output reg [47:0] display_param,
    input display_ready,
    input [31:0] instr_queue[3:0],
    input [1:0] queue_write_head,
    output reg [1:0] queue_read_head,
    output reg [8:0] stack_height,
    output reg [15:0] pc
    );

// ALWAYS write to a, read from others
// 0000 28                     NOP
// 0001 16'd0 cccc bbbb aaaa   add a = b + c
// 0010 16'd0 cccc bbbb aaaa   sub a = b - c
// 0011 16'd0 cccc bbbb aaaa   mul a = b * c
// 0100 16'd0 cccc bbbb aaaa   div a = b / c
// 0101 16'd0 cccc bbbb aaaa   mod a = b % c

// 1000 24'd0           aaaa   push a
// 1001 24'd0           aaaa   pop a
// 1010 24'd0           aaaa   shift a
// 1011 16'i  8'd0      aaaa   setl a i
// 1100 24'd0           aaaa   print a
// 1101 28'd0                  clear


reg write_enable, read_enable;
reg [31:0] write_value;
wire [31:0] read_value;
reg [8:0] read_addr, write_addr;

BRAM_SDP_MACRO #(
    .BRAM_SIZE("18Kb"), // Target BRAM, "18Kb" or "36Kb"
    .DEVICE("7SERIES"), // Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6", "7SERIES"
    .WRITE_WIDTH(32), // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
    .READ_WIDTH(32), // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
    .WRITE_MODE("WRITE_FIRST") // Specify "READ_FIRST" for same clock or synchronous clocks
// Specify "WRITE_FIRST for asynchronous clocks on ports
) block1 (
    .DO(read_value), // Output read data port, width defined by READ_WIDTH parameter
    .RDADDR(read_addr), // Input read address, width defined by read port depth
    .RDCLK(clk), // 1-bit input read clock
    .RDEN(read_enable), // 1-bit input read port enable

    .RST(0), // 1-bit input reset

    .DI(write_value), // Input write data port, width defined by WRITE_WIDTH parameter
    .WE(4'hf), // Input write enable, width defined by write port depth
    .WRADDR(write_addr), // Input write address, width defined by write port depth
    .WRCLK(clk), // 1-bit input write clock
    .WREN(write_enable), // 1-bit input write port enable
    .REGCE(0)
);


localparam UNDEF            = 16'bxxxxxxxxxxxxxxxx;
localparam READY            = 16'b1 << 0;
localparam DISPLAY_PRINT    = 16'b1 << 1;
localparam DISPLAY_CLEAR    = 16'b1 << 2;
localparam POP_WAIT         = 16'b1 << 3;
localparam POP              = 16'b1 << 4;
localparam MUL_1            = 16'b1 << 5;
localparam MUL_2            = 16'b1 << 6;

reg [31:0] registers [3:0];
reg [15:0] state = READY;
reg [7:0] px, py;

reg [31:0] instr;
wire [3:0] opcode, ra, rb, rc;
wire [15:0] data;
assign {opcode, data, rc, rb, ra} = instr;

wire [31:0] av, bv, cv;
assign av = registers[ra];
assign bv = registers[rb];
assign cv = registers[rc];

reg next_ready;

reg [31:0] mul_in1_t, mul_in2_t, mul_out_t;

always @(posedge clk) begin
    display_cmd <= 4'h0;
    read_enable <= 0;
    write_enable <= 0;
    next_ready = 0;
    case(state)
        READY:
            case(opcode)
                4'b0001: begin     // ADD
                    next_ready = 1;
                    registers[ra] <= registers[rb] + registers[rc];
                end
                4'b0010: begin     // SUB
                    next_ready = 1;
                    registers[ra] <= registers[rb] - registers[rc];
                end
                4'b0011: begin     // MUL
                    state <= MUL_1;
                    mul_in1_t <= bv;
                    mul_in2_t <= cv;
                end
                4'b0100: begin     // DIV
                    next_ready = 1;
                end
                4'b0101: begin     // MOD
                    next_ready = 1;
                end
                4'b1000: begin     // PUSH
                    if (stack_height != 9'd511) begin
                        stack_height <= stack_height + 1;
                        if (py == 44) begin
                            py <= 0;
                            px <= px + 1;
                        end else
                            py <= py + 1;
                        write_enable <= 1;
                        write_addr <= stack_height;
                        write_value <= av;
                    end
                    next_ready = 1;
                end
                4'b1001: begin     // POP
                    if (stack_height != 0) begin
                        stack_height <= stack_height - 1;
                        if (py == 0) begin
                            py <= 44;
                            px <= px - 1;
                        end else
                            py <= py - 1;
                        read_enable <= 1;
                        read_addr <= stack_height - 1;
                        state <= POP_WAIT;
                    end else
                        next_ready = 1;
                end
                4'b1010: begin     // SHIFT
                    next_ready = 1;
                    registers[ra] <= (av << 16);
                end
                4'b1011: begin     // SETL
                    next_ready = 1;
                    registers[ra] <= {av[31:16], data};
                end
                4'b1100: begin     // PRINT
                    state <= DISPLAY_PRINT;
                end
                4'b1101: begin     // CLEAR
                    state <= DISPLAY_CLEAR;
                end
                default:    next_ready = 1;
            endcase

        MUL_1: begin
            state <= MUL_2;
            mul_out_t <= mul_in1_t * mul_in2_t;
        end

        MUL_2: begin
            next_ready = 1;
            registers[ra] <= mul_out_t;
        end

        DISPLAY_PRINT:
            if (display_ready) begin
                next_ready = 1;
                display_param <= {px, py, av};
                display_cmd <= 4'h3;
            end else
                state <= DISPLAY_PRINT;

        DISPLAY_CLEAR:
            if (display_ready) begin
                next_ready = 1;
                display_param <= {px, py, 32'd0};
                display_cmd <= 4'h2;
            end else
                state <= DISPLAY_CLEAR;

        POP_WAIT:
            state <= POP;

        POP: begin
            next_ready = 1;
            registers[ra] <= read_value;
        end

        default: state <= UNDEF; // unreachable
    endcase

    if (next_ready) begin
        state <= READY;
        if (queue_read_head != queue_write_head) begin
            pc <= pc + 1;
            instr <= instr_queue[queue_read_head];
            queue_read_head <= queue_read_head + 1;
        end else
            instr <= 32'd0;
    end
end

endmodule
