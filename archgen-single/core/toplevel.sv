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

    // Internal signal declarations
    logic [31:0] next_pc;
    logic [31:0] current_pc_internal;
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic [31:0] imm_data;
    logic [4:0] ALU_Function;
    logic ALUSrc1;
    logic ALUSrc2;
    logic [2:0] WriteBack_Sel;
    logic RegWrite;
    logic MemRead;
    logic MemWrite;
    logic [2:0] BranchType;
    logic [31:0] reg_data_rs1;
    logic [31:0] reg_data_rs2;
    logic [31:0] Reg_write_data;
    logic [31:0] alu_src1_out;
    logic [31:0] alu_src2_out;
    logic [31:0] alu_result;
    logic cmp_result;
    logic [31:0] pc_add_4;
    logic [1:0] next_pc_sel;
    logic [31:0] branch_target;
    logic [31:0] adjusted_addr;
    logic [31:0] extended_data;
    logic [`DATA_BITS-3:0] data_mem_address;
    logic [31:0] data_mem_q;
    logic [31:0] write_data_out;
    logic [3:0] byteena;
    logic read_enable_out;
    logic write_enable_out;
    logic [31:0] instruction;

    
    // Connect top-level outputs
    assign pc = current_pc_internal;
    assign inst = instruction;
    assign bus_read_data = data_mem_q;
    assign bus_address = alu_result;
    assign bus_write_data = write_data_out;
    assign bus_byte_enable = byteena;
    assign bus_read_enable = read_enable_out;
    assign bus_write_enable = write_enable_out;

    // Module instantiations
    PC pc_inst (
        .clk(clock),
        .reset(reset),
        .next_pc_in(next_pc),
        .current_pc(current_pc_internal)
    );

    InstMem instr_mem_inst (
        .address(current_pc_internal[`TEXT_BITS-1:2]),
        .clock(clock),
        .q(instruction)
    );

    Decoder decoder_inst (
        .instruction(instruction),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd)
    );

    ImmGen imm_gen_inst (
        .instruction(instruction),
        .opcode(opcode),
        .imm_data(imm_data)
    );

    Controller ctrl_inst (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .ALU_Function(ALU_Function),
        .ALUSrc1(ALUSrc1),
        .ALUSrc2(ALUSrc2),
        .WriteBack_Sel(WriteBack_Sel),
        .RegWrite(RegWrite),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .BranchType(BranchType)
    );

    RegFile reg_file_inst (
        .clk(clock),
        .reset(reset),
        .RegWrite(RegWrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(Reg_write_data),
        .reg_data_rs1(reg_data_rs1),
        .reg_data_rs2(reg_data_rs2)
    );

    Mux_ALUSrc1 mux_alu_src1_inst (
        .input0(reg_data_rs1),
        .input1(current_pc_internal),
        .select(ALUSrc1),
        .out(alu_src1_out)
    );

    Mux_ALUSrc2 mux_alu_src2_inst (
        .input0(reg_data_rs2),
        .input1(imm_data),
        .select(ALUSrc2),
        .out(alu_src2_out)
    );

    ALU alu_inst (
        .operand1(alu_src1_out),
        .operand2(alu_src2_out),
        .ALU_Function(ALU_Function),
        .alu_result(alu_result),
        .cmp_result(cmp_result)
    );

    Mux_RegWriteData mux_reg_write_data_inst (
        .input0(alu_result),
        .input1(extended_data),
        .input2(imm_data),
        .input3(pc_add_4),
        .select(WriteBack_Sel),
        .reg_write_data(Reg_write_data)
    );

    PC_Plus4_Adder pc_plus4_adder_inst (
        .current_pc(current_pc_internal),
        .pc_add_4(pc_add_4)
    );

    Mux_NextPC mux_next_pc_inst (
        .input0(pc_add_4),
        .input1(branch_target),
        .input2(adjusted_addr),
        .select(next_pc_sel),
        .next_pc(next_pc)
    );

    PC_PlusImm_Adder pc_plus_imm_adder_inst (
        .pc_in(current_pc_internal),
        .imm_in(imm_data),
        .branch_target(branch_target)
    );

    NextPC_Decision_Unit next_pc_decision_inst (
        .cmp_result_in(cmp_result),
        .branch_type_in(BranchType),
        .next_pc_sel(next_pc_sel)
    );

    JALR_Adjust jalr_adjust_inst (
        .addr_in(alu_result),
        .adjusted_addr(adjusted_addr)
    );

    DataMem_interface_Unit data_mem_interface_inst (
        .funct3(funct3),
        .write_data_in(reg_data_rs2),
        .mem_addr(alu_result),
        .mem_data_in(data_mem_q),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .extended_data(extended_data),
        .address(data_mem_address),
        .write_data_out(write_data_out),
        .byteena(byteena),
        .read_enable_out(read_enable_out),
        .write_enable_out(write_enable_out)
    );

    DataMem data_mem_inst (
        .address(data_mem_address),
        .byteena(byteena),
        .clock(clock),
        .data(write_data_out),
        .wren(write_enable_out),
        .q(data_mem_q)
    );

endmodule
