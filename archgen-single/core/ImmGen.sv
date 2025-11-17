module ImmGen (
    input [31:0] instruction,
    input [6:0] opcode,
    output reg [31:0] imm_data
);
    always @(*) begin
        case (opcode)
            `OPCODE_OP_IMM, `OPCODE_LOAD, `OPCODE_JALR: 
                imm_data = {{20{instruction[31]}}, instruction[31:20]};
            `OPCODE_LUI, `OPCODE_AUIPC: 
                imm_data = {instruction[31:12], 12'b0};
            `OPCODE_STORE: 
                imm_data = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            `OPCODE_BRANCH: 
                imm_data = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            `OPCODE_JAL: 
                imm_data = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            default: 
                imm_data = 32'b0;
        endcase
    end
endmodule
