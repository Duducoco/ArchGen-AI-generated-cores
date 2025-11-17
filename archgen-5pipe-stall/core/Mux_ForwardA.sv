module Mux_ForwardA (
    input [31:0] input0,     
    input [31:0] input1,     
    input [31:0] input2,     
    input [1:0] select,      
    output [31:0] output_data
);
    assign output_data = (select == 2'b00) ? input0 : 
                        (select == 2'b01) ? input2 : 
                        (select == 2'b10) ? input1 : 
                        32'b0; 
endmodule
