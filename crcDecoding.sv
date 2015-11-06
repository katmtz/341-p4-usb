module decoding(
	input bit clk, rst_b,
	output logic [98:0] pkt,  //99 is max size
    input bit bitInAvail,
    input bit bitIn,
    input bit done,
	output bit pktOutAvail,
    output bit valid,
	output bit readyIn);

    assign readyIn = 1; //always ready

    enum logic [2:0] {Wait,Collect,CRC5,CRC16} currState,nextState;

    bit isToken,isData;
    logic [3:0] PID, nPID;
    logic [7:0] pid;
    assign pid = { nPID, PID };

    assign isToken = (pid == `OUTPID || pid == `INPID);
    assign isData = (pid == `DATAPID);

    logic [6:0] count, max, index; //controls nextState and index of pkt
    assign index = (count >= max) ? 0 : count; 
    logic counterEn,counterClr; //assigned based on state
    assign counterEn = bitInAvail || (currState == CRC5 || currState == CRC16);
    assign counterClr = (currState == Wait);
    maxCounter2 mC(counterEn,counterClr,clk,max,count);

    //collect packet
    logic sipoDone,sipoRst;
    logic [6:0] sipoMax;
    assign sipoMax = (isToken) ? 7'd35 : (isData ? 7'd99 : 7'd19); //'
    assign sipoRst = ~rst_b || (currState==Wait && nextState != Collect);
    SIPO sipo(pkt,bitIn,sipoDone,sipoMax,clk,bitInAvail,sipoRst);

    //get residues!
    logic [15:0] compRemainder5;
    logic [4:0] residue5,checkR5;
    logic [79:0] compRemainder16;
    logic [15:0] residue16,checkR16;
    assign checkR5 = 5'b0110;
    assign checkR16 =  16'h800d;   
    assign compRemainder5 = pkt[16:1];
    assign compRemainder16 = pkt[80:1];

    logic c5rst, c16rst; //assigned based on state
    assign c5rst = (currState == Wait);
    assign c16rst = (currState == Wait);
    calcR5 ffer5(clk,c5rst,compRemainder5,count,residue5);  //all the flipflop logic
    calcR16 ffer16(clk,c16rst,compRemainder16,count,residue16);  //for 5 and 16

    logic [3:0] npid, pid;
    assign pktOutAvail = (nextState==Wait)&&((currState!=Wait));
    assign valid = (isToken || isData);
    
    assign nPID = (pktOutAvail) ? pkt[3:0] : 0;
    assign PID = (pktOutAvail) ? pkt[7:4] : 0;

    always_comb begin //nextstate logic and max of counter
        case (currState)
            Wait:
                nextState = bitInAvail ? Collect : Wait;
            Collect: begin
                nextState = ~done ? Collect : (  //CHANGED TO not done instead of bitInAvail
                            isToken ? CRC5 : (isData ?
                            CRC16 : Wait));
                max = (nextState==CRC16) ? 7'd80 : 7'd99;
            end
            CRC5: begin
                max = 7'd15;
                nextState = (count==15) ? Wait : CRC5;
            end
            CRC16: begin
                max = 7'd79; //'
                nextState = (count==7'd79) ? Wait : CRC16;
            end
            default:
                nextState = Wait;
        endcase
    end


    always_ff @(posedge clk,negedge rst_b)
        if (~rst_b)
            currState <= Wait;
        else
            currState <= nextState;

endmodule: decoding

module calcR16(
    input bit clk, rst,
    input logic [79:0] compR,
    input logic [6:0] index, //goes up to 17
    output logic [15:0] out16);

    logic [15:0] in16;
    logic bstr;
    assign bstr = index<79 ? compR[78-index] : compR[79];

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

    ff ff16_0(clk,rst,in16[0],out16[0]),
       ff16_1(clk,rst,in16[1],out16[1]),
       ff16_2(clk,rst,in16[2],out16[2]),
       ff16_3(clk,rst,in16[3],out16[3]),
       ff16_4(clk,rst,in16[4],out16[4]),
       ff16_5(clk,rst,in16[5],out16[5]),
       ff16_6(clk,rst,in16[6],out16[6]),
       ff16_7(clk,rst,in16[7],out16[7]),
       ff16_8(clk,rst,in16[8],out16[8]),
       ff16_9(clk,rst,in16[9],out16[9]),
       ff16_a(clk,rst,in16[10],out16[10]),
       ff16_b(clk,rst,in16[11],out16[11]),
       ff16_c(clk,rst,in16[12],out16[12]),
       ff16_d(clk,rst,in16[13],out16[13]),
       ff16_e(clk,rst,in16[14],out16[14]),
       ff16_f(clk,rst,in16[15],out16[15]);

endmodule: calcR16

module calcR5(
    input bit clk, rst,
    input logic [15:0] compR,
    input logic [6:0] index, //goes up to 6
    output logic [4:0] out5);

    logic [4:0] in5;
    logic bstr;
    assign bstr = index<16 ? compR[15-index] : 0;

    always_comb begin
        in5[0] = out5[4]^bstr;
        in5[1] = out5[0];
        in5[2] = out5[1]^in5[0];
        in5[3] = out5[2];
        in5[4] = out5[3];
    end

    ff ff5_0(clk,rst,in5[0],out5[0]),
       ff5_1(clk,rst,in5[1],out5[1]),
       ff5_2(clk,rst,in5[2],out5[2]),
       ff5_3(clk,rst,in5[3],out5[3]),
       ff5_4(clk,rst,in5[4],out5[4]);


endmodule: calcR5

module maxCounter2( //up to max, different than maxCounter in encoder
	input logic en, clr, clk,
    input logic [6:0] max,
	output logic [6:0] count);

	always_ff @(posedge clk, posedge clr)
        if (clr || (count>=max))
            count <=0;
		else if (en) 
		    count <= count + 1;
        
endmodule: maxCounter2
