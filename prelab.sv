`include "crcEncoding.sv"
`include "stuffer.sv"
`include "nrzi.sv"
`include "dpdm.sv"

module prelab(clk, rst_b,
              pkt, pkt_avail, ready_in,
              dp, dm);
    input logic clk, rst_b, pkt_avail;
    input bit [98:0] pkt;
    output logic ready_in;
    output bit dp, dm;

    logic crc2stuffer_str, stuffer2nrzi_str, nrzi2dpdm_str, dp_r, dm_r, rw;
    logic [1:0] crc2stuffer_ready, stuffer2nrzi_ready, nrzi2dpdm_ready;

    encoding    encoder (clk, rst_b, crc2stuffer_ready, pkt, pkt_avail, crc2stuffer_str, ready_in);
    bitstuffing stuffer (clk, rst_b, crc2stuffer_str, crc2stuffer_ready, stuffer2nrzi_str, stuffer2nrzi_ready);
    nrzi        nrzier  (clk, rst_b, stuffer2nrzi_str, stuffer2nrzi_ready, nrzi2dpdm_str, nrzi2dpdm_ready);
    dpdm        dpdmer  (clk, rst_b, nrzi2dpdm_str, nrzi2dpdm_ready, rw, dp_r, dm_r, dp, dm);
endmodule: prelab
