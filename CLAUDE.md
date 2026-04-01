# ArchGen-AI-generated-cores

## Project Structure
```
archgen-single/core/       # Single-cycle RV32I core (18 SV files)
archgen-5pipe-stall/core/  # 5-stage pipeline RV32I core (29 SV files)
dv/                        # Verification infrastructure
  riscv-dv/                # git submodule (chipsalliance/riscv-dv)
  common/                  # Shared: config.sv, constants.sv, link.ld, scripts
  single/                  # Single-cycle TB + files.f
  5pipe-stall/             # Pipeline TB + files.f
  target/archgen_rv32i/    # RISCV-DV testlist.yaml
  tests/                   # Hand-written smoke_test.S
  Makefile                 # Top-level verification flow
  out/                     # Build artifacts (gitignored)
```

## Architecture
- RV32I only (no CSR, no M extension, no fence)
- INITIAL_PC = TEXT_BEGIN = DATA_BEGIN = 0x00400000
- Harvard architecture: InstMem[PC[15:2]], DataMem[addr[16:2]]

## Verification Flow
```
make -C dv smoke_single           # Smoke test single-cycle
make -C dv smoke_5pipe            # Smoke test pipeline
make -C dv run_single TEST=<t> SEED=<n>  # RISCV-DV flow
make -C dv regress CORE=single    # Regression
```

## Tools Required
- VCS T-2022.06+, Spike 1.1.1-dev+, riscv64-unknown-elf-gcc, Python 3.12+

## Coding Conventions
- RTL comments in Chinese (existing codebase convention)
- DV code comments in English
- Pipeline debug ports marked with `// for trace (debug)` comments

## Known Issues

### Pipeline Core - JALR Instruction Bug (CRITICAL)

**Status**: FAILED in `riscv_load_store_test_seed1`
**Date**: 2026-04-01
**Severity**: High - causes complete trace divergence

#### Failure Details

**Location**: PC=0x0040073c
**Instruction**: `jalr a6, a6, 0` (binary: 0x00080867)

**Expected Behavior (Spike ISS)**:
```
Line 137: PC=0x00400738  mv a6, ra        -> a6=0x0040012c (ra value)
Line 138: PC=0x0040073c  jalr a6, a6, 0   -> a6=0x00400740, jump to 0x0040012c
Line 139: PC=0x0040012c  lui t5, 0xf7475  -> t5=0xf7475000
```

**Actual Behavior (RTL)**:
```
Line 179: PC=0x00400738  mv a6, ra        -> a6=0x0040012c
Line 180: PC=0x0040073c  jalr a6, a6, 0   -> (no register update shown)
Line 181: PC=0x0040012c  lui t5, 0xf7475  -> t5=0xf7475000  ✓ Correct jump target
Line 182: PC=0x00400130  auipc t6, 0x0    -> t6=0x00400130  ✓ Sequential execution
```

**Problem**: RTL跳转到了正确的目标地址(0x0040012c)，但后续执行流程与Spike完全不同步：
- Spike在0x0040012c执行后继续顺序执行
- RTL在0x0040012c执行后trace显示不同的指令序列
- 最终导致321,516条指令不匹配

#### Assembly Context

```asm
00400738:  00008813    mv   a6, ra         # a6 = 0x0040012c (return address)
0040073c:  00080867    jalr a6, a6, 0      # Jump to a6, save PC+4 to a6
                                            # Expected: jump to 0x0040012c
                                            #           a6 = 0x00400740

# Target location (should be executed after jalr):
0040012c:  f7475f37    lui  t5, 0xf7475
00400130:  00000f97    auipc t6, 0x0
00400134:  610f8f93    addi t6, t6, 1552
...

# Return target (where a6 should point after jalr):
00400740 <sub_1>:
00400740:  008d9863    bne  s11, s0, 400750
```

#### Root Cause Analysis

**Suspected Modules**:
1. **JALR_Adjust.sv** - JALR地址对齐逻辑(清除LSB)
2. **Hazard_Control_Unit.sv** - Pipeline flush信号生成
3. **NextPC_Decision_Unit.sv** - 跳转目标选择
4. **ID_EX_Reg.sv / EX_Mem_Reg.sv** - Pipeline寄存器传递

**可能原因**:
1. JALR的rd写回值(PC+4)计算错误或时序问题
2. Pipeline flush时IF/ID寄存器未正确清空
3. 跳转目标地址计算正确，但rd写回与PC更新的时序冲突
4. Hazard检测逻辑在JALR后未正确处理数据依赖

#### Debug Steps

1. **波形分析** (优先):
   ```bash
   cd dv/out/5pipe-stall/riscv_load_store_test_seed1
   verdi -ssf dump.vcd &
   # 搜索时间点: PC=0x0040073c附近
   # 关注信号: pc_WB, inst_WB, rd_WB, wb_data_WB, RegWrite_WB
   #           NextPC, PC_Src, flush信号
   ```

2. **对比single-cycle核**:
   ```bash
   make run_single TEST=riscv_load_store_test SEED=1
   # single核同样的测试PASSED，对比其JALR执行
   ```

3. **检查关键信号**:
   - `dut.mem_wb_reg.wb_data_WB` 在PC=0x0040073c时应为0x00400740
   - `dut.reg_file_inst` 的x16(a6)写入时序
   - `dut.hazard_control.flush_IF`, `flush_ID`, `flush_EX`状态

4. **简化测试**:
   ```asm
   # 创建最小JALR测试用例
   li   ra, 0x00400100
   jalr a6, ra, 0      # 应跳转到0x00400100, a6=PC+4
   # 在0x00400100放置已知指令序列
   ```

#### Workaround

暂无。该bug影响所有包含JALR的复杂测试。

#### Test Results Summary

- Single-cycle core: **12/12 PASSED** ✓
- Pipeline core: **4/5 PASSED** (仅此JALR相关测试失败)

#### Related Files

- `archgen-5pipe-stall/core/JALR_Adjust.sv`
- `archgen-5pipe-stall/core/Hazard_Control_Unit.sv`
- `archgen-5pipe-stall/core/NextPC_Decision_Unit.sv`
- `archgen-5pipe-stall/core/Mem_WB_Reg.sv`
- `dv/out/5pipe-stall/riscv_load_store_test_seed1/compare.log`
- `dv/out/5pipe-stall/riscv_load_store_test_seed1/rtl_trace.log`
- `dv/out/5pipe-stall/riscv_load_store_test_seed1/spike_trace.csv`
