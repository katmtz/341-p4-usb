/*
 * unnrzi:
 * - converts a stream of usb nrzi encoded data to raw bits
 * - expects incoming data_avail to be asserted through data
 * and eop bits
 */

module unnrzi (clk, rst_b,
               bstr_in, bstr_in_ready, in_done,
               bstr_out, bstr_out_ready, out_done);

    input logic clk, rst_b;
    input bit bstr_in, bstr_in_ready, in_done;
    output bit bstr_out, bstr_out_ready, out_done;

    logic bstr_last;

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) bstr_last <= 1'b1;
        else        bstr_last <= bstr_in;
    end

    assign bstr_out = (bstr_in == bstr_last),//(bstr_in_ready && (bstr_in == bstr_last)),
           bstr_out_ready = bstr_in_ready,
           out_done = in_done;

endmodule: unnrzi
