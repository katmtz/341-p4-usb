module nrzi(clk, rst_b, 
            bstr_in, bstr_in_ready,
            bstr_out, bstr_out_ready,
            stuffed_in, stuffed_out);

    input bit clk, rst_b, bstr_in;
    input bit [1:0] bstr_in_ready;
    output bit bstr_out;
    output bit [1:0] bstr_out_ready;
    input logic [5:0] stuffed_in;
    output logic [5:0] stuffed_out;

    logic use_nrzi, bstr_avail;
    assign bstr_avail = (bstr_in_ready != 2'b0);
    nrzi_ctrl ctrl (clk, rst_b, bstr_avail, bstr_in_ready, use_nrzi, stuffed_in, stuffed_out);

    // calculate the nrzi value if you're supposed to
    reg nrzi_val;
    reg [1:0] bstr_out_ready_r;
    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) nrzi_val <= 1'b1;
        else        nrzi_val <= (~use_nrzi) ? 1'b1 : (bstr_in) ? nrzi_val : ~nrzi_val;
        bstr_out_ready_r <= bstr_in_ready;
    end

    assign bstr_out = (use_nrzi) ? nrzi_val : bstr_in,
           bstr_out_ready = bstr_in_ready;

endmodule

/*
 * determines when it's appropriate to use the nrzi encoding.
 * given a packet type, counts clk cycles 
 */
module nrzi_ctrl(clk, rst_b,
                 bstr_in_ready, p_type,
                 use_nrzi,
                 stuffed_in, stuffed_out);

    input logic clk, rst_b;
    input bit bstr_in_ready;
    input logic [1:0] p_type;
    output logic use_nrzi;
    input logic [5:0] stuffed_in;
    output logic [5:0] stuffed_out;



    // decide what counter's limit should be;
    logic [6:0] counter_lim;
    always_comb
        case(p_type)
            2'b0: counter_lim = 7'b0;
            2'b01: counter_lim = `TOK_S+stuffed_in;
            2'b10: counter_lim = `DATA_S+stuffed_in;
            2'b11: counter_lim = `HANDSHAKE_S+stuffed_in;
        endcase

    // increment counter if there's data    
    reg [6:0] counter;
    bit [6:0] count_in;
    always_comb begin
        if (~bstr_in_ready)
            count_in = 7'b0;
        else begin
            count_in = counter + 1;
        end
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 7'b0;
        else        counter <= count_in;
    end

    // use nrzi if we are in the packet data
    always_comb begin
        if (bstr_in_ready && (counter <= counter_lim))
            use_nrzi = 1'b1;
        else use_nrzi = 1'b0;
    end

    assign stuffed_out = stuffed_in;

endmodule
