// Write your usb host here.  Do not modify the port list.
module usbHost
  (input logic clk, rst_L,
   usbWires wires);

  /* Tasks needed to be finished to run testbenches */

  task prelabRequest(
    output logic [98:0] pkt,
    output bit pktInAvail);
  // sends an OUT packet with ADDR=5 and ENDP=4
  // packet should have SYNC and EOP too

      pkt[98:64] = 35'h0187a040;
      pkt[63:0] = 64'd0;
      pktInAvail = 1'b1;//'

      #1000;
      return;

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


endmodule: usbHost
