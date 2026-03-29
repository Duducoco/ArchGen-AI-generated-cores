`include "config.sv"
`include "constants.sv"

module DataMem (
	input [`DATA_BITS-3:0] address, //17-3:0, = 15bits
	input [3:0] byteena, // 4 bits for byte enable, each bit corresponds to a byte in the word
	input clock,
	input [31:0] data,
	input wren,
	output [31:0] q
);

    (* nomem2reg *)
    logic [31:0] mem[0:2**(`DATA_BITS-2)-1];

    assign q = mem[address];

    // Use 'always' instead of 'always_ff' to allow initial $readmemh coexistence
    always @(posedge clock)
        if (wren) begin
            if (byteena[0]) mem[address][0+:8] <= data[0+:8];
            if (byteena[1]) mem[address][8+:8] <= data[8+:8];
            if (byteena[2]) mem[address][16+:8] <= data[16+:8];
            if (byteena[3]) mem[address][24+:8] <= data[24+:8];
        end

`ifdef DATA_HEX
    initial $readmemh(`DATA_HEX, mem);
`endif

endmodule