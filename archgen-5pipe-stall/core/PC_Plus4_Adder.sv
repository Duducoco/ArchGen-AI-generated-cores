module PC_Plus4_Adder (
    input [31:0] current_pc,
    output [31:0] pc_add_4
);
    assign pc_add_4 = current_pc + 4;
endmodule
