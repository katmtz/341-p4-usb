/*
 * bitstuffing module:
 * when it detects 6 1 bits in a row, it sticks a
 * zero bit in the stream.
 * saved data bits are queued (?)
 */

module bitstuffing (clk, rst_b,
                    bstr_in, bstr_in_ready,
                    bstr_out, bstr_out_ready);
    input logic clk, rst_b;
    input bit bstr_in;
    input logic [1:0] bstr_in_ready;
    output bit bstr_out;
    output logic [1:0] bstr_out_ready;

    bit stream;
    assign stream = bstr_in;
    logic bstr_in_avail;
    assign bstr_in_avail = (bstr_in_ready != 2'b0);

    // determine when to insert a 0 bit
    reg [2:0] count;
    logic swp, re;

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) count <= 0;
        else count <= (stream && ~swp) ? count + 1 : 0;
    end
    
    assign swp = (count == 3'd5);  // if swp: insert a zero bit instead of reading from stream.
    assign re = ~swp;              // else: read from stream

    logic q_empty, q_out;
    fifo q (.clk(clk), .rst_b(rst_b), 
            .data_in(stream),
            .we(bstr_in_avail), .re(re),
            .empty(q_empty), .data_out(q_out));

    assign bstr_out = (swp) ? 0 : q_out;
    assign bstr_out_ready = (~q_empty) ? 2'b01 : 2'b0; // this should be type

endmodule

/*
 * modified queue from p3:
 * WIDTH: 1 bit
 * DEPTH: 10
 * 
 * q should never be full since it will contain at most 10 bits
 * (64 bits in a message => up to 10 swapped bits)
 */

module fifo(clk, rst_b, data_in, we, re, empty, data_out);
  input  bit clk, rst_b;
  input  bit data_in;
  input  bit we; //write enable
  input  bit re; //read enable
  output bit empty;
  output bit data_out;

  reg [7:0] Q;
  reg [2:0] w_ptr, r_ptr;
  reg [3:0] count;

  logic full;
  assign full = (count == 4'd10 && ~re),
         empty = (count == 4'd0);
 
  always_ff @(posedge clk, negedge rst_b) begin 
    if (~rst_b) begin
      count <= 0; w_ptr <= 0; r_ptr <= 0; Q <= 0;
    end
    else begin
      if (re && we && count >= 1) begin
         Q[w_ptr] <= data_in;
         count <= count;
         w_ptr <= w_ptr + 1;
         r_ptr <= r_ptr + 1;
      end else begin
      if (we && !full) begin
        Q[w_ptr] <= data_in;
        count <= count + 1;
        w_ptr <= w_ptr + 1;
      end
      if (re && !empty) begin
        count <= count - 1;
        r_ptr <= r_ptr + 1;
      end
    end
    end
  end

  assign data_out = Q[r_ptr];

endmodule
