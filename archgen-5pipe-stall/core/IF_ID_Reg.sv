module IF_ID_Reg (
    input clk,                
    input reset,              
    input flush,              
    input stall,              
    input [31:0] instruction_in,
    input [31:0] pc_add_4_in, 
    input [31:0] pc_in,       
    output [31:0] instruction_ID,
    output [31:0] pc_add_4_ID,
    output [31:0] pc_ID       
);
    reg [31:0] instruction_reg;
    reg [31:0] pc_add_4_reg;
    reg [31:0] pc_reg;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            instruction_reg <= 32'b0;
            pc_add_4_reg <= 32'b0;
            pc_reg <= 32'b0;
        end
        else if (flush) begin
            instruction_reg <= 32'b0;
            pc_add_4_reg <= 32'b0;
            pc_reg <= 32'b0;
        end
        else if (!stall) begin
            instruction_reg <= instruction_in;
            pc_add_4_reg <= pc_add_4_in;
            pc_reg <= pc_in;
        end
    end
    assign instruction_ID = instruction_reg;
    assign pc_add_4_ID = pc_add_4_reg;
    assign pc_ID = pc_reg;
endmodule
