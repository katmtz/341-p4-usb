/*
 * Small test procedure for nrzi module
 */

module nrzi_test;

    logic clk, rst_b;
    bit bstr_in, bstr_in_ready;
    logic [1:0] p_type;
    bit bstr_out, bstr_out_ready;

    nrzi dut (.*);

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        bstr_in_ready = 1'b0;
        bstr_in = 1'b0;
        p_type = 2'b01;
        rst_b = 1'b1;
        #5 rst_b = 1'b0;
        #10 rst_b = 1'b1;
        $display("testing token length...");
        #10 bstr_in_ready = 1'b1;
        #280 bstr_in = 1'b0;
        #20 bstr_in = 1'b1;
        #10 bstr_in_ready = 1'b0;
        #20 $finish;
    end
endmodule    
