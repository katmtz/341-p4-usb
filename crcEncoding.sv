module encoding(
	input bit clk, rst_b,
	output logic [1:0] ready,
	input logic [98:0] pkt,  //99 is max size
	input bit pktInAvail,
	output bit bOut,
	output bit readyIn);

	//JUST FOR OUT/IN: fix l8r
	logic [1:0] pktType;
	assign pktType = 2'b01; //' just 4 tb yo FIX

	logic [5:0] index;

	logic en;
	assign en = pktInAvail;

	logic [10:0] addrENDP;
	assign addrENDP = pkt[82:72];

	Counter pktIndexCount(en,~rst_b,clk,index);
	logic [5:0] index2;
	Counter2 pktIndexPlus1(en,~rst_b,clk,index2);

	logic bstr;
	assign bstr = addrENDP[index];

	//for crc5
	logic [4:0] in5, out5;

	always_comb begin
		in5[0] = index2 != 0 ? 1'b1 : out5[4]^bstr;
		in5[1] = index2 != 0 ? 1'b1 : out5[0];
		in5[2] = index2 != 0 ? 1'b1 : out5[1]^in5[0];
		in5[3] = index2 != 0 ? 1'b1 : out5[2];
		in5[4] = index2 != 0 ? 1'b1 : out5[3]; //'
	end

	ff ff5_0(clk,rst_b,in5[0],out5[0]),
	   ff5_1(clk,rst_b,in5[1],out5[1]),
	   ff5_2(clk,rst_b,in5[2],out5[2]),
	   ff5_3(clk,rst_b,in5[3],out5[3]),
	   ff5_4(clk,rst_b,in5[4],out5[4]);

	//SAVE CRC??
	logic save;
	assign save = (index2==6'd11); //'

	//following controls sending to bit stuffing yay

	logic [4:0] crc5;
	logic put_outbound, full;

	logic [34:0] pktToken;    //ALL OF THIS STILL FIX L8R
	
	PISO_reg piso(bOut,full,put_outbound,pktToken,clk,save,~rst_b);
	
	assign ready = put_outbound ? 2'b01 : 2'b00; //CHANGE L8R

	always_comb begin
		pktToken = pkt[98:64]; //THIS IS SO BAD IM SRY
		if (index2==6'd11) begin //' SAVE FF OUTPUTS
			crc5 = out5;
			pktToken[7:3] = ~out5; //was backwards before: lsb to msb
		end
		else begin
			crc5 = 5'd0;
			pktToken = 35'd0; 
		end
	end

	//for crc16
/*   not using this for prelab: (ignore for now)

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
*/


endmodule: encoding

module ff(  //initiated to ONE
	input bit clk, rst_b,
	input bit in,
	output bit out);

	always_ff @(posedge clk, negedge rst_b)
		if(~rst_b)
			out <= 1;
		else
			out <= in;

endmodule: ff



module PISO_reg( //for OUT/IN: 24+8+3=35
  output logic outBit,
  output logic full,
  output logic put_outbound,
  input logic [34:0] in,
  input logic clk, save, rst);
  
  enum logic [5:0] {Empty,Sending,Last} currState, nextState;

  logic [34:0] savedIn;
  always_ff @(posedge clk, posedge rst)
	  if (rst)
		savedIn <= 0;
	  else if (save && (currState == Empty))
		savedIn <= in;

  logic counterEn,counterClr;
  logic [5:0] index;
  revCounter revC(counterEn,counterClr,clk,index);

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
	output logic [5:0] index);

	always_ff @(posedge clk, posedge rst)
		if (rst)
		  index <=6'd34;  //'this syntax highlighting is silly
		else if (en)
		  index <= (index!=0) ? index - 1 : 0; //dont wanna be goin negative
endmodule: revCounter


module Counter( //up to 10 max
	input logic en, clr, clk,
	output logic [5:0] index);

	always_ff @(posedge clk, posedge clr)
		if (clr || (index==10))
		  index <=0;
		else if (en || (index!=0))
		  index <= index + 1;
endmodule: Counter

module Counter2( //up to 11 max
	input logic en, clr, clk,
	output logic [5:0] index);

	always_ff @(posedge clk, posedge clr)
		if (clr || (index==11))
		  index <=0;
		else if (en || (index!=0))
		  index <= index + 1;
endmodule: Counter2
