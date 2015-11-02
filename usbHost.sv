`include "datapath.sv"

// Write your usb host here.  Do not modify the port list.
module usbHost
  (input logic clk, rst_L,
   usbWires wires);

  /* Tasks needed to be finished to run testbenches */
  logic [98:0] pkt;
  logic pktInAvail;

  task prelabRequest();
      // sends an OUT packet with ADDR=5 and ENDP=4
      // packet should have SYNC and EOP too
      
      $display("Sending an OUT packet....");
      pkt[98:64] = 35'h00c3d0200;
      pkt[63:0] = 64'd0;
      pktInAvail = 1'b1;
      #20 pktInAvail = 1'b0;

      #1000;
      $display("Returning from task prelabRequest");
  endtask: prelabRequest

  task readData
  // host sends memPage to thumb drive and then gets data back from it
  // then returns data and status to the caller
  (input  bit [15:0] mempage, // Page to write
   output bit [63:0] data, // array of bytes to write
   output bit        success);

  endtask: readData

  task writeData
  // Host sends memPage to thumb drive and then sends data
  // then returns status to the caller
  (input  bit [15:0] mempage, // Page to write
   input  bit [63:0] data, // array of bytes to write
   output bit        success);

  endtask: writeData

  // usbHost starts here!!

  // wires to be hooked up to to protocol fsm
  logic [98:0] pkt_from_fsm, pkt_into_fsm;
  logic pkt_from_fsm_avail, pkt_into_fsm_avail, data_good, decoder_ready, encoder_ready, re;
  // end 

  // tri-state assignment
  logic dp_w, dm_w, dp_r, dm_r;

  assign wires.DP = (~re) ? dp_w : 1'bz;
  assign wires.DM = (~re) ? dm_w : 1'bz;
  assign dp_r = wires.DP;
  assign dm_r = wires.DM;

  datapath d (clk, rst_b,
              pkt_from_fsm, pkt_from_fsm_avail,
              pkt_into_fsm, pkt_into_fsm_avail,
              dp_w, dm_w, dp_r, dm_r,
              data_good, decoder_ready, encoder_ready, re);

  // <protocol fsm goes here>

  // <read/write fsm goes here>

endmodule: usbHost
