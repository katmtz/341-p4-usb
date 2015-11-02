module reverser(
    input logic [63:0] data,
    output logic [63:0] reversed);

    always_comb begin
        reversed[0] = data[63];
        reversed[1] = data[62];
        reversed[2] = data[61];
        reversed[3] = data[60];
        reversed[4] = data[59];
        reversed[5] = data[58];
        reversed[6] = data[57];
        reversed[7] = data[56];
        reversed[8] = data[55];
        reversed[9] = data[54];
        reversed[10] = data[53];
        reversed[11] = data[52];
        reversed[12] = data[51];
        reversed[13] = data[50];
        reversed[14] = data[49];
        reversed[15] = data[48];
        reversed[16] = data[47];
        reversed[17] = data[46];
        reversed[18] = data[45];
        reversed[19] = data[44];
        reversed[20] = data[43];
        reversed[21] = data[42];
        reversed[22] = data[41];
        reversed[23] = data[40];
        reversed[24] = data[39];
        reversed[25] = data[38];
        reversed[26] = data[37];
        reversed[27] = data[36];
        reversed[28] = data[35];
        reversed[29] = data[34];
        reversed[30] = data[33];
        reversed[31] = data[32];
        reversed[32] = data[31];
        reversed[33] = data[30];
        reversed[34] = data[29];
        reversed[35] = data[28];
        reversed[36] = data[27];
        reversed[37] = data[26];
        reversed[38] = data[25];
        reversed[39] = data[24];
        reversed[40] = data[23];
        reversed[41] = data[22];
        reversed[42] = data[21];
        reversed[43] = data[20];
        reversed[44] = data[19];
        reversed[45] = data[18];
        reversed[46] = data[17];
        reversed[47] = data[16];
        reversed[48] = data[15];
        reversed[49] = data[14];
        reversed[50] = data[13];
        reversed[51] = data[12];
        reversed[52] = data[11];
        reversed[53] = data[0];
        reversed[54] = data[9];
        reversed[55] = data[8];
        reversed[56] = data[7];
        reversed[57] = data[6];
        reversed[58] = data[5];
        reversed[59] = data[4];
        reversed[60] = data[3];
        reversed[61] = data[2];
        reversed[62] = data[1];
        reversed[63] = data[0];

    end

endmodule: reverser
