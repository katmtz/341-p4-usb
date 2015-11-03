/*
 * Read/Write FSM:
 * - manages transactions for the protocol fsm & interacts with 
 * the testbench
 */
// Includes
`include "reverser.sv"

// Packet Data Constants
`define OUTPID 8'b10000111
`define INPID 8'b10010110
`define DATAPID 8'b11000011
`define ADDR 7'b1010000
`define ENDP4 4'b0010
`define ENDP8 4'b0001

// Task Type Constants
`define TASK_IDLE 2'b0
`define TASK_READ 2'b01
`define TASK_WRITE 2'b10

module rw_fsm (clk, rst_b,
               tsk, mempage, data_in, 
               token_pkt_out, data_pkt_out,
               data_to_tb, ptcl_data, pkt_sent,
               data_avail, ptcl_done, 
               ptcl_success, transaction,
               task_done, task_success);

    input logic clk, rst_b;
    input logic [1:0] tsk;
    input logic [15:0] mempage;
    input logic [63:0] data_in;
    input logic [63:0] ptcl_data;
    input logic pkt_sent, ptcl_done, ptcl_success;
    output logic [18:0] token_pkt_out;
    output logic [71:0] data_pkt_out;
    output logic [63:0] data_to_tb; 
    output logic [1:0] transaction;
    output logic data_avail, task_done, task_success;

    logic [63:0] data_to_reverse, reversed_data, read_data;
    logic send_addr;
    transaction_ctrl ctrl (.*);
    reverser r (data_to_reverse, reversed_data);

    // output data
    always_comb
        case(tsk)
            `TASK_IDLE: begin
                token_pkt_out = 19'b0;
                data_to_reverse = 64'b0;
                data_pkt_out = 72'b0;
            end
            `TASK_READ: begin
                if (send_addr) begin
                    token_pkt_out = {`OUTPID, `ADDR, `ENDP4};
                    data_to_reverse = {mempage, 48'b0};
                    data_pkt_out = {`DATAPID, reversed_data};
                end else begin
                    token_pkt_out = {`INPID, `ADDR, `ENDP8};
                    data_to_reverse = 64'b0;
                    data_pkt_out = 72'b0;
                end
            end
            `TASK_WRITE: begin
                if (send_addr) begin
                    token_pkt_out = {`OUTPID, `ADDR, `ENDP4};
                    data_to_reverse = {mempage,48'b0};
                    data_pkt_out = {`DATAPID, reversed_data};
                end else begin
                    token_pkt_out = {`OUTPID, `ADDR, `ENDP8};
                    data_to_reverse = data_in;
                    data_pkt_out = {`DATAPID, reversed_data};
                end
            end
        endcase

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) read_data <= 64'b0;
        else        read_data <= (ptcl_done && ptcl_success) ? ptcl_data : read_data;
    end 

    reverser d2tb(read_data, data_to_tb);

endmodule: rw_fsm

/*
 * transaction_ctrl:
 * - for either in or out transactions, handles the process of sending
 * an address then either waiting for data to come in or sending data
 * from the tb
 */
module transaction_ctrl (clk, rst_b,
                         tsk, pkt_sent,
                         ptcl_done, ptcl_success,
                         send_addr, task_done, task_success,
			             data_avail, transaction);

    input logic clk, rst_b;
    input logic [1:0] tsk;
    input logic pkt_sent, ptcl_done, ptcl_success;
    output logic send_addr, task_done, task_success;
    output logic data_avail;
    output logic [1:0] transaction;

    enum logic [2:0] {idle = 3'b0, 
                      addr = 3'b001, 
                      data = 3'b010, 
                      success = 3'b011,
                      fail = 3'b100} state, nextState;

    enum logic {in, out} transState;

    always_comb
        case(state)
            idle: nextState = (tsk != 2'b0) ? addr : idle;
            addr: nextState = (~ptcl_done) ? addr : (~ptcl_success) ? fail : data;
            data: nextState = (~ptcl_done) ? data : (~ptcl_success) ? fail : success;
            fail: nextState = fail;
            success: nextState = success;
        endcase

    always_comb 
        case(state)
            addr: transaction = transState;
            data: transaction = transState;
            default: transaction = 0;
        endcase 

    always_comb begin
        if (state == fail || state == success) begin
            task_done = 1'b1;
            task_success = (state == fail) ? 1'b0 : 1'b1;
        end else begin 
            task_done = 1'b0;
            task_success = 1'b0;
        end
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) state <= idle;
        else        state <= nextState;
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) transState <= out;
        else        transState <= (pkt_sent && tsk == `TASK_READ) ? in : transState;
    end

    assign send_addr = (state == addr);
    assign data_avail = (state == addr || state == data);

endmodule: transaction_ctrl
