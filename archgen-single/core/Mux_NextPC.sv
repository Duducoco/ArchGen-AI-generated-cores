module Mux_NextPC (
    input [31:0] input0,
    input [31:0] input1,
    input [31:0] input2,
    input [1:0] select,
    output reg [31:0] next_pc
);
    always @(*) begin
        case (select)
            2'b00: next_pc = input0;  // PC+4
            2'b01: next_pc = input1;  // Branch target
            2'b10: next_pc = input2;  // JALR target
            default: next_pc = input0;
        endcase
    end
endmodule
