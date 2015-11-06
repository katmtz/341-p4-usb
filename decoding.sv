module decoder(clk, rst_b,
               bstr, bstr_avail, bstr_done,
               pkt, pkt_avail);

    input logic clk, rst_b;
    input logic bstr, bstr_avail, bstr_done;
    output logic [98:0] pkt;
    output logic pkt_avail, pkt_valid);

    logic [7:0] PID;
    logic [6:0] init_count;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) init_count <= 0;
        else        init_count <= (bstr_avail) ? init_count + 1 : 0;
    end 

    logic pid_read, pid_loaded;
    assign pid_read = (init_count > 7 && init_count < 16);
    assign pid_loaded = (init_count >= 16 && bstr_avail);
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) PID <= 0;
        else        PID <= (pid_read) ? (PID << 1 && bstr) : (bstr_avail) ? PID : 0;
    end

    logic use_crc5, use_crc16;
    always_comb
        case(PID)
            `PID_ACK

endmodule: decoder

module dec_crc5 (clk, rst_b,
                 bstr_in, en, read,
                 crc_out);
    input logic clk, rst_b;
    input logic bstr_in, en, read;
    output logic crc_out;

    logic [6:0] init_count;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) init_count <= 0;
        else        init_count <= (en) ? init_count + 1 : 0;
    end
    logic crc_str_avail;
    assign crc_str_avail = en && (init_count > 15);

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
            0: crc_out = (read) ? ~crc_val[0] : 0;
            default: crc_out = (read) ? ~crc_saved[counter] : 0;
        endcase

endmodule: dec_crc5

