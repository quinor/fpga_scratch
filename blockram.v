`timescale 1ns / 1ps


module blockram #(
    parameter WIDTH=0,
    parameter DEPTH=1
) (
    input rclk,
    input [11+DEPTH:0] raddr,
    output [(8 << WIDTH)-1:0] rval, // delayed by 1

    input wclk,
    input [11+DEPTH:0] waddr,
    input [(8 << WIDTH)-1:0] wval,
    input wenable
    );

reg [WIDTH+DEPTH-1:0] r_switch; // delayed by 1
wire [WIDTH+DEPTH-1:0] w_switch;


always @(posedge rclk) begin
    r_switch <= raddr[11+DEPTH:12-WIDTH];
end

assign w_switch = waddr[11+DEPTH:12-WIDTH];

wire [(8 << WIDTH)-1:0] rvals[(1<<(WIDTH+DEPTH))-1:0];
assign rval = rvals[r_switch];

genvar i;

generate
    for (i = 0; i < (1 << WIDTH+DEPTH); i = i+1) begin: gen_br
        BRAM_SDP_MACRO #(
            .BRAM_SIZE("36Kb"), // Target BRAM, "18Kb" or "36Kb"
            .DEVICE("7SERIES"), // Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6", "7SERIES"
            .WRITE_WIDTH(8<<WIDTH), // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
            .READ_WIDTH(8<<WIDTH), // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
            .WRITE_MODE("WRITE_FIRST") // Specify "READ_FIRST" for same clock or synchronous clocks
        // Specify "WRITE_FIRST for asynchronous clocks on ports
        ) block0 (
            .DO(rvals[i]), // Output read data port, width defined by READ_WIDTH parameter
            .RDADDR(raddr[11-WIDTH:0]), // Input read address, width defined by read port depth
            .RDCLK(rclk), // 1-bit input read clock
            .RDEN(1), // 1-bit input read port enable

            .RST(0), // 1-bit input reset

            .DI(wval), // Input write data port, width defined by WRITE_WIDTH parameter
            .WE((1<<(1<<WIDTH))-1), // Input write enable, width defined by write port depth
            .WRADDR(waddr[11-WIDTH:0]), // Input write address, width defined by write port depth
            .WRCLK(wclk), // 1-bit input write clock
            .WREN((w_switch == i) & wenable), // 1-bit input write port enable
            .REGCE(0)
        );
    end
endgenerate


endmodule
