module Mux_ALUSrc1 (
    input [31:0] input0,
    input [31:0] input1,
    input select,
    output reg [31:0] out
);
    always @(*) begin
        out = select ? input1 : input0;
    end
endmodule
