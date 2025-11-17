module Mux_RegWriteData (
    input [31:0] input0, //alu_result
    input [31:0] input1, //extended_Mem_data
    input [31:0] input2, //imm_data
    input [31:0] input3, //pc_add_4
    input [2:0] select,
    output reg [31:0] reg_write_data
);
    always @(*) begin
        case (select)
            `CTL_WRITEBACK_ALU:  reg_write_data = input0;
            `CTL_WRITEBACK_DATA: reg_write_data = input1;
            `CTL_WRITEBACK_PC4:  reg_write_data = input3;
            `CTL_WRITEBACK_IMM:  reg_write_data = input2;
            default: reg_write_data = 0;
        endcase
    end
endmodule
