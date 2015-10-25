// Constpnts for packet sizes - info bytes + sync
`define TOK_S 7'd28
`define HANDSHAKE_S 7'd12
`define DATA_S 7'd92


/*
 * DP/DM Writing:
 * - takes a bitstream from the encoding stuff and makes it
 * conform to the dp/dm spec
 */
module w_dpdm (clk, rst_b,
             bstr_in, bstr_in_ready, p_type,
             dp, dm);

    input logic clk, rst_b;
    input bit bstr_in, bstr_in_ready;
    input logic [1:0] p_type;
    output logic dp, dm;

    logic use_stream, use_EOP, use_J;
    w_dpdm_crtl ctrl (.*)

    always_comb begin
        if (~bstr_ready) begin
            dp = 1'b1;
            dm = 1'b0;
        end
        else begin
            if (use_stream) begin
                dp = bstr_in;
                dm = ~bstr_in;
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

endmodule

module w_dpdm_ctrl(clk, rst_b,
                 bstr_in_ready, p_type,
                 use_stream, use_EOP, use_J);

    input logic clk, rst_b;
    input bit bstr_in_ready;
    input logic [1:0] p_type;
    output logic use_stream, use_EOP, use_J;

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

    // use stream if we are in the packet data
    always_comb begin
        if (bstr_in_ready) begin
            use_stream = (counter <= counter_lim) ? 1'b1 : 1'b0;
            use_EOP = (counter > counter_lim && counter <= (counter_lim + 2)) ? 1'b1 : 1'b0;
            use_J = (counter > (counter_lim + 2)) ? 1'b1 : 1'b0;
        end
        else begin
            use_stream = 1'b0;
            use_EOP = 1'b0;
            use_J = 1'b0;
        end
    end

endmodule

