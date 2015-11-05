/*
 * Read/Write FSM:
 * - manages transactions for the protocol fsm & interacts with 
 * the testbench
 */
module rw_fsm (clk, rst_b,
               tsk, mempage, data_from_tb,
               tok_pkt_into_ptcl, data_pkt_into_ptcl,
               data_into_ptcl_avail,
               data_from_ptcl, data_from_ptcl_avail,
               transaction, transaction_done, transaction_success,
               data_to_tb, task_done, task_success);

    input logic clk, rst_b;
    input logic [1:0] tsk;
    input logic [15:0] mempage;
    input logic [63:0] data_from_tb;
    input logic [63:0] data_from_ptcl;
    input logic data_from_ptcl_avail;
    input logic transaction_done, transaction_success;
    output logic [18:0] tok_pkt_into_ptcl;
    output logic [71:0] data_pkt_into_ptcl;
    output logic [63:0] data_to_tb; 
    output logic [1:0] transaction;
    output logic data_into_ptcl_avail;
    output logic task_done, task_success;

    logic [63:0] data_to_reverse, reversed_data, read_data;
    logic send_addr;
    transaction_ctrl ctrl (.*);
    reverser r (data_to_reverse, reversed_data);

    // output data
    always_comb
        case(tsk)
            `TASK_IDLE: begin
                tok_pkt_into_ptcl = 19'b0;
                data_to_reverse = 64'b0;
                data_pkt_into_ptcl = 72'b0;
            end
            `TASK_READ: begin
                if (send_addr) begin
                    tok_pkt_into_ptcl = {`OUTPID, `ADDR, `ENDP4};
                    data_to_reverse = {mempage, 48'b0};
                    data_pkt_into_ptcl = {`DATAPID, reversed_data};
                end else begin
                    tok_pkt_into_ptcl = {`INPID, `ADDR, `ENDP8};
                    data_to_reverse = 64'b0;
                    data_pkt_into_ptcl = 72'b0;
                end
            end
            `TASK_WRITE: begin
                if (send_addr) begin
                    tok_pkt_into_ptcl = {`OUTPID, `ADDR, `ENDP4};
                    data_to_reverse = {mempage,48'b0};
                    data_pkt_into_ptcl = {`DATAPID, reversed_data};
                end else begin
                    tok_pkt_into_ptcl = {`OUTPID, `ADDR, `ENDP8};
                    data_to_reverse = data_from_tb;
                    data_pkt_into_ptcl = {`DATAPID, reversed_data};
                end
            end
        endcase

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) read_data <= 64'b0;
        else        read_data <= (transaction_done && transaction_success) ? data_from_ptcl : read_data;
    end 

    reverser d2tb(read_data, data_to_tb);

endmodule: rw_fsm

/*
 * transaction_ctrl:
 * - for either in or out transactions, handles the process of sending
 * an address then either waiting for data to come in or sending data
 * from the tb
 */
module transaction_ctrl (clk, rst_b, tsk,
                         transaction_done, transaction_success,
                         send_addr, task_done, task_success,
			             data_into_ptcl_avail, transaction);

    input logic clk, rst_b;
    input logic [1:0] tsk;
    input logic transaction_done, transaction_success;
    output logic send_addr, task_done, task_success;
    output logic data_into_ptcl_avail;
    output logic [1:0] transaction;

    enum logic [2:0] {idle = 3'b0, 
                      addr = 3'b001, 
                      data = 3'b010, 
                      success = 3'b011,
                      fail = 3'b100} state, nextState;

    always_comb
        case(state)
            idle: nextState = (tsk != 2'b0) ? addr : idle;
            addr: nextState = (~transaction_done) ? addr : (~transaction_success) ? fail : data;
            data: nextState = (~transaction_done) ? data : (~transaction_success) ? fail : success;
            fail: nextState = (tsk != 2'b0) ? fail : idle;
            success: nextState = (tsk != 2'b0) ? success : idle;
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

    always_comb begin
        transaction = 0;
        if (state == addr || tsk == `TASK_WRITE)
            transaction = 2'b10;
        if (state == data && tsk == `TASK_READ)
            transaction = 2'b01;
    end

    always_ff @(posedge clk, negedge rst_b) begin
        if (~rst_b) state <= idle;
        else        state <= nextState;
    end

    assign send_addr = (state == addr);
    assign data_into_ptcl_avail = tsk != 0;

endmodule: transaction_ctrl
