module NextPC_Decision_Unit (
    input cmp_result_in,
    input [2:0] branch_type_in,
    output reg [1:0] next_pc_sel
);
    always @(*) begin
        case (branch_type_in)
            3'b000: next_pc_sel = 2'b00; // No branch
            3'b001: next_pc_sel = cmp_result_in ? 2'b01 : 2'b00; // Conditional
            3'b010: next_pc_sel = 2'b01; // JAL
            3'b011: next_pc_sel = 2'b10; // JALR
            default: next_pc_sel = 2'b00;
        endcase
    end
endmodule
