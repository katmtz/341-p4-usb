/* test for bitstuffing */
module top;
    logic clk, rst_b;
    bit si, sir, so, sor;

    bitstuffing dut (.clk(clk), .rst_b(rst_b), .bstr_in(si), .bstr_in_ready(sir), .bstr_out(so), .bstr_out_ready(sor));    

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end   

    initial begin
        $monitor("time: %0d  - %0b - valid: %0b", $time, so, sor);
        rst_b = 0;
        #6 rst_b = 1;
        sir = 1;
        si = 1;
        #10 si = 1;
        #70 sir = 0;
        #10 sir = 1;
        #30 si = 0;
        #10 si = 1;
        #20 sir = 0;
        #30 $finish;
    end
endmodule
        
    
