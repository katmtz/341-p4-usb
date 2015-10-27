module encoder(clk, rst_b,
               pkt, pkt_ready,
               bstr, bstr_ready);



module pktToSerial(clk, rst_b,
                   pkt, pkt_ready,
                   bstr, bstr_ready);

endmodule: pktToSerial

module crc5(clk, rst_b,
            bstr, crc);

    input logic clk, rst_b;
    input bit bstr;
    output bit [4:0] crc;

endmodule: crc5

module crc16(clk, rst_b,
             bstr, crc);

    input logic clk, rst_b;
    input bit bstr;
    output bit [15:0] crc;

endmodule: crc16 
