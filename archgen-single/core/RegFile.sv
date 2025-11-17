module RegFile (
    input clk,
    input reset,
    input RegWrite,
    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] rd,
    input [31:0] write_data,
    output reg [31:0] reg_data_rs1,
    output reg [31:0] reg_data_rs2
);
    reg [31:0] registers [31:0];
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) for (i = 0; i < 32; i = i+1) registers[i] <= 0;
        else if (RegWrite && rd != 0) registers[rd] <= write_data;
    end
    always @(*) begin
        reg_data_rs1 = (rs1 == 0) ? 0 : registers[rs1];
        reg_data_rs2 = (rs2 == 0) ? 0 : registers[rs2];
    end
endmodule
