module PC_PlusImm_Adder (
    input [31:0] pc_in,
    input [31:0] imm_in,
    output [31:0] branch_target
);
    assign branch_target = pc_in + imm_in;
endmodule
