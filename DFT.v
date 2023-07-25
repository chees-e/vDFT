/*
* Module DFT: Discrete Fourier Transform
* -> clk: clock
* -> rst: reset (active high)
* -> data_in: audio data (x_n, [-1000, 1000])
* -> transfer_in: input transfer enable (read data during high)
* -> p: number of output per second
* <- data_out: index of the highest sum in the frequency domain
* <- transfer_out: a high pulse to indicate when the output is ready to be read 
*/
module DFT (clk, rst, data_in, transfer_in, p, data_out, transfer_out);
    input clk; 
    input rst; 
    input signed [10:0] data_in;
    input transfer_in; 
    input  [2:0] p; 
    output [6:0] data_out;
    output transfer_out;
    /***********
    * Bus init *
    ************/
    // Sine/cosine bus: holds the outputs for the current sinx blocks
    // Width: 11 * 88 = 968 bits
    wire [967:0] sin_bus;
    wire [967:0] cos_bus;

    // Sum buses: These will culumatively add values from sin/cos bus
    // Width: 27 * 88 = 2376 bits 
    wire [2375:0] sin_sum;
    wire [2375:0] cos_sum; 
    // sin^2 + cos^2 shifted
    wire [2375:0] abs_sum; 
    // register to hold abs_sum so the module can keep computing
    wire [2375:0] abs_sum_reg;
    // number of samples per output
    wire [19:0] output_samples = 16'hAC44 >> (p - 1);

    /************************
    * Submodules controller *
    *************************/    
    // Counters: n
    reg [967:0] n;
    // Adjusted n (mod N/k)
    wire [967:0] n_adj;
    // counter that doesn't reset: used to determine when output should be transmitted
    reg [19:0] counter;
    // sum_reg enable
    reg en_out;
    // trans_out signal
    reg trans_out;
    // 1 clk cycle delay for sum_reg to hold data before transfer out
    reg delay_out;
    // reset for sinx (called during reset and at the end of every output)
    reg rst_out;

    always @(posedge clk) begin
        // Reset
        if (rst) begin
            n <= 0;
            rst_out <= 1;
            counter <= 0;
        end else begin
            rst_out <= 0;
            if (transfer_in) begin
                // Add 1 to n
                n <= n_adj + {88{11'b1}};
                counter <= counter + 1;
                // set trans_out to low after 1 cycle
                if (trans_out) begin
                    trans_out <= 0;
                end
                // begin transfer after 1 cycle delay
                if (delay_out) begin
                    delay_out <= 0;
                    trans_out <= 1;
                end
                // enable sum_reg and wait 1 cycle before transfer
                if (en_out) begin
                    en_out <= 0;
                    delay_out <= 1;
                end
                // reset n per output
                if (counter >= output_samples) begin
                    counter <= 0;
                    n <= 0;
                    en_out <= 1;
                    rst_out <= 1;
                end
            end
        end
    end

    /**********
    * Outputs *
    ***********/    
    // Threshold (default=0): An output is given only if it is greater than this 
    wire [26:0] threshold = 0;
    wire [6:0] index_out;
    // sum register to remember abs_sum
    vDFFE #(2376) sum_reg (clk, en_out, abs_sum, abs_sum_reg);
    // calculate the index with the highest value 
    getmax getmax (abs_sum_reg, threshold, index_out);
    assign data_out = index_out;
    assign transfer_out = trans_out;

    /***************
    * Sine and sum *
    ****************/    
    // gamma a', b', c
    wire [2375:0] ya_bus = {27'h1b, 27'h1e, 27'h22, 27'h26, 27'h2b, 27'h30, 27'h36, 27'h3c, 27'h44, 27'h4c, 27'h55, 27'h60, 27'h6c, 27'h79, 27'h88, 27'h98, 27'hab, 27'hc0, 27'hd7, 27'hf2, 27'h10f, 27'h130, 27'h156, 27'h17f, 27'h1ae, 27'h1e3, 27'h21e, 27'h261, 27'h2ab, 27'h2ff, 27'h35d, 27'h3c6, 27'h43c, 27'h4c1, 27'h556, 27'h5fd, 27'h6b9, 27'h78c, 27'h879, 27'h982, 27'haac, 27'hbfb, 27'hd73, 27'hf18, 27'h10f1, 27'h1304, 27'h1559, 27'h17f6, 27'h1ae5, 27'h1e30, 27'h21e3, 27'h2609, 27'h2ab2, 27'h2fec, 27'h35ca, 27'h3c60, 27'h43c6, 27'h4c12, 27'h5563, 27'h5fd8, 27'h6b94, 27'h78c1, 27'h878b, 27'h9824, 27'haac6, 27'hbfaf, 27'hd729, 27'hf182, 27'h10f15, 27'h13048, 27'h1558b, 27'h17f5f, 27'h1ae52, 27'h1e305, 27'h21e2a, 27'h2608f, 27'h2ab16, 27'h2febe, 27'h35ca4, 27'h3c608, 27'h43c56, 27'h4c121, 27'h5562c, 27'h5fd7c, 27'h6b946, 27'h78c11, 27'h878ac, 27'h98240};
    wire [2375:0] yb_bus = {27'ha87a, 27'hb286, 27'hbd1f, 27'hc855, 27'hd447, 27'he0e6, 27'hee41, 27'hfc68, 27'h10b6b, 27'h11b58, 27'h12c31, 27'h13e05, 27'h150f3, 27'h164fc, 27'h17a3e, 27'h190ba, 27'h1a88f, 27'h1c1cc, 27'h1dc82, 27'h1f8e0, 27'h216e5, 27'h236b0, 27'h25862, 27'h27c1a, 27'h2a1e7, 27'h2c9f8, 27'h2f46c, 27'h32164, 27'h3510e, 27'h38389, 27'h3b905, 27'h3f1b0, 27'h42dba, 27'h46d61, 27'h4b0c5, 27'h4f824, 27'h543cd, 27'h593ef, 27'h5e8d9, 27'h642d8, 27'h6a21b, 27'h70712, 27'h77219, 27'h7e36f, 27'h85b83, 27'h8dab2, 27'h96189, 27'h9f048, 27'ha879a, 27'hb27de, 27'hbd1b1, 27'hc85a0, 27'hd4447, 27'he0e33, 27'hee422, 27'hfc6cf, 27'h10b706, 27'h11b574, 27'h12c303, 27'h13e0a0, 27'h150f35, 27'h164fcc, 27'h17a372, 27'h190b3f, 27'h1a887e, 27'h1c1c67, 27'h1dc854, 27'h1f8dae, 27'h216dfd, 27'h236ae8, 27'h258607, 27'h27c140, 27'h2a1e69, 27'h2c9f99, 27'h2f46d4, 27'h32167e, 27'h3510fb, 27'h3838ce, 27'h3b90a8, 27'h3f1b5c, 27'h42dc09, 27'h46d5cf, 27'h4b0c0d, 27'h4f827f, 27'h543cd3, 27'h593f22, 27'h5e8db8, 27'h642d0c};
    wire [26:0] yc = 25'hceb4e;
    // N/k values, used to reset n
    wire [967:0] NoverK = {
        11'h644, 11'h5e9, 11'h595, 11'h545, 11'h4f9, 11'h4b1, 11'h46e, 11'h42e, 11'h3f2, 11'h3ba, 11'h384, 
        11'h352, 11'h322, 11'h2f5, 11'h2ca, 11'h2a2, 11'h27c, 11'h259, 11'h237, 11'h217, 11'h1f9, 11'h1dd, 
        11'h1c2, 11'h1a9, 11'h191, 11'h17a, 11'h165, 11'h151, 11'h13e, 11'h12c, 11'h11b, 11'h10c, 11'hfd, 
        11'hee, 11'he1, 11'hd4, 11'hc8, 11'hbd, 11'hb3, 11'ha9, 11'h9f, 11'h96, 11'h8e, 11'h86, 
        11'h7e, 11'h77, 11'h71, 11'h6a, 11'h64, 11'h5f, 11'h59, 11'h54, 11'h50, 11'h4b, 11'h47, 
        11'h43, 11'h3f, 11'h3c, 11'h38, 11'h35, 11'h32, 11'h2f, 11'h2d, 11'h2a, 11'h28, 11'h26, 
        11'h23, 11'h21, 11'h20, 11'h1e, 11'h1c, 11'h1b, 11'h19, 11'h18, 11'h16, 11'h15, 11'h14, 
        11'h13, 11'h12, 11'h11, 11'h10, 11'hf, 11'he, 11'hd, 11'hd, 11'hc, 11'hb, 11'hb
    };

    genvar i;
    generate
        for (i = 88; i > 0; i = i - 1) begin : for_sin
            sinx sin (
                data_in, 
                n_adj[i * 11 - 1: (i - 1) * 11], 
                ya_bus[i * 27 - 1: (i - 1) * 27] << (2 * p), 
                yb_bus[i * 27 - 1: (i - 1) * 27] << p, 
                yc, 
                (NoverK[i * 11 - 1 : (i - 1) * 11] << 1) >> p,
                sin_bus[i * 11 - 1 : (i - 1) * 11]);

            sinx cos (
                data_in, 
                n_adj[i * 11 - 1: (i - 1) * 11] + (NoverK[i * 11 - 1 : (i - 1) * 11] >> (p + 1)), 
                ya_bus[i * 27 - 1: (i - 1) * 27] << (2 * p), 
                yb_bus[i * 27 - 1: (i - 1) * 27] << p, 
                yc, 
                (NoverK[i * 11 - 1 :  (i - 1) * 11] << 1) >> p,
                cos_bus[i * 11 - 1 :  (i - 1) * 11]);
        end
    endgenerate
    // genvar j;
    // generate
    //     for (j = 88; j > 0; j = j - 1) begin : for_cos
    //         sinx cos (
    //             data_in, 
    //             n_adj[j * 11 - 1: (j - 1) * 11] + (NoverK[j * 11 - 1 : (j - 1) * 11] >> (p + 1)), 
    //             ya_bus[j * 25 - 1: (j - 1) * 25] << (2 * p), 
    //             yb_bus[j * 25 - 1: (j - 1) * 25] << p, 
    //             yc, 
    //             NoverK[j * 11 - 1 :  (j - 1) * 11] >> (p - 1),
    //             cos_bus[j * 11 - 1 :  (j - 1) * 11]);
    //     end
    // endgenerate
    //sin addition
    genvar j;
    generate
        for (j = 88; j > 0; j = j - 1) begin : for_sinadd
            sineadd sinadd (
                clk, 
                rst_out, 
                transfer_in, 
                sin_bus[j * 11 - 1 : (j - 1) * 11], 
                sin_sum[j * 27 - 1 : (j - 1) * 27], 
                sin_sum[j * 27 - 1 : (j - 1) * 27]);

            sineadd cosadd (
                clk, 
                rst_out, 
                transfer_in, 
                cos_bus[j * 11 - 1 : (j - 1) * 11], 
                cos_sum[j * 27 - 1 : (j - 1) * 27], 
                cos_sum[j * 27 - 1 : (j - 1) * 27]);
        end
    endgenerate
    //cos addition
    // genvar l;
    // generate
    //     for (l = 88; l > 0; l = l - 1) begin : for_cosadd
    //         sineadd cosadd (
    //             clk, 
    //             rst_out, 
    //             transfer_in, 
    //             cos_bus[l * 11 - 1 : (l - 1) * 11], 
    //             cos_sum[l * 27 - 1 : (l - 1) * 27], 
    //             cos_sum[l * 27 - 1 : (l - 1) * 27]);
    //     end
    // endgenerate
    //abs calculation
    genvar m;
    generate
        for (m = 88; m > 0; m = m - 1) begin : for_abssum
            getabssum getabssum (
                sin_sum[m * 27 - 1 : (m - 1) * 27], 
                cos_sum[m * 27 - 1 : (m - 1) * 27], 
                abs_sum[m * 27 - 1 : (m - 1) * 27]);
        end
    endgenerate
    //n adjustment;
    genvar o;
    generate
        for (o = 88; o > 0; o = o - 1) begin : for_adjn
            resetn resetn (
                n[o * 11 - 1 : (o - 1) * 11], 
                NoverK[o * 11 - 1 : (o - 1) * 11], 
                n_adj[o * 11 - 1 : (o - 1) * 11]);
        end
    endgenerate  
endmodule

/*
* Module sinx: sin times xn
* -> xn: x_n, current audio data
* -> n: counter
* -> ya: gamma a' (coefficients for approximation)
* -> yb: gamma b' 
* -> yc: gamma c
* -> NoverK: N/K for this
* <- out: 11 bit product
*/module sinx(xn, n, ya, yb, yc, NoverK, out);
    input signed [10:0] xn; 
    input [10:0] n; 
    input [26:0] ya, yb, yc; 
    input [10:0] NoverK;
    output signed [10:0] out;
    // Note: N is 11 bits now to compensate for cosine which could go up to and over N/k

    // adj_n will compensate for cosine overflow (cond1) and second half of sine (cond2)
    wire [10:0] adj_n = n > NoverK ? (n - NoverK) : (n > (NoverK >> 1) ? (n - NoverK >> 1) : n);

    // compute n^2
    wire [19:0] nsqr = adj_n * adj_n;
    // approximate sign
    wire signed [24:0] sin = -ya * nsqr + yb * adj_n - yc;
    // multiply by x_n
    wire signed [34:0] product = sin * xn;
    // obtain output
    assign out = (n <= NoverK && n > (NoverK >> 1)) ? -product[34:24] : product[34:24];
endmodule

//register
module vDFFE(clk, en, in, out);
    parameter n = 1;
    input clk, en;
    input [n-1:0] in;
    output [n-1:0] out;
    reg [n-1:0] out;
    wire [n-1:0] next_out; 

    assign next_out = en ? in : out;

    always @(posedge clk)
        out = next_out;
endmodule

//signed adder
module sineadd(clk, rst, en, in, sum, out);
    input clk, rst, en;
    input [10:0] in;
    input signed [26:0] sum;
    output [26:0] out;
    reg [26:0] out;
    wire [26:0] next_out; 

    //extended input  
    wire signed [26:0] exin = {{16{in[10]}}, in[10:0]};
    assign next_out = rst ? 27'b0 : (en ? exin + sum : out);

    always @(posedge clk)
        out = next_out;
endmodule

module getabssum(sin_sum, cos_sum, abs_sum);
    input signed [26:0] sin_sum, cos_sum;
    output [26:0] abs_sum;

    wire [53:0] sqr =  cos_sum * cos_sum + sin_sum * sin_sum;
    assign abs_sum = sqr[44:18];
endmodule

module resetn(n, NoverK, n_adj);
    input [10:0] n;
    input [10:0] NoverK;
    output [10:0] n_adj;

    assign n_adj = n > NoverK ? 0 : n;
endmodule



