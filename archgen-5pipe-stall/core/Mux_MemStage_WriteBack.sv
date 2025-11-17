module Mux_MemStage_WriteBack (
    input [31:0] input0,     
    input [31:0] input1,     
    input [31:0] input2,     
    input [31:0] input3,     
    input [2:0] select,      
    output [31:0] wb_data    
);
    assign wb_data = (select == `CTL_WRITEBACK_ALU)  ? input0 : 
                     (select == `CTL_WRITEBACK_DATA) ? input1 : 
                     (select == `CTL_WRITEBACK_IMM)  ? input2 : 
                     (select == `CTL_WRITEBACK_PC4)  ? input3 : 
                     32'b0;
endmodule
