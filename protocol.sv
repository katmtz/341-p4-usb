module protocol(
	//from read/write
	input logic [18:0] tokenRW,
	input logic [71:0] dataRW,
	input bit pktInAvailRW,
	//from decoder
	input logic [98:0] pktInDC,
	input bit validDC,
	input bit pktInAvailDC,
	//from/to encoder
    input bit readyEC, 
	output logic [98:0] pktOut,
	output bit pktOutAvail,
	//to read/write
	output bit done,
	output bit success,
	output bit readyIn,
    output logic [63:0] dataOut,
    //to dp/dm
    output bit re, //read enable
	input bit clk, rst_b,
    input logic nrzi_avail);


	enum logic [2:0] {Wait,ACKsend,NAKsend,TokenSend,
					  DataSend,DataWait,HandshakeWait} currState, nextState; 

	logic [18:0] ack, nak;
	assign ack = 16'h014b;  //built in default handshake packets, never change
	assign nak = 16'h015a;

	logic [3:0] tokPID;
    always_ff @(posedge clk) begin//determines the packet to send to encoder
        if (pktInAvailRW&&(currState==Wait)) begin	    
            tokPID <= tokenRW[18:15];
            pktOut <= {8'h01,tokenRW,72'd0};
        end
        else if (nextState==ACKsend)
            pktOut <= {ack,83'd0};
        else if (nextState==NAKsend)
            pktOut <= {nak,83'd0};
        else if (nextState==DataSend)
            pktOut <= {8'h01,dataRW,19'd0};
        else if (nextState==Wait) begin
            pktOut <= 99'd0;
            tokPID <= 4'd0;
        end
    end


    logic [3:0] errorCount;//,NAKcount;
    logic gotACK,gotNAK,timeout;
    always_comb begin
        gotACK = validDC && pktInAvailDC && (pktInDC[17:2]== ack);
        gotNAK = validDC && pktInAvailDC && (pktInDC[17:2]== nak);
    end

    logic tOCrst,tOCen,timeOut;

    timeOutCounter tOC(clk,tOCrst,tOCen,timeOut);
    assign tOCrst = ((nextState==DataWait)&&(currState!=DataWait))||(
                    (nextState==HandshakeWait)&&(currState!=HandshakeWait));
    assign tOCen = (currState==DataWait)||(currState==HandshakeWait);

    always_ff @(posedge clk,negedge rst_b)
        if (~rst_b||(nextState == Wait))
            errorCount <= 0;
        else if (gotNAK||timeOut||(pktInAvailDC&&~validDC))
            errorCount <= errorCount + 1;

	always_comb //nextState logic
		case (currState)
			Wait:
                nextState = (tokPID) ? TokenSend : Wait;
            TokenSend:
                nextState = readyEC ? ((tokPID == 4'b1000) ?  //check readyEC signal carefully
                            DataSend : ((tokPID == 4'b1001) ?
                            DataWait : Wait)) : TokenSend;
            DataWait:
                nextState = (pktInAvailDC) ? (validDC ? ACKsend 
                            : NAKsend) : (timeOut ? NAKsend : DataWait);
            NAKsend:
                nextState = (errorCount==8) ? Wait : DataWait;
            ACKsend:
                nextState = Wait;
            DataSend:
                nextState = HandshakeWait;
            HandshakeWait:
                nextState = (gotNAK && (errorCount<8)) ? DataSend : ((
                            gotACK || (gotNAK))? Wait : (timeOut ?
                            DataSend : HandshakeWait));
            default: 
                nextState = Wait;
        endcase

    always_comb begin //success/done/readyIn/pktOutAvail logic
        done = (nextState ==Wait)&&(currState!=Wait);
        success = (errorCount<8);
        readyIn = (currState == Wait);
        pktOutAvail = readyEC && ((nextState != Wait)||(currState==ACKsend)||(currState==NAKsend)) && (
                      (currState != HandshakeWait)&&(currState !=DataWait));
    end

    always_ff @(posedge clk)
        if (nextState==ACKsend)
            dataOut <= pktInDC[81:18];
    

    //assigning read enable
    always_ff @(posedge clk)
        re <= ((currState==DataWait)||(currState==HandshakeWait))&&(~nrzi_avail);

    always_ff @(posedge clk,posedge ~rst_b)
        if (~rst_b)
            currState <= Wait;
        else
            currState <= nextState;

endmodule: protocol

module timeOutCounter(
    input logic clk, rst, en,
    output logic timeOut);

    logic [7:0] count;
    assign timeOut = count==8'd255;

    always_ff @(posedge clk, posedge rst)
        if (rst)
            count <= 0;
        else if (en)
            count <= count + 1;
            

endmodule: timeOutCounter






