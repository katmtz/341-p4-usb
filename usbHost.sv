`include "prelab.sv"

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

  logic we, dp_out, dm_out;
  assign we = 1'b1; // this signal should come from the fsm but we r not doin that just yet
  assign wires.DP = (we) ? dp_out : 1'bz;
  assign wires.DM = (we) ? dm_out : 1'bz;

  logic ready_in;

  prelab dut (clk, rst_L, pkt, pktInAvail, ready_in, dp_out, dm_out);

endmodule: usbHost
