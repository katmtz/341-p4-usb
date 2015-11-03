// Constpnts for packet sizes - info bytes + sync
`define TOK_S 7'd32
`define HANDSHAKE_S 7'd16
`define DATA_S 7'd96

/*
 * DP/DM
 * @input w_bstr - bitstream from host, to be written out
 * @input w_bstr_ready - data ready for w_bstr, also indicates packet type
 * @input rw - control signal from protocol fsm, controls whether dp/dm is
 *             reading or writing; 0 is read, 1 is write
 * @output r_bstr - bitstream into host, to be decoded
 * @output r_bstr_ready - data ready for r_bstr, also indicates packet type 
 */
module dpdm (clk, rst_b,
             w_bstr, w_bstr_ready,
             r_bstr, r_bstr_ready,
             dp_r, dm_r, dp_w, dm_w, 
             re, done);

    input logic clk, rst_b;
    input logic [1:0] w_bstr_ready;           // ENCODING ==> DPDM
    input bit w_bstr;                         // ENCODING ==> DPDM
    input bit dp_r, dm_r;                     // DEVICE   ==> HOST
    output bit dp_w, dm_w;                    // HOST     ==> DEVICE
    output logic r_bstr_ready;                // DPDM     ==> UNENCODING
    output bit r_bstr;                        // DPDM     ==> UNENCODING

    input bit re;                             // PROTOCOL FSM ==> DPDM
    output bit done;                          // DPDM         ==> UNENCODING
    logic r_ready;

    // writing
    w_dpdm w (clk, rst_b, w_bstr, w_bstr_ready, dp_w, dm_w);

    // reading
    r_dpdm r (clk, rst_b, r_bstr, r_ready, dp_r, dm_r, done);

    assign r_bstr_ready = re && r_ready;      // only use bitstream if reading

endmodule: dpdm

/*
 * DP/DM Reading
 * - receives a bitstream from the device, passes the right info 
 * on to the unencoding pipeline
 */
module r_dpdm(clk, rst_b,
              bstr, bstr_ready,
              dp, dm, done);

    input logic clk, rst_b;
    input bit dp, dm;
    output bit bstr;
    output logic bstr_ready;
    output logic done;

    // seek sync -> send dp & assert bstr -> detect EOP -> deassert pkt avail
    enum logic [1:0] {seek = 2'b00, en = 2'b01, eop = 2'b10} state, nextState;

    always_comb
        case (state)
            seek: nextState = (dp == 1'b0 && dm == 1'b1) ? en : seek;
            en: nextState = (dp == 1'b0 && dm == 1'b0) ? eop : en;
            eop: nextState = (dp == 1'b1 && dm == 1'b0) ? seek : eop;
        endcase  

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) state <= seek;
        else state <= nextState;
    end

    assign bstr = dp;
    assign bstr_ready = (nextState == en || nextState == eop);
    assign done = (state == eop && nextState == seek);

endmodule: r_dpdm

/*
 * DP/DM Writing:
 * - takes a bitstream from the encoding stuff and makes it
 * conform to the dp/dm spec
 */
module w_dpdm (clk, rst_b,
             bstr, bstr_ready,
             dp, dm);

    input logic clk, rst_b;
    input bit bstr;
    input logic [1:0] bstr_ready;
    output logic dp, dm;

    logic bstr_avail, use_stream, use_SEO, use_J;
    assign bstr_avail = (bstr_ready != 2'b0);
    w_dpdm_ctrl ctrl (clk, rst_b, 
                      bstr_avail, bstr_ready, 
                      use_stream, use_SEO, use_J);

    always_comb begin
        if (~bstr_avail) begin
            dp = 1'b1;
            dm = 1'b0;
        end
        else begin
            if (use_stream) begin
                dp = bstr;
                dm = ~bstr;
            end
            if (use_SEO) begin
                dp = 1'b0;
                dm = 1'b0;
            end
            if (use_J) begin
                dp = 1'b1;
                dm = 1'b0;
            end
        end
    end

endmodule: w_dpdm

module w_dpdm_ctrl (clk, rst_b,
                    bstr_ready, p_type,
                    use_stream, use_SEO, use_J);

    input logic clk, rst_b;
    input bit bstr_ready;
    input logic [1:0] p_type;
    output logic use_stream, use_SEO, use_J;

    // decide what counter's limit should be;
    logic [6:0] counter_lim;
    always_comb
        case(p_type)
            2'b0: counter_lim = 7'b0;
            2'b01: counter_lim = `TOK_S;
            2'b10: counter_lim = `DATA_S;
            2'b11: counter_lim = `HANDSHAKE_S;
        endcase

    // increment counter if there's data
    reg [6:0] counter;
    bit [6:0] count_in;
    always_comb begin
        if (~bstr_ready)
            count_in = 7'b0;
        else begin
            count_in = counter + 1;
        end
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 7'b0;
        else        counter <= count_in;
    end

    // use stream if we are in the packet data
    always_comb begin
        if (bstr_ready) begin
            use_stream = (counter <= counter_lim) ? 1'b1 : 1'b0;
            use_SEO = (counter > counter_lim && counter <= (counter_lim + 2)) ? 1'b1 : 1'b0;
            use_J = (counter > (counter_lim + 2)) ? 1'b1 : 1'b0;
        end
        else begin
            use_stream = 1'b0;
            use_SEO = 1'b0;
            use_J = 1'b0;
        end
    end

endmodule: w_dpdm_ctrl
