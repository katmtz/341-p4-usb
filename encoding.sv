module encoding(
	input bit clk, rst_b,
	input logic [98:0] pkt,  //99 is max size
	input bit pkt_avail,
	output bit bstr,
	output bit [1:0] bstr_ready,
    output bit pkt_sent);

    logic use_stream, use_crc5, use_crc16, use_eop;
    logic pts_out, crc5_out, crc16_out, read_from_crc;

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

    enc_ctrl      ctrl  (clk, rst_b, pkt_avail, pkt_type, use_stream, use_crc5, use_crc16, use_eop, read_from_crc, done);
    pktToSerial   pts   (clk, rst_b, pkt, use_stream, pts_out);
    enc_crc5      crc5  (clk, rst_b, pts_out, use_crc5, read_from_crc, crc5_out);
    enc_crc16     crc16 (clk, rst_b, pts_out, use_crc16, read_from_crc, crc16_out);  

    // OUTPUT
    assign pkt_sent = done;
    always_comb begin
        bstr = 0;
        if (use_stream) 
            bstr = pts_out;
        else if (use_crc5)
            bstr = crc5_out;
        else if (use_crc16)
            bstr = crc16_out;
    end

    assign bstr_ready = (use_stream || use_crc5 || use_crc16 || use_eop) ? pkt_type : 0;
endmodule: encoding

module enc_ctrl(clk, rst_b, pkt_avail, pkt_type,
                use_stream, use_crc5, use_crc16, use_eop,
                use_crc, done);

    input logic clk, rst_b;
    input logic pkt_avail;
    input logic [1:0] pkt_type;
    output logic use_stream, use_crc5, use_crc16, use_eop;
    output logic use_crc, done;

    logic [7:0] counter, counter_lim;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 0;
        else        counter <= (pkt_avail) ? counter + 1 : 0;
    end

    always_comb
        case(pkt_type)
            `TYPE_TOK: counter_lim = `TOK_S - 5;
            `TYPE_DATA: counter_lim = `DATA_S - 16;
            `TYPE_HS: counter_lim = `HANDSHAKE_S;
            default: counter_lim = 0;
        endcase

    logic [4:0] crc_size;
    always_comb
        case(pkt_type)
            `TYPE_TOK: crc_size = 5'd5;
            `TYPE_DATA: crc_size = 5'd16;
            default: crc_size = 5'd0;
        endcase

    logic use_crc;
    always_comb begin
        use_eop = 0; use_stream = 0; use_crc = 0;
        if (counter < counter_lim) begin    
            use_stream = (pkt_avail) ? 1'b1 : 1'b0;
        end else begin
        if (counter < counter_lim + crc_size) begin
            use_crc = 1'b1;
        end else begin
        if (counter < counter_lim + crc_size + 3) begin
            use_eop = 1'b1;
        end end end
    end

    assign use_crc5 = (crc_size == 5) ? (use_stream || use_crc) : 1'b0;
    assign use_crc16 = (crc_size == 16) ? (use_stream || use_crc) : 1'b0;
    assign done = (pkt_avail && ~use_stream && ~use_crc && ~use_eop);

endmodule: enc_ctrl

module pktToSerial(clk, rst_b,
                   pkt, pkt_avail,
                   bstr_out);

    input logic clk, rst_b;
    input logic [98:0] pkt;
    input logic pkt_avail;
    output logic bstr_out;

    logic [7:0] counter;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 0;
        else        counter <= (pkt_avail && counter < 99) ? counter + 1 : 0;
    end

    assign bstr_out = (pkt_avail) ? pkt[(98 - counter)] : 0;

endmodule: pktToSerial

module enc_crc5 (clk, rst_b,
                 bstr_in, en, read,
                 crc_out);
    input logic clk, rst_b;
    input logic bstr_in, en, read;
    output logic crc_out;

    // ignore sync
    logic [6:0] sync_count;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) sync_count <= 0;
        else        sync_count <= (en) ? sync_count + 1 : 0;
    end
    logic crc_str_avail;
    assign crc_str_avail = en && (sync_count > 7);

    logic [4:0] crc_val;
    logic crc_avail;
    crc5 calc (clk, rst_b, crc_str_avail, bstr_in, crc_str_avail, crc_val, crc_avail); 

    logic [2:0] counter;
    logic [4:0] crc_saved;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) crc_saved <= 0;
        else        crc_saved <= (read && counter == 0) ? crc_val : crc_saved;
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 0;
        else        counter <= (read) ? counter + 1 : 0;
    end

    always_comb
        case(counter)
            0: crc_out = (read) ? crc_val[0] : 0;
            default: crc_out = (read) ? crc_saved[counter] : 0;
        endcase

endmodule: enc_crc5

module enc_crc16 (clk, rst_b,
                  bstr_in, en, read,
                  crc_out);

    input logic clk, rst_b;
    input logic bstr_in, en, read;
    output logic crc_out;

    logic [6:0] sync_count;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) sync_count <= 0;
        else        sync_count <= (en) ? sync_count + 1 : 0;
    end
    logic crc_str_avail;
    assign crc_str_avail = en && (sync_count > 7);

    logic [15:0] crc_val;
    logic crc_avail;
    crc16 calc (clk, rst_b, crc_str_avail, bstr_in, crc_str_avail, crc_val, crc_avail);

    logic [5:0] counter;
    logic [15:0] crc_saved;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) crc_saved <= 0;
        else        crc_saved <= (read && counter == 0) ? crc_val : crc_saved;
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 0;
        else        counter <= (en) ? counter + 1 : 0;
    end

    always_comb
        case(counter)
            0: crc_out = (read) ? crc_val[0] : 0;
            default: crc_out = (read) ? crc_saved : 0;
        endcase

endmodule: enc_crc16
