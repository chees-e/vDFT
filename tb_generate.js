const pcm = require("pcm");
const fs = require("fs");

let outfile = './DFT_tb.v';
let audiofile = './testC.mp3';
let varname = "data_in";
let start = `//This is an auto-generated file
module DFT_tb ();
    reg clk, rst;
    reg signed [10:0] data_in;
    reg transfer_in;
    reg signed [3:0] p;
    wire [6:0] data_out;
    wire transfer_out;


	DFT DUT(clk, rst, data_in, transfer_in, p, data_out, transfer_out);

	initial begin
		rst = 1'b1;
        transfer_in = 1'b1;
        p = 3'b100; 
        clk = 1'b0; #2;
        clk = 1'b1; #2;
        rst = 1'b0;
        clk = 1'b0; #2; 
`;

let end = `
        $stop;
    end
endmodule
`;

if (process.argv[2]) {
    audiofile = process.argv[2];
}

fs.open(outfile, 'w', (err, file) => {
    if (err) console.log(err);
});

let length = 0;
let samplerate = 44100;
let outtext = start;

pcm.getPcmData(audiofile, { stereo: true, sampleRate: samplerate },
function(sample, channel) {
    if (channel == 0) {
        let bi = Math.round(sample*1000);
        let signed = bi < 0;
        bi = bi.toString(2);
        if (signed) {
            let flipped = ""
            for (let i = 1; i < bi.length; i++) {
                if (bi[i] == "0") {
                    flipped = flipped + "1";
                } else {
                    flipped = flipped + "0";
                }
            }
            //sign extend
            while (flipped.length < 11) {
                flipped = "1" + flipped;
            }
            bi = (parseInt(flipped, 2) + 1).toString(2);
            if (bi.length > 11) {
                bi = bi.subString(1);
            }
        } else {
            while (bi.length < 11) {
                bi = "0" + bi;
            }
        }
        outtext = outtext + `        ${varname} = 11'sb${bi};\n`;
        outtext = outtext + `        clk = 1'b1; #2;\n`;
        outtext = outtext + `        clk = 1'b0; #2;\n`;
    }
    length += 1;
},
function(err, output) {
    if (err) {
        console.log(err);
    }

    outtext = outtext + end;
    fs.writeFile(outfile, outtext, (err) => {
        if (err) console.log(err);
    });
    console.log(`Done converting ${length} data`);
});
