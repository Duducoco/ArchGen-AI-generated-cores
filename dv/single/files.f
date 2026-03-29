// VCS file list for archgen-single core verification
// Paths relative to project root (PROJ_ROOT)

// Include directories
+incdir+dv/common

// DV common config (overrides RTL config.sv with plusargs enabled)
dv/common/config.sv
dv/common/constants.sv

// RTL source files
archgen-single/core/PC.sv
archgen-single/core/InstMem.sv
archgen-single/core/DataMem.sv
archgen-single/core/Decoder.sv
archgen-single/core/ImmGen.sv
archgen-single/core/Controller.sv
archgen-single/core/RegFile.sv
archgen-single/core/ALU.sv
archgen-single/core/Mux_ALUSrc1.sv
archgen-single/core/Mux_ALUSrc2.sv
archgen-single/core/Mux_RegWriteData.sv
archgen-single/core/Mux_NextPC.sv
archgen-single/core/PC_Plus4_Adder.sv
archgen-single/core/PC_PlusImm_Adder.sv
archgen-single/core/NextPC_Decision_Unit.sv
archgen-single/core/JALR_Adjust.sv
archgen-single/core/DataMem_interface_Unit.sv
archgen-single/core/toplevel.sv

// Testbench
dv/single/tb_top.sv
