module ALU (
    input [31:0] operand1,
    input [31:0] operand2,
    input [4:0] ALU_Function,
    output reg [31:0] alu_result,
    output cmp_result
);
    wire signed [31:0] signed_op1 = operand1;
    wire signed [31:0] signed_op2 = operand2;
    always @(*) begin
        case (ALU_Function)
            `ALU_ADD:  alu_result = operand1 + operand2;
            `ALU_SUB:  alu_result = operand1 - operand2;
            `ALU_SLL:  alu_result = operand1 << operand2[4:0];
            `ALU_SRL:  alu_result = operand1 >> operand2[4:0];
            `ALU_SRA:  alu_result = signed_op1 >>> operand2[4:0];
            `ALU_SEQ:  alu_result = (operand1 == operand2) ? 1 : 0;
            `ALU_SNE:  alu_result = (operand1 != operand2) ? 1 : 0;
            `ALU_SLT:  alu_result = (signed_op1 < signed_op2) ? 1 : 0;
            `ALU_SLTU: alu_result = (operand1 < operand2) ? 1 : 0;
            `ALU_XOR:  alu_result = operand1 ^ operand2;
            `ALU_OR:   alu_result = operand1 | operand2;
            `ALU_AND:  alu_result = operand1 & operand2;
            `ALU_SGE:  alu_result = (signed_op1 >= signed_op2) ? 1 : 0;
            `ALU_SGEU: alu_result = (operand1 >= operand2) ? 1 : 0;
            default:    alu_result = 0;
        endcase
    end
    assign cmp_result = alu_result[0];
endmodule
