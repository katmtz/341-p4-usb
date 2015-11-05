// MODULE FILES
`include "crcEncoding.sv"
`include "crcDecoding.sv"
`include "stuffer.sv"
`include "nrzi.sv"
`include "dpdm.sv"
`include "unnrzi.sv"
`include "unstuffer.sv"

/*
 * datapath:
 * two-way module connecting the protocol fsm and host/device connection.
 */

module datapath (clk, rst_b,
                 pkt_in, pkt_in_avail,
                 pkt_out, pkt_out_avail,
                 dp_w, dm_w, dp_r, dm_r,
                 data_good, decoder_ready, encoder_ready, re);

    input logic clk, rst_b;
    input logic [98:0] pkt_in;      // PROTOCOL FSM --> DATAPATH
    input logic pkt_in_avail;       // PROTOCOL FSM --> DATAPATH
    output logic re;                 // PROTOCOL FSM --> DPDM
    input logic dp_r, dm_r;         // DEVICE       --> DPDM
    output logic [98:0] pkt_out;    // DATAPATH     --> PROTOCOL FSM
    output logic pkt_out_avail;     // DATAPATH     --> PROTCOL FSM
    output logic dp_w, dm_w;        // DPDM         --> DEVICE
    output logic data_good;         // DATAPATH     --> PROTOCOL FSM
    output logic decoder_ready;     // DATAPATH     --> PROTOCOL FSM
    output logic encoder_ready;     // DATAPATH     --> PROTOCOL FSM

    // OUTBOUND PKTS:
    // PROTOCOL FSM --> DPDM

    logic crc2stuffer_str, stuffer2nrzi_str, nrzi2dpdm_str;
    logic [1:0] crc2stuffer_ready, stuffer2nrzi_ready, nrzi2dpdm_ready;
    logic [5:0] stuffed_in, stuffed_out;

    encoding    encoder (clk, rst_b, pkt_in, pkt_in_avail, crc2stuffer_str, crc2stuffer_ready, encoder_ready);
    bitstuffing stuffer (clk, rst_b, crc2stuffer_str, crc2stuffer_ready, stuffer2nrzi_str, stuffer2nrzi_ready,stuffed_in);
    nrzi        nrzier  (clk, rst_b, stuffer2nrzi_str, stuffer2nrzi_ready, nrzi2dpdm_str, nrzi2dpdm_ready,stuffed_in, stuffed_out);


    // INBOUND PKTS:
    // DPDM --> PROTOCOL FSM

    logic dpdm2nrzi_str, dpdm2nrzi_ready, dpdm2nrzi_done, nrzi2unstuffer_str, nrzi2unstuffer_ready, nrzi2unstuffer_done,
          unstuffer2crc_str, unstuffer2crc_ready, unstuffer2crc_done;

    decoding   decoder   (clk, rst_b, 
                          pkt_out, unstuffer2crc_ready, unstuffer2crc_str, unstuffer2crc_done, 
                          pkt_out_avail, data_good, decoder_ready);

    unstuffing unstuffer (clk, rst_b, 
                          nrzi2unstuffer_str, nrzi2unstuffer_ready, nrzi2unstuffer_done,
                          unstuffer2crc_str, unstuffer2crc_ready, unstuffer2crc_done);

    unnrzi     unnrzier  (clk, rst_b, 
                          dpdm2nrzi_str, dpdm2nrzi_ready, dpdm2nrzi_done, 
                          nrzi2unstuffer_str, nrzi2unstuffer_ready, nrzi2unstuffer_done);

    // I/O
    // DATAPATH <--> [ DPDM ] <--> DEVICE
    dpdm        dpdmer  (clk, rst_b, 
                         nrzi2dpdm_str, nrzi2dpdm_ready, 
                         dpdm2nrzi_str, dpdm2nrzi_ready, 
                         dp_r, dm_r, dp_w, dm_w, 
                         re, dpdm2nrzi_done, stuffed_out);

endmodule: datapath
