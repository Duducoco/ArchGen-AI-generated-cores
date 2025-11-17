module EX_Mem_Reg (
    input clk,                
    input reset,              
    input [31:0] alu_result_in, 
    input [31:0] reg_data_rs2_in,
    input [31:0] imm_data_in, 
    input [31:0] pc_add_4_in, 
    input [2:0] funct3_in,    
    input [4:0] rd_in,        
    input MemRead_in,         
    input MemWrite_in,        
    input RegWrite_in,        
    input [2:0] WriteBack_Sel_in,
    output [31:0] alu_result_Mem,
    output [31:0] reg_data_rs2_Mem,
    output [31:0] imm_data_Mem,
    output [31:0] pc_add_4_Mem,
    output [2:0] funct3_Mem,
    output [4:0] rd_Mem,
    output MemRead_Mem,
    output MemWrite_Mem,
    output RegWrite_Mem,
    output [2:0] WriteBack_Sel_Mem
);
    reg [31:0] alu_result_reg;
    reg [31:0] reg_data_rs2_reg;
    reg [31:0] imm_data_reg;
    reg [31:0] pc_add_4_reg;
    reg [2:0] funct3_reg;
    reg [4:0] rd_reg;
    reg MemRead_reg;
    reg MemWrite_reg;
    reg RegWrite_reg;
    reg [2:0] WriteBack_Sel_reg;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            alu_result_reg <= 32'b0;
            reg_data_rs2_reg <= 32'b0;
            imm_data_reg <= 32'b0;
            pc_add_4_reg <= 32'b0;
            funct3_reg <= 3'b0;
            rd_reg <= 5'b0;
            MemRead_reg <= 1'b0;
            MemWrite_reg <= 1'b0;
            RegWrite_reg <= 1'b0;
            WriteBack_Sel_reg <= 3'b0;
        end
        else begin
            alu_result_reg <= alu_result_in;
            reg_data_rs2_reg <= reg_data_rs2_in;
            imm_data_reg <= imm_data_in;
            pc_add_4_reg <= pc_add_4_in;
            funct3_reg <= funct3_in;
            rd_reg <= rd_in;
            MemRead_reg <= MemRead_in;
            MemWrite_reg <= MemWrite_in;
            RegWrite_reg <= RegWrite_in;
            WriteBack_Sel_reg <= WriteBack_Sel_in;
        end
    end
    assign alu_result_Mem = alu_result_reg;
    assign reg_data_rs2_Mem = reg_data_rs2_reg;
    assign imm_data_Mem = imm_data_reg;
    assign pc_add_4_Mem = pc_add_4_reg;
    assign funct3_Mem = funct3_reg;
    assign rd_Mem = rd_reg;
    assign MemRead_Mem = MemRead_reg;
    assign MemWrite_Mem = MemWrite_reg;
    assign RegWrite_Mem = RegWrite_reg;
    assign WriteBack_Sel_Mem = WriteBack_Sel_reg;
endmodule
