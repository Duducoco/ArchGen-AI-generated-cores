module Hazard_Control_Unit (
    input [6:0] opcode_ID,         // ID阶段操作码
    input [4:0] rs1_ID,            // ID阶段源寄存器1
    input [4:0] rs2_ID,            // ID阶段源寄存器2
    input ALUSrc1,
    input ALUSrc2,
    input [4:0] rd_EX,             // EX阶段目的寄存器
    input RegWrite_EX,             // EX阶段寄存器写使能
    input [4:0] rd_Mem,            // Mem阶段目的寄存器
    input RegWrite_Mem,            // Mem阶段寄存器写使能
    input [2:0] BranchType_EX,     // EX阶段分支类型
    input branch_taken_EX,         // EX阶段分支决策结果

    input [4:0] rd_WB,            
    input RegWrite_WB,             
    input reset,                   
    input clk,                     

    output logic jal_one_regfile_write_eanble, //fan provide to controll to make jal 1 time enable for regfile_write_enable
    output logic non_branch_case,       //non_branch_case
    output logic stall_pc,               
    output logic stall_if_id,            
    output logic stall_id_ex,             
    output logic flush_if_id
//fan    output logic flush_id_ex
);
   wire data_hazard_flag;
   wire control_hazard_flag;

    // 检测EX阶段数据冲突
    wire ex_stage_conflict = (
            ((rs1_ID == rd_EX) || (rs2_ID == rd_EX)) &&
            (rd_EX != 0) && 
            (RegWrite_EX==1) &&
            ALUSrc1 == 0 
        ) || (
            ((rs1_ID == rd_EX) || (rs2_ID == rd_EX)) &&
            (rd_EX != 0) && 
            (RegWrite_EX==1) &&
            ALUSrc2 == 0
        ) ;

    // 检测MEM阶段数据冲突
    wire mem_stage_conflict = (
            ((rs1_ID == rd_Mem) || (rs2_ID == rd_Mem)) &&
            (rd_Mem != 0) &&
            RegWrite_Mem &&
            ALUSrc1 == 0 
        ) || (
            ((rs1_ID == rd_Mem) || (rs2_ID == rd_Mem)) &&
            (rd_Mem != 0) &&
            RegWrite_Mem &&
            ALUSrc2 == 0
        );

    //新增 WB阶段冲突
    wire wb_stage_conflict = (
        ((rs1_ID == rd_WB) || (rs2_ID == rd_WB)) &&
        (rd_WB != 0) &&
        RegWrite_WB &&
        ALUSrc1 == 0
        ) || (
            ((rs1_ID == rd_WB) || (rs2_ID == rd_WB)) &&
            (rd_WB != 0) &&
            RegWrite_WB &&
            ALUSrc2 == 0
        );
    assign data_hazard_flag = ex_stage_conflict || mem_stage_conflict || wb_stage_conflict;

    // 检测控制冲突（分支/JAL/JALR指令）
    wire is_branch = (opcode_ID == 7'b1100011);  // branch
    wire is_jal    = (opcode_ID == 7'b1101111);  // JAL
    wire is_jalr   = (opcode_ID == 7'b1100111);  // JALR
    assign control_hazard_flag = is_branch || is_jal || is_jalr;

    //FSM：如果存在控制冲突且不存在数据冲突，将依次产生如下状态： 控制stall(PC、IF_ID、ID_EX都冻结), 控制跟新（PC_stall解除，IF_ID、ID_EX保持冻结）,释放（PC、IF_ID、ID_EX都解除冻结）
    // FSM状态定义
    typedef enum logic [1:0] { 
        IDLE,           // 空闲状态
        DATA_STALL,    // 数据冲突冻结状态
        CONTROL_STALL,  // 控制冲突冻结状态
        CONTROL_UPDATE  // 控制冲突更新状态
//fan        CONTROL_RECOVER  //控制冲突更新状态多等待一拍
    } fsm_state_t;
    fsm_state_t current_state, next_state;
    // FSM状态转换逻辑
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE; // 重置状态为IDLE
        end else begin
            current_state <= next_state; // 更新状态
        end
    end

//fan    assign stall_pc = data_hazard_flag || (control_hazard_flag && !data_hazard_flag && (current_state==DATA_STALL) && (next_state == CONTROL_STALL)); 
//fan    assign stall_if_id = data_hazard_flag || (control_hazard_flag && !data_hazard_flag && (current_state==DATA_STALL) && (next_state == CONTROL_STALL)); 
//fan    assign stall_id_ex = data_hazard_flag || (control_hazard_flag && !data_hazard_flag && (current_state==DATA_STALL) && (next_state == CONTROL_STALL)); 

    assign stall_pc = data_hazard_flag || (control_hazard_flag && !data_hazard_flag && (((current_state==IDLE) && (next_state == CONTROL_STALL)) || ((current_state==DATA_STALL) && (next_state == CONTROL_STALL)))); 
    assign stall_if_id = data_hazard_flag || (control_hazard_flag && !data_hazard_flag && (((current_state==IDLE) && (next_state == CONTROL_STALL)) || ((current_state==DATA_STALL) && (next_state == CONTROL_STALL)) || (next_state == CONTROL_UPDATE))) ; 
    assign stall_id_ex = data_hazard_flag; 

    assign flush_if_id = (!data_hazard_flag) && control_hazard_flag && branch_taken_EX && (current_state==CONTROL_STALL) && (next_state == IDLE); //fan 
    assign non_branch_case = control_hazard_flag && !data_hazard_flag && (current_state==CONTROL_STALL) && (next_state == CONTROL_UPDATE) ? 1'b1 : 1'b0; //ensure select_pc =3 within one clock
    assign jal_one_regfile_write_eanble = (control_hazard_flag && !data_hazard_flag && ((current_state==IDLE) && (next_state == CONTROL_STALL)) );
//fan    assign flush_if_id = control_hazard_flag; //fan 

//fan    assign flush_id_ex = data_hazard_flag;  //fan 


    // FSM状态转移逻辑
    always_comb begin
        case (current_state)
            IDLE: begin
                if(data_hazard_flag) begin
                    next_state = DATA_STALL; // 进入数据冲突冻结状态
                end else if(control_hazard_flag) begin
                    next_state = CONTROL_STALL; // 进入控制冲突冻结状态
                end else begin
                    next_state = IDLE; // 保持空闲状态
                end
            end

            DATA_STALL: begin
                if (data_hazard_flag) begin
                    next_state = DATA_STALL; // 保持数据冲突冻结状态如
                end else if(control_hazard_flag) begin
                    next_state = CONTROL_STALL; // 如果有控制冲突，进入控制冲突冻结状态
                end else begin
                    next_state = IDLE; //如果没有数据冲突，进入空闲状态
                end
            end

            CONTROL_STALL: begin
                next_state = CONTROL_UPDATE;
            end

            CONTROL_UPDATE: begin
                next_state = IDLE; // 控制更新后等待一拍
            end

//fan            CONTROL_UPDATE: begin
//fan                next_state = IDLE; // 控制更新后直接进入空闲状态
//fan            end

            default: begin
                next_state = IDLE; // 默认回到空闲状态
            end
        endcase
    end

//    // FSM输出逻辑
//    always_comb begin
//        case (next_state)
//            IDLE: begin
//                // 空闲状态下，所有信号均为无效
//                stall_pc = 0;
//             end
//
//            DATA_STALL: begin
//                // 数据冲突冻结状态下，冻结相关信号
//                stall_pc = 1;
//
//            end
//
//            CONTROL_STALL: begin
//                // 控制冲突冻结状态下，冻结相关信号
//                stall_pc = 1;
//
//            end
//
//            CONTROL_UPDATE: begin
//                // 控制冲突更新状态下，更新相关信号
//                stall_pc = 0;
//
//            end
//
//            default: begin
//                // 默认情况下，所有信号均为无效
//                stall_pc = 0;
//            end
//        endcase
//    end

endmodule
