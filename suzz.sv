`default_nettype none


module encoding(
    input bit clk, rst_b,
    input logic [3:0] pktType,
    input bit bstr,
    output bit bOut);


    //for crc5
    logic [4:0] in5, out5;

    always_comb begin
        in5[0] = out5[4]^bstr;
        in5[1] = out5[0];
        in5[2] = out5[1]^in5[0];
        in5[3] = out5[2];
        in5[4] = out5[3];
    end

    ff ff5_0(clk,rst_b,in5[0],out5[0]),
       ff5_1(clk,rst_b,in5[1],out5[1]),
       ff5_2(clk,rst_b,in5[2],out5[2]),
       ff5_3(clk,rst_b,in5[3],out5[3]),
       ff5_4(clk,rst_b,in5[4],out5[4]);

    //for crc16

    logic [15:0] in16, out16;
    
    always_comb begin
        in16[0] = out16[15]^bstr;
        in16[1] = out16[0];
        in16[2] = out16[1]^in16[0];
        in16[3] = out16[2];
        in16[4] = out16[3];
        in16[5] = out16[4];
        in16[6] = out16[5];
        in16[7] = out16[6];
        in16[8] = out16[7];
        in16[9] = out16[8];
        in16[10] = out16[9];
        in16[11] = out16[10];
        in16[12] = out16[11];
        in16[13] = out16[12];
        in16[14] = out16[13];
        in16[15] = out16[14]^in16[0];
    end

    ff ff16_0(clk,rst_b,in16[0],out16[0]),
       ff16_1(clk,rst_b,in16[1],out16[1]),
       ff16_2(clk,rst_b,in16[2],out16[2]),
       ff16_3(clk,rst_b,in16[3],out16[3]),
       ff16_4(clk,rst_b,in16[4],out16[4]),
       ff16_5(clk,rst_b,in16[5],out16[5]),
       ff16_6(clk,rst_b,in16[6],out16[6]),
       ff16_7(clk,rst_b,in16[7],out16[7]),
       ff16_8(clk,rst_b,in16[8],out16[8]),
       ff16_9(clk,rst_b,in16[9],out16[9]),
       ff16_a(clk,rst_b,in16[10],out16[10]),
       ff16_b(clk,rst_b,in16[11],out16[11]),
       ff16_c(clk,rst_b,in16[12],out16[12]),
       ff16_d(clk,rst_b,in16[13],out16[13]),
       ff16_e(clk,rst_b,in16[14],out16[14]),
       ff16_f(clk,rst_b,in16[15],out16[15]);

endmodule: encoding

module ff(
    input bit clk, rst_b,
    input bit in,
    output bit out);

    always_ff @(posedge clk, negedge rst_b)
        if(~rst_b)
            out <= 0;
        else
            out <= in;

endmodule: ff
