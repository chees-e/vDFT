module getmax(input [2375:0] in, input [26:0] threshold, output [6:0] out);
    //Stores the intermediate max values
    //[26:0] contains the max value out of all
    wire [2402:0] maxvalues;
    //[6:0] stores the index of highest amplitude
    //Note, indices go from high -> low
    wire [622:0] index;
    //Stores the reference indices
    //88 => A0
    //1 => C8
    wire [615:0] indices = {7'h58, 7'h57, 7'h56, 7'h55, 7'h54, 7'h53, 7'h52, 7'h51, 7'h50, 
                            7'h4f, 7'h4e, 7'h4d, 7'h4c, 7'h4b, 7'h4a, 7'h49, 7'h48, 7'h47, 7'h46, 7'h45, 7'h44, 7'h43, 7'h42, 7'h41, 7'h40, 
                            7'h3f, 7'h3e, 7'h3d, 7'h3c, 7'h3b, 7'h3a, 7'h39, 7'h38, 7'h37, 7'h36, 7'h35, 7'h34, 7'h33, 7'h32, 7'h31, 7'h30, 
                            7'h2f, 7'h2e, 7'h2d, 7'h2c, 7'h2b, 7'h2a, 7'h29, 7'h28, 7'h27, 7'h26, 7'h25, 7'h24, 7'h23, 7'h22, 7'h21, 7'h20, 
                            7'h1f, 7'h1e, 7'h1d, 7'h1c, 7'h1b, 7'h1a, 7'h19, 7'h18, 7'h17, 7'h16, 7'h15, 7'h14, 7'h13, 7'h12, 7'h11, 7'h10, 
                            7'hf, 7'he, 7'hd, 7'hc, 7'hb, 7'ha, 7'h9, 7'h8, 7'h7, 7'h6, 7'h5, 7'h4, 7'h3, 7'h2, 7'h1 };
    

    assign maxvalues[2402:2376] = 0;
    assign index[622:616] = 0;


    genvar i;
    generate
        for (i = 89; i > 1; i = i - 1) begin : for_compare
            compare compare(in[(i - 1) * 27 - 1 : (i - 2) * 27], maxvalues[i * 27 - 1 : (i - 1) * 27], maxvalues[(i - 1) * 27 - 1 : (i - 2) * 27]);
        end
    endgenerate

    // max: maxvalues[26:0];
    genvar j;
    generate
        for (i = 89; i > 1; i = i - 1) begin : for_index
            getindex getindex(maxvalues[26:0], in[(i - 1) * 27 - 1 : (i - 2) * 27], index[i * 7 - 1 : (i - 1) * 7], indices[(i - 1) * 7 - 1 : (i - 2) * 7], threshold, index[(i - 1) * 7 - 1 : (i - 2) * 7]);
        end
    endgenerate

    assign out = index[6:0];
endmodule

module compare(input [26:0] a, input [26:0] b, output [26:0] out);
    assign out = a > b ? a : b;
endmodule

module getindex (input [26:0] max, input [26:0] in, input [6:0] prev, input [6:0] curr, input [26:0] threshold, output [6:0] out);
    assign out = (max == in && max > threshold)? curr : prev;
endmodule