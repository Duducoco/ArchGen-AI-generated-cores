module ID_EX_Reg (
    input clk,                
    input reset,              
    input flush, 
    input stall,             
    input [31:0] pc_add_4_in, 
    input [31:0] pc_in,       
    input [31:0] reg_data_rs1_in,
    input [31:0] reg_data_rs2_in,
    input [31:0] imm_data_in, 
    input [2:0] funct3_in,    
    input [4:0] rd_in,        
    input [4:0] rs1_in,       
    input [4:0] rs2_in,       
    input [4:0] ALU_Function_in,
    input ALUSrc1_in,         
    input ALUSrc2_in,         
    input MemRead_in,         
    input MemWrite_in,        
    input RegWrite_in,        
    input [2:0] WriteBack_Sel_in,
    input [2:0] BranchType_in,
    input is_jalr_in,         
    output reg [31:0] pc_add_4_EX,
    output reg [31:0] pc_EX,
    output reg [31:0] reg_data_rs1_EX,
    output reg [31:0] reg_data_rs2_EX,
    output reg [31:0] imm_data_EX,
    output reg [2:0] funct3_EX,
    output reg [4:0] rd_EX,
    output reg [4:0] rs1_EX,
    output reg [4:0] rs2_EX,
    output reg [4:0] ALU_Function_EX,
    output reg ALUSrc1_EX,
    output reg ALUSrc2_EX,
    output reg MemRead_EX,
    output reg MemWrite_EX,
    output reg RegWrite_EX,
    output reg [2:0] WriteBack_Sel_EX,
    output reg [2:0] BranchType_EX,
    output reg is_jalr_EX
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            MemRead_EX <= 1'b0;
            MemWrite_EX <= 1'b0;
            RegWrite_EX <= 1'b0;
            BranchType_EX <= 3'b0;
        end
        else if (flush) begin
            pc_add_4_EX <= 32'b0;
            pc_EX <= 32'b0;
            reg_data_rs1_EX <= 32'b0;
            reg_data_rs2_EX <= 32'b0;
            imm_data_EX <= 32'b0;
            funct3_EX <= 3'b0;
            rd_EX <= 5'b0;
            rs1_EX <= 5'b0;
            rs2_EX <= 5'b0;
            ALU_Function_EX <= 5'b0;
            ALUSrc1_EX <= 1'b0;
            ALUSrc2_EX <= 1'b0;
            MemRead_EX <= 1'b0;
            MemWrite_EX <= 1'b0;
            RegWrite_EX <= 1'b0;
            WriteBack_Sel_EX <= 3'b0;
            BranchType_EX <= 3'b0;
            is_jalr_EX <= 1'b0;
        end
        else begin
            pc_add_4_EX <= pc_add_4_in;
            pc_EX <= pc_in;
            reg_data_rs1_EX <= reg_data_rs1_in;
            reg_data_rs2_EX <= reg_data_rs2_in;
            imm_data_EX <= imm_data_in;
            funct3_EX <= funct3_in;
            rd_EX <= rd_in;
            rs1_EX <= rs1_in;
            rs2_EX <= rs2_in;
            ALU_Function_EX <= ALU_Function_in;
            ALUSrc1_EX <= ALUSrc1_in;
            ALUSrc2_EX <= ALUSrc2_in;
            MemRead_EX <= MemRead_in;
            MemWrite_EX <= MemWrite_in;
            RegWrite_EX <= RegWrite_in;
            WriteBack_Sel_EX <= WriteBack_Sel_in;
            BranchType_EX <= BranchType_in;
            is_jalr_EX <= is_jalr_in;
            if (stall) begin
                // If stalled, hold the previous values
                MemRead_EX <= 1'b0;
                MemWrite_EX <= 1'b0;
                RegWrite_EX <= 1'b0;
                BranchType_EX <= 3'b0;
            end
        end
    end

endmodule

