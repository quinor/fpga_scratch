`timescale 1ns / 1ps


module fma (
    output signed [33:0] fma,
    input signed [33:0] a,
    input signed [33:0] b,
    input signed [33:0] c
    );

wire [64:0] temp;
reg [33:0] fma_r;
assign temp = b * c;
assign fma = a + temp[64:31];

endmodule


module division (
    input clk,
    input signed [31:0] sa,
    input signed [31:0] sb,
    output signed [31:0] q,
    output signed [31:0] r
    ); // delay 5

// assuming b != 0 !!!

reg [31:0] a, b;

always @(posedge clk)
    {a, b} <= sb >= 0 ? {sa, sb} : {-sa, -sb};


wire [31:0] bee[5:0];
wire [31:0] bf, nbf;
wire [4:0] shift;

assign bee[0] = b;
assign bf = bee[5];
assign nbf = -bf;

genvar i, j;
generate
    for (i=0; i<5; i=i+1) begin: gen_norm
        localparam j = 1 << (4-i);
        assign bee[i+1] = bee[i][31:32-j] ? bee[i] : bee[i] << j;
        assign shift[4-i] = (bee[i][31:32-j] == 0);
    end
endgenerate

localparam [33:0] lut [0:255] = {
    34'h100000000,
    34'hff00ff00,
    34'hfe03f80f,
    34'hfd08e550,
    34'hfc0fc0fc,
    34'hfb188565,
    34'hfa232cf2,
    34'hf92fb221,
    34'hf83e0f83,
    34'hf74e3fc2,
    34'hf6603d98,
    34'hf57403d5,
    34'hf4898d5f,
    34'hf3a0d52c,
    34'hf2b9d648,
    34'hf1d48bce,
    34'hf0f0f0f0,
    34'hf00f00f0,
    34'hef2eb71f,
    34'hee500ee5,
    34'hed7303b5,
    34'hec979118,
    34'hebbdb2a5,
    34'heae56403,
    34'hea0ea0ea,
    34'he939651f,
    34'he865ac7b,
    34'he79372e2,
    34'he6c2b448,
    34'he5f36cb0,
    34'he525982a,
    34'he45932d7,
    34'he38e38e3,
    34'he2c4a688,
    34'he1fc780e,
    34'he135a9c9,
    34'he070381c,
    34'hdfac1f74,
    34'hdee95c4c,
    34'hde27eb2c,
    34'hdd67c8a6,
    34'hdca8f158,
    34'hdbeb61ee,
    34'hdb2f171d,
    34'hda740da7,
    34'hd9ba4256,
    34'hd901b203,
    34'hd84a598e,
    34'hd79435e5,
    34'hd6df43fc,
    34'hd62b80d6,
    34'hd578e97c,
    34'hd4c77b03,
    34'hd4173289,
    34'hd3680d36,
    34'hd2ba083b,
    34'hd20d20d2,
    34'hd161543e,
    34'hd0b69fcb,
    34'hd00d00d0,
    34'hcf6474a8,
    34'hcebcf8bb,
    34'hce168a77,
    34'hcd712752,
    34'hcccccccc,
    34'hcc29786c,
    34'hcb8727c0,
    34'hcae5d85f,
    34'hca4587e6,
    34'hc9a633fc,
    34'hc907da4e,
    34'hc86a7890,
    34'hc7ce0c7c,
    34'hc73293d7,
    34'hc6980c69,
    34'hc5fe7403,
    34'hc565c87b,
    34'hc4ce07b0,
    34'hc4372f85,
    34'hc3a13de6,
    34'hc30c30c3,
    34'hc2780613,
    34'hc1e4bbd5,
    34'hc152500c,
    34'hc0c0c0c0,
    34'hc0300c03,
    34'hbfa02fe8,
    34'hbf112a8a,
    34'hbe82fa0b,
    34'hbdf59c91,
    34'hbd691047,
    34'hbcdd535d,
    34'hbc52640b,
    34'hbbc8408c,
    34'hbb3ee721,
    34'hbab65610,
    34'hba2e8ba2,
    34'hb9a7862a,
    34'hb92143fa,
    34'hb89bc36c,
    34'hb81702e0,
    34'hb79300b7,
    34'hb70fbb5a,
    34'hb68d3134,
    34'hb60b60b6,
    34'hb58a4855,
    34'hb509e68a,
    34'hb48a39d4,
    34'hb40b40b4,
    34'hb38cf9b0,
    34'hb30f6352,
    34'hb2927c29,
    34'hb21642c8,
    34'hb19ab5c4,
    34'hb11fd3b8,
    34'hb0a59b41,
    34'hb02c0b02,
    34'hafb321a1,
    34'haf3addc6,
    34'haec33e1f,
    34'hae4c415c,
    34'hadd5e632,
    34'had602b58,
    34'haceb0f89,
    34'hac769184,
    34'hac02b00a,
    34'hab8f69e2,
    34'hab1cbdd3,
    34'haaaaaaaa,
    34'haa392f35,
    34'ha9c84a47,
    34'ha957fab5,
    34'ha8e83f57,
    34'ha8791708,
    34'ha80a80a8,
    34'ha79c7b16,
    34'ha72f0539,
    34'ha6c21df6,
    34'ha655c439,
    34'ha5e9f6ed,
    34'ha57eb502,
    34'ha513fd6b,
    34'ha4a9cf1d,
    34'ha4402910,
    34'ha3d70a3d,
    34'ha36e71a2,
    34'ha3065e3f,
    34'ha29ecf16,
    34'ha237c32b,
    34'ha1d13985,
    34'ha16b312e,
    34'ha105a932,
    34'ha0a0a0a0,
    34'ha03c1688,
    34'h9fd809fd,
    34'h9f747a15,
    34'h9f1165e7,
    34'h9eaecc8d,
    34'h9e4cad23,
    34'h9deb06c9,
    34'h9d89d89d,
    34'h9d2921c3,
    34'h9cc8e160,
    34'h9c69169b,
    34'h9c09c09c,
    34'h9baade8e,
    34'h9b4c6f9e,
    34'h9aee72fc,
    34'h9a90e7d9,
    34'h9a33cd67,
    34'h99d722da,
    34'h997ae76b,
    34'h991f1a51,
    34'h98c3bac7,
    34'h9868c809,
    34'h980e4156,
    34'h97b425ed,
    34'h975a750f,
    34'h97012e02,
    34'h96a85009,
    34'h964fda6c,
    34'h95f7cc72,
    34'h95a02568,
    34'h9548e497,
    34'h94f2094f,
    34'h949b92dd,
    34'h94458094,
    34'h93efd1c5,
    34'h939a85c4,
    34'h93459be6,
    34'h92f11384,
    34'h929cebf4,
    34'h92492492,
    34'h91f5bcb8,
    34'h91a2b3c4,
    34'h91500915,
    34'h90fdbc09,
    34'h90abcc02,
    34'h905a3863,
    34'h90090090,
    34'h8fb823ee,
    34'h8f67a1e3,
    34'h8f1779d9,
    34'h8ec7ab39,
    34'h8e78356d,
    34'h8e2917e0,
    34'h8dda5202,
    34'h8d8be33f,
    34'h8d3dcb08,
    34'h8cf008cf,
    34'h8ca29c04,
    34'h8c55841c,
    34'h8c08c08c,
    34'h8bbc50c8,
    34'h8b70344a,
    34'h8b246a87,
    34'h8ad8f2fb,
    34'h8a8dcd1f,
    34'h8a42f870,
    34'h89f87469,
    34'h89ae4089,
    34'h89645c4f,
    34'h891ac73a,
    34'h88d180cd,
    34'h88888888,
    34'h883fddf0,
    34'h87f78087,
    34'h87af6fd5,
    34'h8767ab5f,
    34'h872032ac,
    34'h86d90544,
    34'h869222b1,
    34'h864b8a7d,
    34'h86053c34,
    34'h85bf3761,
    34'h85797b91,
    34'h85340853,
    34'h84eedd35,
    34'h84a9f9c8,
    34'h84655d9b,
    34'h84210842,
    34'h83dcf94d,
    34'h83993052,
    34'h8355ace3,
    34'h83126e97,
    34'h82cf7503,
    34'h828cbfbe,
    34'h824a4e60,
    34'h82082082,
    34'h81c635bc,
    34'h81848da8,
    34'h814327e3,
    34'h81020408,
    34'h80c121b2,
    34'h80808080,
    34'h80402010
};

reg [33:0] x[3:0];

assign x[0] = lut[bf[30:23]]; // bf has got the first bit set to 1 anyway, so the lut is 9 upper bits

wire [33:0] tmp[2:0];
wire [33:0] xo[2:0];

genvar k;
generate
    for (k=0; k<3; k=k+1) begin: gen_newtonrhapson
        fma(tmp[k], 1<<31, nbf, x[k]);
        fma(xo[k], x[k], x[k], tmp[k]);
        always @(posedge clk)
            x[k+1] <= xo[k];
    end
endgenerate

wire signed [33:0] qt;

fma(qt, 0, a, x[3]);


reg signed [31:0] q_r, r_r;

always @(posedge clk) begin
    q_r <= qt >>> (31-shift);
    r_r <= a - b * q;
end

assign q = q_r;
assign r = r_r;
endmodule
