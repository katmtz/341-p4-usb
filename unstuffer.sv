/*
 * unstuffer:
 * - converts a stream of "stuffed" data into a stream
 * of "unstuffed" data
 * - expects bstr_in_avail to be asserted through
 * packet and eop, but not sync
 */

module unstuffing (clk, rst_b,
                  bstr_in, bstr_in_avail, in_done,
                  bstr_out, bstr_out_avail, out_done);

    input logic clk, rst_b;
    input bit bstr_in;
    input logic bstr_in_avail, in_done;
    output bit bstr_out;
    output logic bstr_out_avail, out_done;

    logic swp;
    // if string of 6 detected, deassert bstr_out_avail
    unstuffer_ctrl ctrl (clk, rst_b, bstr_in, bstr_in_avail, swp);

    assign bstr_out = bstr_in,
           bstr_out_avail = (bstr_in_avail && ~swp),
           out_done = in_done;  

endmodule: unstuffing

module unstuffer_ctrl (clk, rst_b,
                       bstr_in, bstr_in_avail,
                       swp);
    input logic clk, rst_b;
    input bit bstr_in;
    input logic bstr_in_avail;
    output logic swp;

    enum logic {seek = 1'b0, counting = 1'b1} state, nextState;
    logic [2:0] counter;

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) counter <= 3'b0;
        else        counter <= (state == counting) ? counter + 1 : 3'b0;
    end

    always_comb begin
        if (~bstr_in_avail || ~bstr_in) nextState = seek;
        else begin
            if (counter == 3'd6) nextState = seek;
            else                 nextState = counting;
        end
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) state <= seek;
        else state <= nextState;
    end

    assign swp = ((state == counting) && (nextState == seek) && (counter==3'd6));

endmodule: unstuffer_ctrl
