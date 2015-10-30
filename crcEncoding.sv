module encoding(
	input bit clk, rst_b,
	output logic [1:0] ready,
	input logic [98:0] pkt,  //99 is max size
	input bit pktInAvail,
	output bit bOut,
	output bit readyIn);

	enum logic [2:0] {Wait,CRC5Calc,TokenSend,CRC16Calc,
                      DataSend,HandShakeSend} currState,nextState;
    enum logic [1:0] {None=2'b00, Token = 2'b01, Data = 2'b10, 
                      HandShake=2'b11} pktType;

    logic [3:0] PID; //remember: reversed, so 1000 for out
    assign PID = pkt[90:87];

    logic [10:0] addrENDP;
    logic [63:0] dataBits;
    assign addrENDP = pkt[82:72]; //will only matter if token
    assign dataBits = pkt[82:19]; //will only matter if data

    always_comb //assign packet types
        case (PID)
            4'b1000:
                pktType = Token;
            4'b1001:
                pktType = Token;
            4'b1100:
                pktType = Data;
            4'b0100:
                pktType = HandShake;
            4'b0101:
                pktType = HandShake;
            default:
                pktType = None;
        endcase
    logic put_outbound;
    assign ready = put_outbound ? pktType : 2'b00; //'


    logic [6:0] count, max, index; //controls nextState and index of pkt
    assign index = (count>=max) ? 0 : count; //CHECK: not sure if this will work
    logic counterEn,counterClr; //assigned based on state
    assign counterEn = (nextState != Wait);
    assign counterClr = (nextState == Wait);
    maxCounter mC(counterEn,counterClr,clk,max,count);

    logic c5rst, c16rst; //assigned based on state
    assign c5rst = (nextState != CRC5Calc);
    assign c16rst = (nextState != CRC16Calc);
    logic [4:0] out5;
    logic [15:0] out16;
    calc5 ffer5(clk,c5rst,addrENDP,count,out5);  //all the flipflop logic
    calc16 ffer16(clk,c16rst,dataBits,count,out16);  //for 5 and 16

    always_comb
        case (currState)
            Wait: begin
                nextState = ~pktInAvail ? Wait : (
                            pktType==Token ? CRC5Calc : (
                            pktType==Data ? CRC16Calc : 
                            pktType==HandShake ? HandShakeSend : (
                            Wait)));
                max = 7'd12;
                end
            CRC5Calc: begin
                nextState = (count==12) ? TokenSend : CRC5Calc;
                max = 7'd12;
                end
            CRC16Calc: begin
                nextState = (count==65) ? DataSend : CRC16Calc;
                max = 7'd65;
                end
            TokenSend: begin
                nextState = (count==35) ? Wait : TokenSend;
                max = 7'd35;
                end
            DataSend: begin
                nextState = (count==99) ? Wait : DataSend;
                max = 7'd99;
                end
            HandShakeSend: begin
                nextState = (count==19) ? Wait : HandShakeSend;
                max = 7'd19;
                end
            default: begin
                nextState = Wait;
                max = 7'd0;
                end //'
        endcase

    logic [98:0] pktToken;
    logic [98:0] pktData, pktToSend;
    logic [98:0] pktHandshake;
    logic full, save;
    logic [6:0] rstIndex;
    assign pktToSend = (nextState==HandShakeSend) ? pktHandshake : (
                        nextState==DataSend ? pktData : pktToken);
    assign rstIndex = (nextState==HandShakeSend) ? 7'd18 : (
                        nextState==DataSend ? 7'd98 : 7'd34); //'
    PISO_reg piso(bOut,full,put_outbound,pktToSend,rstIndex,clk,save,~rst_b);
        

    always_comb begin //assigning the calculated crc into the packet to send
        pktToken = 98'd0;
        pktHandshake = 98'd0;
        pktToken = pkt[98:64];
        pktData = pkt;
        pktHandshake = pkt[98:79];
        save=0;
        if (((currState==CRC5Calc) || (currState==CRC16Calc)) && (count==max)) begin
            save = 1;
            pktToken[7] = ~out5[0];
            pktToken[6] = ~out5[1];
            pktToken[5] = ~out5[2];
            pktToken[4] = ~out5[3];
            pktToken[3] = ~out5[4];
            pktData[18] = ~out16[0];
            pktData[17] = ~out16[1];
            pktData[16] = ~out16[2];
            pktData[15] = ~out16[3];
            pktData[14] = ~out16[4];
            pktData[13] = ~out16[5];
            pktData[12] = ~out16[6];
            pktData[11] = ~out16[7];
            pktData[10] = ~out16[8];
            pktData[9] = ~out16[9];
            pktData[8] = ~out16[10];
            pktData[7] = ~out16[11];
            pktData[6] = ~out16[12];
            pktData[5] = ~out16[13];
            pktData[4] = ~out16[14];
            pktData[3] = ~out16[15];
            end
    end


    always_ff @(posedge clk,negedge rst_b)
        if (~rst_b)
            currState <= Wait;
        else
            currState <= nextState;

endmodule: encoding

module calc16(
    input bit clk, rst,
    input logic [63:0] data,
    input logic [6:0] index, //goes up to 65
    output logic [15:0] out16);

    logic [15:0] in16;
    logic bstr;
    assign bstr = index<64 ? index : 0;

    always_comb begin
        in16[0] = index == 7'b0 ? 1'b1 : out16[15]^bstr;
        in16[1] = index == 7'b0 ? 1'b1 : out16[0];
        in16[2] = index == 7'b0 ? 1'b1 : out16[1]^in16[0];
        in16[3] = index == 7'b0 ? 1'b1 : out16[2];
        in16[4] = index == 7'b0 ? 1'b1 : out16[3];
        in16[5] = index == 7'b0 ? 1'b1 : out16[4];
        in16[6] = index == 7'b0 ? 1'b1 : out16[5];
        in16[7] = index == 7'b0 ? 1'b1 : out16[6];
        in16[8] = index == 7'b0 ? 1'b1 : out16[7];
        in16[9] = index == 7'b0 ? 1'b1 : out16[8];
        in16[10] = index == 7'b0 ? 1'b1 : out16[9];
        in16[11] = index == 7'b0 ? 1'b1 : out16[10];
        in16[12] = index == 7'b0 ? 1'b1 : out16[11];
        in16[13] = index == 7'b0 ? 1'b1 : out16[12];
        in16[14] = index == 7'b0 ? 1'b1 : out16[13];
        in16[15] = index == 7'b0 ? 1'b1 : out16[14]^in16[0];
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
endmodule: calc16

module calc5(
    input bit clk, rst,
    input logic [10:0] addrENDP,
    input logic [6:0] index, //goes up to 12
    output logic [4:0] out5);

    logic [4:0] in5;
    logic bstr;
    assign bstr = index<11 ? index : 0;

    always_comb begin
        in5[0] = index == 7'b0 ? 1'b1 : out5[4]^bstr;
        in5[1] = index == 7'b0 ? 1'b1 : out5[0];
        in5[2] = index == 7'b0 ? 1'b1 : out5[1]^in5[0];
        in5[3] = index == 7'b0 ? 1'b1 : out5[2];
        in5[4] = index == 7'b0 ? 1'b1 : out5[3];
    end

    ff ff5_0(clk,rst,in5[0],out5[0]),
       ff5_1(clk,rst,in5[1],out5[1]),
       ff5_2(clk,rst,in5[2],out5[2]),
       ff5_3(clk,rst,in5[3],out5[3]),
       ff5_4(clk,rst,in5[4],out5[4]);


endmodule: calc5


module ff(  //initiated to ONE
	input bit clk, rst,
	input bit in,
	output bit out);

	always_ff @(posedge clk, posedge rst)
		if(rst)
			out <= 1;
		else
			out <= in;

endmodule: ff



module PISO_reg( //for OUT/IN: 24+8+3=35, data: 99, hs: 19
  output logic outBit,
  output logic full,
  output logic put_outbound,
  input logic [98:0] in,
  input logic [6:0] rstIndex,
  input logic clk, save, rst);
  
  enum logic [5:0] {Empty,Sending,Last} currState, nextState;

  logic [34:0] savedIn;
  always_ff @(posedge clk, posedge rst)
	  if (rst)
		savedIn <= 0;
	  else if (save && (currState == Empty))
		savedIn <= in;

  logic counterEn,counterClr;
  logic [6:0] index;
  revCounter revC(counterEn,counterClr,clk,index, rstIndex);

  always_comb
	  case (currState)
		Empty:
			nextState = save ? Sending : Empty;
		Sending:
			nextState = index>0 ? Sending : Last;
		Last:
			nextState = Empty;
		default:
		  nextState = Empty;  //'
	  endcase
  
  always_comb begin
  	if (currState == Sending) begin
  		counterClr = 0;
  		counterEn = 1;
  		end
  	else begin
  		counterClr = (nextState==Empty) ? 1'b1 : rst;//'
  		counterEn = 0;
  		end

  end
  always_comb begin
	  case (currState)
		Empty: begin
			full = 0;
			put_outbound = 0;
			outBit = 0;
		end
		Sending: begin
			full = save;
			put_outbound = 1;
			outBit = savedIn[index];
		end
		Last: begin
			full = 1;
			put_outbound = 1;
			outBit = savedIn[index];
		end
		default: begin
			full = 0;
			put_outbound = 0;
			outBit = 0;
		end
	  endcase
	end
  
  always_ff @(posedge clk,posedge rst)
	  if (rst)
	currState <= Empty;
	  else
	currState <= nextState;
endmodule: PISO_reg


module revCounter( //actually counts normally wow
	input logic en, rst, clk,
	output logic [6:0] index,
    input logic [6:0] rstIndex);

	always_ff @(posedge clk, posedge rst)
		if (rst)
		  index <=rstIndex;  
		else if (en)
		  index <= (index!=0) ? index - 1 : 0; //dont wanna be goin negative
endmodule: revCounter


module maxCounter( //up to 10 max
	input logic en, clr, clk,
    input logic [6:0] max,
	output logic [6:0] count);

	always_ff @(posedge clk, posedge clr)
        if (clr || (count==max))
		  count <=0;
		else if (en || (count!=0)) 
		    count <= count + 1;
        
endmodule: maxCounter
