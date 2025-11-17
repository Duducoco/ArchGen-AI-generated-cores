module Controller (
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    input jal_one_regfile_write_eanble,
    output reg [4:0] ALU_Function,
    output reg ALUSrc1,
    output reg ALUSrc2,
    output reg [2:0] WriteBack_Sel,
    output reg RegWrite,
    output reg MemRead,
    output reg MemWrite,
    output reg [2:0] BranchType
);
    always @(*) begin
        // Default values
        ALU_Function = `ALU_ADD;
        ALUSrc1 = 0;
        ALUSrc2 = 0;
        WriteBack_Sel = `CTL_WRITEBACK_ALU;
        RegWrite = `OFF;
        MemRead = `OFF;
        MemWrite = `OFF;
        BranchType = 3'b000; // CTL_BRANCH_NONE
        case (opcode)
            `OPCODE_OP: begin
                RegWrite = `ON;
                case (funct3)
                    `FUNCT3_ALU_ADD_SUB: ALU_Function = (funct7[5]) ? `ALU_SUB : `ALU_ADD;
                    `FUNCT3_ALU_SLT: ALU_Function = `ALU_SLT;
                    `FUNCT3_ALU_SLTU: ALU_Function = `ALU_SLTU;
                    `FUNCT3_ALU_SLL: ALU_Function = `ALU_SLL;
                    `FUNCT3_ALU_SHIFTR: ALU_Function = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                    `FUNCT3_ALU_XOR: ALU_Function = `ALU_XOR;
                    `FUNCT3_ALU_OR: ALU_Function = `ALU_OR;
                    `FUNCT3_ALU_AND: ALU_Function = `ALU_AND;
                endcase
            end
            `OPCODE_OP_IMM: begin
                RegWrite = `ON;
                ALUSrc2 = `ON;
                case (funct3)
                    `FUNCT3_ALU_ADD_SUB: ALU_Function = `ALU_ADD;
                    `FUNCT3_ALU_SLT: ALU_Function = `ALU_SLT;
                    `FUNCT3_ALU_SLTU: ALU_Function = `ALU_SLTU;
                    `FUNCT3_ALU_XOR: ALU_Function = `ALU_XOR;
                    `FUNCT3_ALU_OR: ALU_Function = `ALU_OR;
                    `FUNCT3_ALU_AND: ALU_Function = `ALU_AND;
                    `FUNCT3_ALU_SLL: ALU_Function = `ALU_SLL;
                    `FUNCT3_ALU_SHIFTR: ALU_Function = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                endcase
            end
            `OPCODE_LUI: begin
                RegWrite = `ON;
                ALUSrc2 = `ON;
                WriteBack_Sel = `CTL_WRITEBACK_IMM;
            end
            `OPCODE_AUIPC: begin
                RegWrite = `ON;
                ALUSrc1 = `ON;
                ALUSrc2 = `ON;
            end
            `OPCODE_LOAD: begin
                RegWrite = `ON;
                ALUSrc2 = `ON;
                MemRead = `ON;
                WriteBack_Sel = `CTL_WRITEBACK_DATA;
            end
            `OPCODE_STORE: begin
                ALUSrc2 = `ON;
                MemWrite = `ON;
            end
            `OPCODE_BRANCH: begin
                case (funct3)
                    `FUNCT3_BRANCH_EQ: ALU_Function = `ALU_SEQ;
                    `FUNCT3_BRANCH_NE: ALU_Function = `ALU_SNE;
                    `FUNCT3_BRANCH_LT: ALU_Function = `ALU_SLT;
                    `FUNCT3_BRANCH_GE: ALU_Function = `ALU_SGE;
                    `FUNCT3_BRANCH_LTU: ALU_Function = `ALU_SLTU;
                    `FUNCT3_BRANCH_GEU: ALU_Function = `ALU_SGEU;
                endcase
                BranchType = 3'b001; // CTL_BRANCH_COND
            end
            `OPCODE_JALR: begin
                RegWrite = jal_one_regfile_write_eanble ? `ON :`OFF; //fan
                ALUSrc2 = `ON;
                WriteBack_Sel = `CTL_WRITEBACK_PC4;
                BranchType = 3'b011; // CTL_BRANCH_JALR
            end
            `OPCODE_JAL: begin
                RegWrite = jal_one_regfile_write_eanble ? `ON :`OFF; //fan
                ALUSrc2 = `ON; //fan
                WriteBack_Sel = `CTL_WRITEBACK_PC4;
                BranchType = 3'b010; // CTL_BRANCH_JAL
            end
        endcase
    end
endmodule
