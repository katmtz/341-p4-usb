module encoding(
	input bit clk, rst_b,
	input logic [98:0] pkt,  //99 is max size
	input bit pkt_avail,
	output bit bstr,
	output bit [1:0] bstr_ready,
    output bit pkt_sent);

    logic use_stream, use_crc5, use_crc16;
    logic [2:0] sending;
    assign sending = {use_crc16, use_crc5, use_stream};

    logic pts_out, crc5_out, crc16_out;

    // PACKET TYPE
    logic [7:0] pid;
    logic [1:0] pkt_type;
    assign pid = pkt[90:83];
    always_comb
        case(pid)
            `OUTPID: pkt_type = `TYPE_TOK;
            `INPID: pkt_type = `TYPE_TOK;
            `DATAPID: pkt_type = `TYPE_DATA;
            `ACKPID: pkt_type = `TYPE_HS;
            `NAKPID: pkt_type = `TYPE_HS;
            default: pkt_type = `TYPE_NON;
        endcase

    logic crc5_pkt_avail, crc16_pkt_avail;
    assign crc5_pkt_avail = use_stream && (pkt_type == `TYPE_TOK);
    assign crc16_pkt_avail = use_stream && (pkt_type == `TYPE_DATA);

    pktToSerial   pts   (clk, rst_b, pkt, pkt_type, pkt_avail, pts_out, use_stream);
    enc_crc5      crc5  (clk, rst_b, pts_out, crc5_pkt_avail, crc5_out, use_crc5);
    enc_crc16     crc16 (clk, rst_b, pts_out, crc16_pkt_avail, crc16_out, use_crc16);  

    // OUTPUT
    always_comb begin
        if (~sending) bstr = 0;
        if (use_stream) bstr = pts_out;
        else begin
            if (use_crc5) bstr = crc5_out;
            else if (use_crc16) bstr = crc16_out;
        end
    end
    assign bstr_ready = (sending != 0) ? pkt_type : 0;   
    assign pkt_sent = pkt_avail && (sending == 0);

endmodule: encoding

module pktToSerial(clk, rst_b,
                   pkt, pkt_type, pkt_avail,
                   bstr_out, bstr_out_avail);

    input logic clk, rst_b;
    input logic [98:0] pkt;
    input logic [1:0] pkt_type;
    input logic pkt_avail;
    output logic bstr_out, bstr_out_avail;

    // packet counter limit
    logic [6:0] counter_lim;
    always_comb
        case(pkt_type)
            `TYPE_TOK: counter_lim = `TOK_S - 5;
            `TYPE_DATA: counter_lim = `DATA_S - 16;
            `TYPE_HS: counter_lim = `HANDSHAKE_S;
            default: counter_lim = 0;
        endcase

    logic [7:0] counter;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 0;
        else        counter <= (pkt_avail) ? counter + 1 : 0;
    end

    assign bstr_out = pkt[(98 - counter)];
    assign bstr_out_avail = pkt_avail && counter < counter_lim; 

endmodule: pktToSerial

module enc_crc5 (clk, rst_b,
                 bstr_in, bstr_in_avail,
                 crc_out, crc_out_avail);
    input logic clk, rst_b;
    input logic bstr_in, bstr_in_avail;
    output logic crc_out, crc_out_avail;

    // ignore sync
    logic [6:0] sync_count;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) sync_count <= 0;
        else        sync_count <= (bstr_in_avail) ? sync_count + 1 : 0;
    end
    logic crc_str_avail;
    assign crc_str_avail = bstr_in_avail && (sync_count > 7);

    logic [4:0] crc_val;
    logic crc_avail;
    crc5 calc (clk, rst_b, crc_str_avail, bstr_in, crc_str_avail, crc_val, crc_avail); 

    logic [4:0] crc_saved;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) crc_saved <= 0;
        else        crc_saved <= (crc_avail) ? crc_val : crc_saved;
    end

    logic [2:0] counter;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 0;
        else        counter <= (bstr_in_avail) ? 0 : counter + 1;
    end

    assign crc_out = (crc_avail) ? crc_val[counter] : 0;
    assign crc_out_avail = (crc_avail && counter < 5);

endmodule: enc_crc5

module enc_crc16 (clk, rst_b,
                  bstr_in, bstr_in_avail,
                  crc_out, crc_out_avail);

    input logic clk, rst_b;
    input logic bstr_in, bstr_in_avail;
    output logic crc_out, crc_out_avail;

    // MAD HAX YO

    logic [4:0] counter;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 0;
        else        counter <= (bstr_in_avail) ? 0 : counter + 1;
    end

    assign crc_out = bstr_in;
    assign crc_out_avail = 0;

endmodule: enc_crc16
