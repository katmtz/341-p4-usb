// module includes
`include "datapath.sv"
`include "protocol.sv"
`include "rw.sv"

// Write your usb host here.  Do not modify the port list.
module usbHost
  (input logic clk, rst_L,
   usbWires wires);

  /* Tasks needed to be finished to run testbenches */
  logic [98:0] prelab_pkt;
  logic prelab_pktInAvail;

  task prelabRequest();
      // sends an OUT packet with ADDR=5 and ENDP=4
      // packet should have SYNC and EOP too
      
      $display("Sending an OUT packet....");
      prelab_pkt[98:64] = 35'h00c3d0200;
      prelab_pkt[63:0] = 64'd0;
      prelab_pktInAvail = 1'b1;
      #20 prelab_pktInAvail = 1'b0;

      #1000;
      $display("Returning from task prelabRequest");
  endtask: prelabRequest

  // read task wires
  logic [15:0] rw_mempage;
  logic [63:0] rw_data_to_tb, rw_data_in;
  logic [1:0] rw_task;
  logic rw_task_done, rw_task_success;
  logic rst_b, rst_bb;

  assign rst_b = (rst_L && rst_bb);

  task readData
  // host sends memPage to thumb drive and then gets data back from it
  // then returns data and status to the caller
  (input  bit [15:0] mempage, // Page to write
   output bit [63:0] data, // array of bytes to write
   output bit        success);

    $display("readData called with mempage: %0h and data: %0h", mempage, data);
    rst_bb <= 1'b0;
    #5 rst_bb <= 1'b1;

    // Hooking up task inputs to rw fsm
    rw_mempage <= mempage;
    data <= rw_data_to_tb;
    success <= rw_task_success;
    rw_task <= `TASK_READ;

    // Let task finish
//    wait (rw_task_done);
    #1000; 

    $display("Task success: %0b, returning.", success);
    // return;
  endtask: readData

  task writeData
  // Host sends memPage to thumb drive and then sends data
  // then returns status to the caller
  (input  bit [15:0] mempage, // Page to write
   input  bit [63:0] data, // array of bytes to write
   output bit        success);
    
    $display("writeData called with mempage: %0h and data: %0h", mempage, data);
    rst_bb <= 1'b0;
    #5 rst_bb <= 1'b1;
    
    // Hooking up inputs
    rw_mempage <= mempage;
    rw_data_in <= data;
    success <= rw_task_success;
    rw_task <= `TASK_WRITE;

    // Let task finish
//    wait (rw_task_done);
    #1000;

    $display("Task success: %0b, returning.", success);

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
              pkt_into_fsm, pkt_into_fsm_avail, //protocol=fsm
              dp_w, dm_w, dp_r, dm_r,
              data_good, decoder_ready, encoder_ready, re);

  // Protocol/RW wires
  logic [18:0] token_pkt_in;
  logic [71:0] data_pkt_in;
  logic [63:0] ptcl_data;
  logic ptcl_done, ptcl_success, ptcl_read;

  protocol p (token_pkt_in, data_pkt_in, data_avail,
              pkt_into_fsm, data_good, pkt_into_fsm_avail,
              encoder_ready, pkt_from_fsm, pkt_from_fsm_avail,
              ptcl_done, ptcl_success, ptcl_ready, ptcl_data,
              clk, rst_b);
            
  rw_fsm rw (clk, rst_b,
             rw_task, rw_mempage, rw_data_in,
             token_pkt_in, data_pkt_in,
             rw_data_to_tb, ptcl_data,
             data_avail, ptcl_done,
             ptcl_success, ptcl_ready,
             rw_task_done, rw_task_success);

endmodule: usbHost
