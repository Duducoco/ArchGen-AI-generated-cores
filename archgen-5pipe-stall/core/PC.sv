module PC (
    input clk,
    input reset,
    input pc_write_enable,
    input [31:0] next_pc_in,
    output reg [31:0] current_pc
);
    always @(posedge clk or posedge reset) begin
        if (reset) current_pc <= `INITIAL_PC;
        else if (pc_write_enable) begin
            current_pc <= next_pc_in;
        end
    end
endmodule
