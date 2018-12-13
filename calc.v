`timescale 1ns / 1ps


module calc(
    input clk,
    output reg [3:0] display_cmd,
    output reg [63:0] display_param,
    input display_ready,
    input [31:0] instr,
    output ready
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
    .WREN(write_enable) // 1-bit input write port enable
);


localparam UNDEF            = 16'bxxxxxxxxxxxxxxxx;
localparam READY            = 16'b1 << 0;
localparam DISPLAY_PRINT    = 16'b1 << 1;
localparam DISPLAY_CLEAR    = 16'b1 << 2;
localparam POP              = 16'b1 << 3;

wire [3:0] opcode, ra, rb, rc;
wire [15:0] data;

assign {opcode, data, rc, rb, ra} = instr;
wire [31:0] av, bv, cv;
assign av = registers[ra];
assign bv = registers[rb];
assign cv = registers[rc];

reg [31:0] registers [3:0];
reg [8:0] stack_height;

reg [15:0] state = READY;
reg [15:0] countdown;

assign ready = (state == READY && opcode == 4'h0);

always @(posedge clk) begin
    display_cmd <= 4'h0;
    read_enable <= 0;
    write_enable <= 0;
    if (countdown != 16'd0)
        countdown <= countdown - 1;
    case(state)
        READY:
            case(opcode)
                4'b0001: begin     // ADD
                    state <= READY;
                    registers[ra] <= bv + cv;
                end
                4'b0010: begin     // SUB
                    state <= READY;
                    registers[ra] <= bv - cv;
                end
                4'b0011: begin     // MUL
                    state <= READY;
                end
                4'b0100: begin     // DIV
                    state <= READY;
                end
                4'b0101: begin     // MOD
                    state <= READY;
                end
                4'b1000: begin     // PUSH
                    if (stack_height != 9'd511) begin
                        stack_height <= stack_height + 1;
                        write_enable <= 1;
                        write_addr <= stack_height;
                        write_value <= av;
                    end
                    state <= READY;
                end
                4'b1001: begin     // POP
                    if (stack_height != 0) begin
                        stack_height <= stack_height - 1;
                        read_enable <= 1;
                        read_addr <= stack_height - 1;
                        state <= POP;
                    end else
                        state <= READY;
                end
                4'b1010: begin     // SHIFT
                    state <= READY;
                    registers[ra] <= av << 16;
                end
                4'b1011: begin     // SETL
                    state <= READY;
                    registers[ra] <= {av[31:16], data};
                end
                4'b1100: begin     // PRINT
                    state <= DISPLAY_PRINT;
                end
                4'b1101: begin     // CLEAR
                    state <= DISPLAY_CLEAR;
                end
                default:    state <= READY;
            endcase

        DISPLAY_PRINT:
            if (display_ready) begin
                state <= READY;
                display_param <= {16'd0, 8'd0, stack_height[7:0], av};
                display_cmd <= 4'h3;
            end else
                state <= DISPLAY_PRINT;

        DISPLAY_CLEAR:
            if (display_ready) begin
                state <= READY;
                display_param <= {16'd0, 8'd0, stack_height[7:0], 32'd0};
                display_cmd <= 4'h2;
            end else
                state <= DISPLAY_CLEAR;

        POP: begin
            state <= READY;
            registers[ra] <= read_value;
        end

        default: state <= UNDEF; // unreachable
    endcase
end

endmodule
