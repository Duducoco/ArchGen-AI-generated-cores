module NextPC_Decision_Unit (
    input non_branch_case, //ensure next_pc_sel hit in execution of jump-inst 
    input cmp_result_in,
    input [2:0] branch_type_in,
    output reg [1:0] next_pc_sel
);
    always @(*) begin
        case (branch_type_in)
            3'b000: next_pc_sel = 2'b00; // No branch
            3'b001: next_pc_sel = cmp_result_in ? 2'b01 & {2{non_branch_case}} : 2'b11 & {2{non_branch_case}}; // Conditional cmp_result_in = 0 -> 11 (pc+4 EX)
            3'b010: next_pc_sel = 2'b01 & {2{non_branch_case}}; // JAL
            3'b011: next_pc_sel = 2'b10 & {2{non_branch_case}}; // JALR
            default: next_pc_sel = 2'b00;
        endcase
    end

endmodule
