`include "config.sv"
`include "constants.sv"

module toplevel (
    input  clock,    // input
    input  reset,    // input

    output logic [31:0] bus_read_data,   // 从DataMem读出的数据
    output logic [31:0] bus_address,     // 对DataMem读/写数据时，目标访存地址
    output logic [31:0] bus_write_data,  // 要写入DataMem的数据
    output logic [3:0]  bus_byte_enable, // 存储器控制信号
    output logic        bus_read_enable, // 存储器读使能信号
    output logic        bus_write_enable,// 存储器写使能信号

    output logic [31:0] inst,            // InstrMem读出的指令
    output logic [31:0] pc               // 当前PC值
);

    //////////////////////////////////////////
    // 声明所有中间信号
    //////////////////////////////////////////
    // IF阶段信号
    logic [31:0] current_pc_IF;
    logic [31:0] instruction_IF;
    logic [31:0] pc_add_4_IF;
    logic [31:0] next_pc_IF;
    
    // ID阶段信号
    logic [31:0] instruction_ID;
    logic [31:0] pc_add_4_ID;
    logic [31:0] pc_ID;
    logic [6:0] opcode_ID;
    logic [2:0] funct3_ID;
    logic [6:0] funct7_ID;
    logic [4:0] rs1_ID;
    logic [4:0] rs2_ID;
    logic [4:0] rd_ID;
    logic [31:0] imm_data_ID;
    logic [31:0] reg_data_rs1_ID;
    logic [31:0] reg_data_rs2_ID;
    logic is_jalr_ID;  // 新增JALR标识信号
    
    // EX阶段信号
    logic [31:0] pc_add_4_EX;
//fan    logic [31:0] pc_add_4_EXE;
    logic [31:0] pc_EX;
    logic [31:0] inst_EX;           // instruction for trace (debug)
    logic [31:0] reg_data_rs1_EX;
    logic [31:0] reg_data_rs2_EX;
    logic [31:0] imm_data_EX;
    logic [2:0] funct3_EX;
    logic [4:0] rd_EX;
    logic [4:0] rs1_EX;  // 新增EX阶段rs1
    logic [4:0] rs2_EX;  // 新增EX阶段rs2
    logic [4:0] ALU_Function_EX;
    logic ALUSrc1_EX;
    logic ALUSrc2_EX;
    logic MemRead_EX;
    logic MemWrite_EX;
    logic RegWrite_EX;
    logic [2:0] WriteBack_Sel_EX;
    logic [2:0] BranchType_EX;
    logic [31:0] alu_operand1;
    logic [31:0] alu_operand2;
    logic [31:0] alu_result_EX;
    logic cmp_result_EX;
    logic [31:0] branch_target_EX;
    logic [31:0] jalr_adjusted_EX;
    logic [1:0] next_pc_sel_EX;
    logic branch_taken_EX;  // 分支发生信号
    logic is_jalr_EX;       // EX阶段JALR标识
    
    // MEM阶段信号
    logic [31:0] alu_result_Mem;
    logic [31:0] reg_data_rs2_Mem;
    logic [31:0] imm_data_Mem;
    logic [31:0] pc_add_4_Mem;
    logic [31:0] pc_Mem;            // PC for trace (debug)
    logic [31:0] inst_Mem;          // instruction for trace (debug)
    logic [2:0] funct3_Mem;
    logic [4:0] rd_Mem;
    logic MemRead_Mem;
    logic MemWrite_Mem;
    logic RegWrite_Mem;
    logic [2:0] WriteBack_Sel_Mem;
    logic [31:0] extended_data_Mem;
    logic [`DATA_BITS-3:0] data_mem_address;
    logic [31:0] data_mem_write_data;
    logic [3:0] data_mem_byteena;
    logic data_mem_read_enable;
    logic data_mem_write_enable;
    logic [31:0] data_mem_read_data;
    
    // WB阶段信号
    logic [31:0] wb_data_WB;          // 修改：合并为单一写回数据
    logic [31:0] pc_WB;               // PC for trace (debug)
    logic [31:0] inst_WB;             // instruction for trace (debug)
    logic [4:0] rd_WB;
    logic RegWrite_WB;
    logic [31:0] reg_write_data_WB;   // 写回寄存器文件的数据
    
    // Hazard控制信号
    logic non_branch_case; //fan
    logic jal_one_regfile_write_eanble; //fan
    logic stall_pc;
    logic stall_if_id;
    logic flush_if_id;
    logic flush_id_ex;
    logic stall_id_ex;
    
    // 控制器输出信号
    logic [4:0] ALU_Function_ctl;
    logic ALUSrc1_ctl;
    logic ALUSrc2_ctl;
    logic [2:0] WriteBack_Sel_ctl;
    logic RegWrite_ctl;
    logic MemRead_ctl;
    logic MemWrite_ctl;
    logic [2:0] BranchType_ctl;

    //////////////////////////////////////////
    // 模块实例化
    //////////////////////////////////////////
    
    // PC模块（使用覆盖后的stall信号）
    PC pc_inst (
        .clk(clock),
        .reset(reset),
        .pc_write_enable(~stall_pc), // 修改
        .next_pc_in(next_pc_IF),
        .current_pc(current_pc_IF)
    );
    
    // 指令存储器
    InstMem inst_mem (
        .address(current_pc_IF[`TEXT_BITS-1:2]), // 取PC的高位作为地址
        .clock(clock),
        .q(instruction_IF)
    );
    
    // PC+4加法器
    PC_Plus4_Adder pc_plus4_adder (
        .current_pc(current_pc_IF),
        .pc_add_4(pc_add_4_IF)
    );
    
    // 下一条PC选择器
    Mux_NextPC mux_next_pc (
        .input0(pc_add_4_IF),            // PC+4
        .input1 (branch_target_EX),       // 分支目标地址
        .input2 (jalr_adjusted_EX),       // JALR调整地址
        .input3 (pc_add_4_EX),            // PC+4 [EX] fan add
        .select (next_pc_sel_EX),         // 选择信号
        .next_pc(next_pc_IF)             // 下一条PC值
    );
    
    // IF/ID流水线寄存器（使用覆盖后的stall信号）
    IF_ID_Reg if_id_reg (
        .clk(clock),
        .reset(reset),
        .stall(stall_if_id),       // 修改
        .flush(1'b0),
//fan        .flush(flush_if_id),
        .instruction_in(instruction_IF),
        .pc_add_4_in(pc_add_4_IF),
        .pc_in(current_pc_IF),
        .instruction_ID(instruction_ID),
        .pc_add_4_ID(pc_add_4_ID),
        .pc_ID(pc_ID)
    );
    
    // 指令译码器
    Decoder decoder (
        .instruction(instruction_ID),
        .opcode(opcode_ID),
        .funct3(funct3_ID),
        .funct7(funct7_ID),
        .rs1(rs1_ID),
        .rs2(rs2_ID),
        .rd(rd_ID)
    );
    
    // 立即数生成器
    ImmGen imm_gen (
        .instruction(instruction_ID),
        .opcode(opcode_ID),
        .imm_data(imm_data_ID)
    );
    
    // JALR指令标识
    assign is_jalr_ID = (opcode_ID == `OPCODE_JALR);
    
    // 控制器
    Controller controller (
        .opcode(opcode_ID),
        .funct3(funct3_ID),
        .funct7(funct7_ID),
        .jal_one_regfile_write_eanble(jal_one_regfile_write_eanble),
        .ALU_Function(ALU_Function_ctl),
        .ALUSrc1(ALUSrc1_ctl),
        .ALUSrc2(ALUSrc2_ctl),
        .WriteBack_Sel(WriteBack_Sel_ctl),
        .RegWrite(RegWrite_ctl),
        .MemRead(MemRead_ctl),
        .MemWrite(MemWrite_ctl),
        .BranchType(BranchType_ctl)
    );
    
    // 寄存器文件
    RegFile reg_file (
        .clk(clock),
        .reset(reset),
        .RegWrite(RegWrite_WB),
        .rs1(rs1_ID),
        .rs2(rs2_ID),
        .rd(rd_WB),
        .write_data(wb_data_WB),
        .reg_data_rs1(reg_data_rs1_ID),
        .reg_data_rs2(reg_data_rs2_ID)
    );
    
     // ID/EX流水线寄存器（使用覆盖后的flush信号）
    ID_EX_Reg id_ex_reg (
        .clk(clock),
        .reset(reset),
        .flush(1'b0),
	.stall(stall_id_ex),
        .pc_add_4_in(pc_add_4_ID),
        .pc_in(pc_ID),
        .inst_in(instruction_ID),  // instruction for trace (debug)
        .reg_data_rs1_in(reg_data_rs1_ID),
        .reg_data_rs2_in(reg_data_rs2_ID),
        .imm_data_in(imm_data_ID),
        .funct3_in(funct3_ID),
        .rd_in(rd_ID),
        .rs1_in(rs1_ID),  // 添加rs1连接
        .rs2_in(rs2_ID),  // 添加rs2连接
        .ALU_Function_in(ALU_Function_ctl),
        .ALUSrc1_in(ALUSrc1_ctl),
        .ALUSrc2_in(ALUSrc2_ctl),
        .MemRead_in(MemRead_ctl),
        .MemWrite_in(MemWrite_ctl),
        .RegWrite_in(RegWrite_ctl),
        .WriteBack_Sel_in(WriteBack_Sel_ctl),
        .BranchType_in(BranchType_ctl),
        .is_jalr_in(is_jalr_ID),  // 添加JALR标识
        .pc_add_4_EX(pc_add_4_EX),
        .pc_EX(pc_EX),
        .inst_EX(inst_EX),  // instruction for trace (debug)
        .reg_data_rs1_EX(reg_data_rs1_EX),
        .reg_data_rs2_EX(reg_data_rs2_EX),
        .imm_data_EX(imm_data_EX),
        .funct3_EX(funct3_EX),
        .rd_EX(rd_EX),
        .rs1_EX(rs1_EX),  // 输出rs1
        .rs2_EX(rs2_EX),  // 输出rs2
        .ALU_Function_EX(ALU_Function_EX),
        .ALUSrc1_EX(ALUSrc1_EX),
        .ALUSrc2_EX(ALUSrc2_EX),
        .MemRead_EX(MemRead_EX),
        .MemWrite_EX(MemWrite_EX),
        .RegWrite_EX(RegWrite_EX),
        .WriteBack_Sel_EX(WriteBack_Sel_EX),
        .BranchType_EX(BranchType_EX),
        .is_jalr_EX(is_jalr_EX)  // 输出JALR标识
    );
    
    // ALU操作数1选择器
    Mux_ALUSrc1 mux_alu_src1 (
        .input0(reg_data_rs1_EX),  // 寄存器数据
        .input1(pc_EX),            // PC值
        .select(ALUSrc1_EX),       // 选择信号
        .out(alu_operand1)         // ALU操作数1
    );
    
    // ALU操作数2选择器
    Mux_ALUSrc2 mux_alu_src2 (
        .input0(reg_data_rs2_EX),  // 寄存器数据
        .input1(imm_data_EX),      // 立即数
        .select(ALUSrc2_EX),       // 选择信号
        .out(alu_operand2)         // ALU操作数2
    );
    
    // ALU模块
    ALU alu (
        .operand1(alu_operand1),
        .operand2(alu_operand2),
        .ALU_Function(ALU_Function_EX),
        .alu_result(alu_result_EX),
        .cmp_result(cmp_result_EX)
    );
    
    // PC+立即数加法器（分支目标计算）
    PC_PlusImm_Adder pc_plus_imm_adder (
        .pc_in(pc_EX),
        .imm_in(imm_data_EX),
        .branch_target(branch_target_EX)
    );

//fan    // PC+4加法器（EX） fan add
//fan    PC_Plus4_Adder pc_plus4_adder_EX (
//fan        .current_pc(pc_EX),
//fan        .pc_add_4(pc_add_4_EXE)
//fan    );

    // JALR地址调整模块
    JALR_Adjust jalr_adjust (
        .addr_in(alu_result_EX),
        .adjusted_addr(jalr_adjusted_EX)
    );
    
    // 下一条PC决策单元
    NextPC_Decision_Unit next_pc_decision (
        .non_branch_case(non_branch_case),
        .cmp_result_in(cmp_result_EX),
        .branch_type_in(BranchType_EX),
        .next_pc_sel(next_pc_sel_EX)
    );
    
    // 分支发生判断
    assign branch_taken_EX = (next_pc_sel_EX != 2'b00);
    
    // EX/MEM流水线寄存器
    EX_Mem_Reg ex_mem_reg (
        .clk(clock),
        .reset(reset),
        .alu_result_in(alu_result_EX),
        .reg_data_rs2_in(reg_data_rs2_EX),
        .imm_data_in(imm_data_EX),
        .pc_add_4_in(pc_add_4_EX),
        .pc_in(pc_EX),             // PC for trace (debug)
        .inst_in(inst_EX),         // instruction for trace (debug)
        .funct3_in(funct3_EX),
        .rd_in(rd_EX),
        .MemRead_in(MemRead_EX),
        .MemWrite_in(MemWrite_EX),
        .RegWrite_in(RegWrite_EX),
        .WriteBack_Sel_in(WriteBack_Sel_EX),
        .alu_result_Mem(alu_result_Mem),
        .reg_data_rs2_Mem(reg_data_rs2_Mem),
        .imm_data_Mem(imm_data_Mem),
        .pc_add_4_Mem(pc_add_4_Mem),
        .pc_Mem(pc_Mem),           // PC for trace (debug)
        .inst_Mem(inst_Mem),       // instruction for trace (debug)
        .funct3_Mem(funct3_Mem),
        .rd_Mem(rd_Mem),
        .MemRead_Mem(MemRead_Mem),
        .MemWrite_Mem(MemWrite_Mem),
        .RegWrite_Mem(RegWrite_Mem),
        .WriteBack_Sel_Mem(WriteBack_Sel_Mem)
    );
    
    // 数据存储器接口单元
    DataMem_interface_Unit data_mem_interface (
        .funct3(funct3_Mem),
        .write_data_in(reg_data_rs2_Mem),
        .mem_addr(alu_result_Mem),
        .mem_data_in(data_mem_read_data),
        .MemRead(MemRead_Mem),
        .MemWrite(MemWrite_Mem),
        .extended_data(extended_data_Mem),
        .address(data_mem_address),
        .write_data_out(data_mem_write_data),
        .byteena(data_mem_byteena),
        .read_enable_out(data_mem_read_enable),
        .write_enable_out(data_mem_write_enable)
    );
    
    // 数据存储器
    DataMem data_mem (
        .address(data_mem_address),
        .byteena(data_mem_byteena),
        .clock(clock),
        .reset(reset),
        .data(data_mem_write_data),
        .wren(data_mem_write_enable),
        .q(data_mem_read_data)
    );
    
    // MEM/WB流水线寄存器 (修复接口)
    Mem_WB_Reg mem_wb_reg (
        .clk(clock),
        .reset(reset),
        .wb_data_in(reg_write_data_WB),  // 修改：使用写回数据
        .pc_in(pc_Mem),                  // PC for trace (debug)
        .inst_in(inst_Mem),              // instruction for trace (debug)
        .rd_in(rd_Mem),
        .RegWrite_in(RegWrite_Mem),
        .wb_data_WB(wb_data_WB),          // 修改：输出写回数据
        .pc_WB(pc_WB),                    // PC for trace (debug)
        .inst_WB(inst_WB),                // instruction for trace (debug)
        .rd_WB(rd_WB),
        .RegWrite_WB(RegWrite_WB)
    );
    
    // 写回数据选择器 (在MEM阶段完成选择)
    Mux_RegWriteData mem_stage_writeback_mux (
        .input0(alu_result_Mem),     // ALU结果
        .input1(extended_data_Mem),  // 存储器数据
        .input2(imm_data_Mem),       // 立即数
        .input3(pc_add_4_Mem),       // PC+4
        .select(WriteBack_Sel_Mem),  // 选择信号
        .reg_write_data(reg_write_data_WB) // 写回数据
    );
    
    // Hazard控制单元
    Hazard_Control_Unit hazard_control (
        .opcode_ID(opcode_ID),
        .rs1_ID(rs1_ID),
        .rs2_ID(rs2_ID),
        .ALUSrc1(ALUSrc1_ctl),
        .ALUSrc2(ALUSrc2_ctl),
        .rd_EX(rd_EX),
        .RegWrite_EX(RegWrite_EX),
        .rd_Mem(rd_Mem),
        .RegWrite_Mem(RegWrite_Mem),
        .BranchType_EX(3'b000),
//fan        .branch_taken_EX(1'b0),
        .branch_taken_EX(branch_taken_EX),
        .rd_WB(rd_WB),   //fan
        .RegWrite_WB(RegWrite_WB),  //fan
        .reset(reset),// for FSM
	    .clk(clock),
        .jal_one_regfile_write_eanble(jal_one_regfile_write_eanble),
        .non_branch_case(non_branch_case), //fan
        .stall_pc(stall_pc),
        .stall_if_id(stall_if_id),
	    .stall_id_ex(stall_id_ex),
        .flush_if_id(flush_if_id)  //fan
        );

    //////////////////////////////////////////
    // 连接到顶层输出
    //////////////////////////////////////////
    assign bus_read_data   = extended_data_Mem;     // 从DataMem读出的数据
    assign bus_address     = alu_result_Mem;        // 访存地址
    assign bus_write_data  = data_mem_write_data;   // 写入数据
    assign bus_byte_enable = data_mem_byteena;      // 字节使能
    assign bus_read_enable = data_mem_read_enable;  // 读使能
    assign bus_write_enable= data_mem_write_enable; // 写使能
    assign inst            = instruction_IF;        // 当前指令
    assign pc              = current_pc_IF;         // 当前PC值

endmodule
