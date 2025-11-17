module JALR_Adjust (
    input [31:0] addr_in,
    output [31:0] adjusted_addr
);
    assign adjusted_addr = {addr_in[31:1], 1'b0};
endmodule
