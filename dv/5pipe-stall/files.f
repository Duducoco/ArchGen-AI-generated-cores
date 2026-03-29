// VCS file list for archgen-5pipe-stall core verification
// Paths relative to project root (PROJ_ROOT)

// Include directories
+incdir+dv/common

// DV common config (overrides RTL config.sv with plusargs enabled)
dv/common/config.sv
dv/common/constants.sv

// RTL source files - pipeline stages
archgen-5pipe-stall/core/PC.sv
archgen-5pipe-stall/core/InstMem.sv
archgen-5pipe-stall/core/DataMem.sv
archgen-5pipe-stall/core/Decoder.sv
archgen-5pipe-stall/core/ImmGen.sv
archgen-5pipe-stall/core/Controller.sv
archgen-5pipe-stall/core/RegFile.sv
archgen-5pipe-stall/core/ALU.sv
archgen-5pipe-stall/core/Mux_ALUSrc1.sv
archgen-5pipe-stall/core/Mux_ALUSrc2.sv
archgen-5pipe-stall/core/Mux_RegWriteData.sv
archgen-5pipe-stall/core/Mux_NextPC.sv
// Dead code (not instantiated in toplevel, reserved for future bypass pipeline):
// archgen-5pipe-stall/core/Mux_ForwardA.sv
// archgen-5pipe-stall/core/Mux_ForwardB.sv
// archgen-5pipe-stall/core/Mux_MemStage_WriteBack.sv
archgen-5pipe-stall/core/PC_Plus4_Adder.sv
archgen-5pipe-stall/core/PC_PlusImm_Adder.sv
archgen-5pipe-stall/core/NextPC_Decision_Unit.sv
archgen-5pipe-stall/core/JALR_Adjust.sv
archgen-5pipe-stall/core/DataMem_interface_Unit.sv

// Pipeline registers
archgen-5pipe-stall/core/IF_ID_Reg.sv
archgen-5pipe-stall/core/ID_EX_Reg.sv
archgen-5pipe-stall/core/EX_Mem_Reg.sv
archgen-5pipe-stall/core/Mem_WB_Reg.sv

// Hazard control (stall-based, no forwarding)
archgen-5pipe-stall/core/Hazard_Control_Unit.sv
// Dead code (not instantiated in toplevel, reserved for future bypass pipeline):
// archgen-5pipe-stall/core/Forwarding_Unit.sv

// Toplevel
archgen-5pipe-stall/core/toplevel.sv

// Testbench
dv/5pipe-stall/tb_top.sv
