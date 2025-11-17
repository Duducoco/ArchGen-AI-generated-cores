module Forwarding_Unit (
    input [4:0] rs1_EX,      
    input [4:0] rs2_EX,      
    input [4:0] rd_EX,       
    input [4:0] rd_Mem,      
    input RegWrite_Mem,      
    input [4:0] rd_WB,       
    input RegWrite_WB,       
    output [1:0] ForwardA,   
    output [1:0] ForwardB    
);

    assign ForwardA = (RegWrite_Mem && (rd_Mem != 5'b0) && (rd_Mem == rs1_EX)) ? 2'b10 : 
                     (RegWrite_WB && (rd_WB != 5'b0) && (rd_WB == rs1_EX)) ? 2'b01 : 
                     2'b00;

    assign ForwardB = (RegWrite_Mem && (rd_Mem != 5'b0) && (rd_Mem == rs2_EX)) ? 2'b10 : 
                     (RegWrite_WB && (rd_WB != 5'b0) && (rd_WB == rs2_EX)) ? 2'b01 : 
                     2'b00;
endmodule
