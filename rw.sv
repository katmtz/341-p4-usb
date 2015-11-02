/*
 * Read/Write FSM:
 * - manages transactions for the protocol fsm & interacts with 
 * the testbench
 */
// Includes
`include "reverser.sv"

// Packet Data Constants
`define OUTPID 8'b11100001
`define INPID 8'b01101001
`define DATAPID 8'b11000011
`define ADDR 7'b1010000
`define ENDP4 4'b0010
`define ENDP8 4'b0001

// Task Type Constants
`define TASK_IDLE 2'b0
`define TASK_READ 2'b01
`define TASK_WRITE 2'b10

typedef enum [1:0] {idle = 2'b00, read = 2'b01, write = 2'b10} task_t; 

module rw_fsm (clk, rst_b,
               task, mempage, data_in, 
               token_pkt_out, data_pkt_out,
               data_to_tb,
               data_avail, ptcl_done, 
               ptcl_success, ptcl_ready,
               task_done, task_success);

    input logic clk, rst_b;
    input logic [1:0] task;
    input logic [15:0] mempage;
    input logic [63:0] data_in;
    input logic ptcl_ready, ptcl_done, ptcl_success;
    output [18:0] token_out;
    output [71:0] data_out; 
    output data_avail, task_done, task_success;

    logic [63:0] data_to_reverse, reversed_data;
    logic send_addr;
    transaction_ctrl ctrl (.*);
    reverser r (clk, rst_b, data_to_reverse, reversed_data);

    // output data
    always_comb
        case(task)
            `TASK_IDLE: begin
                token_out = 19'b0;
                data_to_reverse = 64'b0;
                data_out = 72'b0;
                data_avail = 1'b0;
            end
            `TASK_READ: begin
                if (send_addr) begin
                    token_out = {`OUTPID, `ADDR, `ENDP4};
                    data_to_reverse = {48'b0, mempage};
                    data_out = {`DATAPID, reversed_data};
                    data_avail = 1'b1;
                end else begin
                    token_out = {`INPID, `ADDR, `ENDP8};
                    data_to_reverse = 64'b0;
                    data_out = 72'b0;
                    data_avail = 1'b1;
                end
            `TASK_WRITE: begin
                if (send_addr) begin
                    token_out = {`OUTPID, `ADDR, `ENDP4};
                    data_to_reverse = {48'b0, mempage};
                    data_out = {`DATAPID, reversed_data};
                    data_avail = 1'b1;
                end else begin
                    token_out = {`OUTPID, `ADDR, `ENDP4};
                    data_to_reverse = data_in;
                    data_out = {`DATAPID, reversed_data};
                    data_avail = 1'b1;
                end
            end
        endcase

endmodule: rw_fsm

/*
 * transaction_ctrl:
 * - for either in or out transactions, handles the process of sending
 * an address then either waiting for data to come in or sending data
 * from the tb
 */
module transaction_ctrl (clk, rst_b,
                         task, ptcl_ready,
                         ptcl_done, ptcl_success,
                         send_addr, task_done, task_success);

    input logic clk, rst_b;
    input logic [1:0] task;
    input logic ptcl_ready, ptcl_done, ptcl_success;
    ouput logic send_addr, task_done, task_success;

    enum logic [2:0] {idle = 3'b0, 
                      addr = 3'b001, 
                      data = 3'b010, 
                      success = 3'b011,
                      fail = 3'b100} state, nextState;

    always_comb
        case(state)
            idle: nextState = (task != 2'b0) ? addr : idle;
            addr: nextState = (~ptcl_done) ? addr : (~ptcl_success) ? fail : data;
            data: nextState = (~ptcl_done) ? data : (~ptcl_success) ? fail : success;
            fail: nextState = fail;
            success: nextState = success;
        endcase 

    always_comb begin
        if (state == fail || state == success) begin
            task_done = 1'b1;
            task_success = (state == fail) ? 1'b0 : 1'b1;
        end else begin 
            task_done = 1'b1;
            task_success = 1'b0;
        end
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rsb_b) state <= idle;
        else        state <= nextState;
    end

    assign send_addr = (state == addr);

endmodule: transaction_ctrl
