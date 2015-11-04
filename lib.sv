/*
 * Shared library functions and constants for all modules.
 */

// Constants

// PIDs
`define OUTPID 8'b10000111
`define INPID 8'b10010110
`define DATAPID 8'b11000011

// Addresses and endpoints
`define ADDR 7'b1010000
`define ENDP4 4'b0010
`define ENDP8 4'b0001

// Task types
`define TASK_IDLE 2'b0
`define TASK_READ 2'b01
`define TASK_WRITE 2'b10

// Transaction types
`define TRANS_NON 2'b00
`define TRANS_IN  2'b01
`define TRANS_OUT 2'b10

// Packet sizes
`define TOK_S 7'd32
`define HANDSHAKE_S 7'd16
`define DATA_S 7'd96

// Handshake packets
`define HS_ACK 19'h014b
`define HS_NAK 19'h015a

// Sync
`define SYNC 8'b00000001

// Useful Modules

/*
 * Combinationally reverse a 64b data chunk
 */

module reverser (data_in, data_out);
    input logic [63:0] data_in;
    output logic [63:0] data_out;

    generate
        for (genvar i = 0; i < 64; i++) begin : r
            assign data_out[i] = data_in[(63 - i)];
        end
    endgenerate

endmodule: reverser

/*
 * Serial to packet conversion
 */
module SIPO  
    (output logic [98:0] d,
    input bit inBit,
    output logic done,
    input logic [6:0] max,
    input logic clock,
    input logic en,
    input logic rst);

    logic [98:0] q;
    logic [6:0] count;

    assign d = q;
    assign done = (count==max); 
    
    always_ff @(posedge clock, posedge rst)
      if (rst) begin
        q <= 0;
        count <= 0;
        end
      else if (en) begin
        q <= (q << 1) | inBit;
        count <= (count==99) ? 0 : (count+1);
        end

endmodule: SIPO

/*
 * Packet to serial conversion
 */

module PISO( //for OUT/IN: 24+8+3=35, data: 99, hs: 19
  output logic outBit,
  output logic full,
  output logic put_outbound,
  input logic [98:0] in,
  input logic [6:0] rstIndex,
  input logic clk, save, rst);
  
  enum logic [5:0] {Empty,Sending,Last} currState, nextState;

  logic [98:0] savedIn;
  always_ff @(posedge clk, posedge rst)
      if (rst)
        savedIn <= 0;
      else if (save && (currState == Empty))
        savedIn <= in;

  logic counterEn,counterClr;
  logic [6:0] index;
  revCounter revC(counterEn,counterClr,clk,index, rstIndex);

  always_comb
      case (currState)
        Empty:
            nextState = save ? Sending : Empty;
        Sending:
            nextState = index>0 ? Sending : Last;
        Last:
            nextState = Empty;
        default:
          nextState = Empty;  //'
      endcase
  
  always_comb begin
    if (currState == Sending) begin
        counterClr = 0;
        counterEn = 1;
        end
    else begin
        counterClr = (nextState==Empty) ? 1'b1 : rst;//'
        counterEn = 0;
        end

  end
  always_comb begin
      case (currState)
        Empty: begin
            full = 0;
            put_outbound = 0;
            outBit = 0;
        end
        Sending: begin
            full = save;
            put_outbound = 1;
            outBit = savedIn[index];
            //$display("%b",outBit);
        end
        Last: begin
            full = 1;
            put_outbound = 0; //1;
            outBit = savedIn[index];
        end
        default: begin
            full = 0;
            put_outbound = 0;
            outBit = 0;
        end
      endcase
    end
  
  always_ff @(posedge clk,posedge rst)
      if (rst)
    currState <= Empty;
      else
    currState <= nextState;
endmodule: PISO

module revCounter( //actually counts normally wow
    input logic en, rst, clk,
    output logic [6:0] index,
    input logic [6:0] rstIndex);

    always_ff @(posedge clk, posedge rst)
        if (rst)
          index <=rstIndex;  
        else if (en)
          index <= (index!=0) ? index - 1 : 0; //dont wanna be goin negative
endmodule: revCounter
