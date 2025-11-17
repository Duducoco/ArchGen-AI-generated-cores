`include "config.sv"
`include "constants.sv"

module DataMem (
	input [`DATA_BITS-3:0] address, //17-3:0, = 15bits
	input [3:0] byteena, // 4 bits for byte enable, each bit corresponds to a byte in the word
	input clock,
    input reset,
	input [31:0] data,
	input wren,
	output [31:0] q
);

    (* nomem2reg *)
    logic [31:0] mem[0:2**(`DATA_BITS-2)-1];
    reg initialized = 1'b0;  // 初始化为0
    integer log_file;    
    static int i;  // 在模块级别声明静态变量（关键修改）

    assign q = mem[address];

    // 数据加载和写操作逻辑（带详细调试）
always_ff @(posedge clock or posedge reset) begin
    integer file_check;  // 先声明变量（关键修改）
    if (reset) begin
        $display("[DATA_MEM DEBUG] 检测到复位（reset=1），当前initialized=%b", initialized);
        if (!initialized) begin
            $display("[DATA_MEM DEBUG] 进入初始化逻辑（initialized=0）");
            `ifdef DATA_HEX_PATH
                // 先声明变量，再赋值
                file_check = $fopen(`DATA_HEX_PATH, "r");
                if (file_check) begin
                    $display("[DATA_MEM DEBUG] 文件存在，开始执行$readmemh...");
//                    $readmemh(`DATA_HEX_PATH, mem, 32'h80000000);
                    $readmemh(`DATA_HEX_PATH, mem);
                    initialized <= 1'b1;
                    $display("[DATA_MEM DEBUG] $readmemh执行完成，initialized将置1");
                    $fclose(file_check);
                end else begin
                    $display("[DATA_MEM ERROR] 文件不存在：%s", `DATA_HEX_PATH);
                    initialized <= 1'b1;
                end
            `else
                $display("[DATA_MEM ERROR] 宏DATA_HEX_PATH未定义！");
                initialized <= 1'b1;
            `endif
        end else begin
            $display("[DATA_MEM DEBUG] 已完成初始化（initialized=1），跳过加载");
        end
    end
    else if (wren) begin
        // 正常写操作（不变）
        if (byteena[0]) mem[address][0+:8] <= data[0+:8];
        if (byteena[1]) mem[address][8+:8] <= data[8+:8];
        if (byteena[2]) mem[address][16+:8] <= data[16+:8];
        if (byteena[3]) mem[address][24+:8] <= data[24+:8];
    end
end




//`ifdef DATA_HEX
//    initial $readmemh(`DATA_HEX, mem);
//`endif

endmodule
