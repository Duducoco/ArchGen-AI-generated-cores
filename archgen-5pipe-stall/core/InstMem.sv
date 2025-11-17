`include "config.sv"
`include "constants.sv"

module InstMem (
    input [`TEXT_BITS-3:0] address,
    input clock,
    output [31:0] q
);
    (* nomem2reg *)
    logic [31:0] mem[0:2**(`TEXT_BITS-2)-1];

    assign q = mem[address];

//`ifdef TEXT_HEX
//    initial $readmemh(`TEXT_HEX, mem);
//`endif

endmodule

