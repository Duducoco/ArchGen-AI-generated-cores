module Mem_WB_Reg (
    input clk,                
    input reset,              
    input [31:0] wb_data_in,  
    input [4:0] rd_in,        
    input RegWrite_in,        
    output [31:0] wb_data_WB, 
    output [4:0] rd_WB,       
    output RegWrite_WB        
);
    reg [31:0] wb_data_reg;
    reg [4:0] rd_reg;
    reg RegWrite_reg;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wb_data_reg <= 32'b0;
            rd_reg <= 5'b0;
            RegWrite_reg <= 1'b0;
        end
        else begin
            wb_data_reg <= wb_data_in;
            rd_reg <= rd_in;
            RegWrite_reg <= RegWrite_in;
        end
    end
    assign wb_data_WB = wb_data_reg;
    assign rd_WB = rd_reg;
    assign RegWrite_WB = RegWrite_reg;
endmodule
