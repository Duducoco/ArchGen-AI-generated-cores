module PC (
    input clk,
    input reset,
    input [31:0] next_pc_in,
    output reg [31:0] current_pc
);
    always @(posedge clk or posedge reset) begin
        if (reset) current_pc <= `INITIAL_PC;
        else current_pc <= next_pc_in;
    end
endmodule
