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

### Pipeline Core - JALR Write-Back Bug (CRITICAL)

**Status**: ROOT CAUSE IDENTIFIED - 2026-04-18 大规模回归显示几乎所有含JALR测试均失败
**Date**: 2026-04-01 (首次发现), 2026-04-18 (定位根因)
**Severity**: Critical - 影响所有JALR后存在数据相关的情况（即绝大多数函数调用/返回）

#### 回归失败统计 (2026-04-18)

| 测试类型 | 失败率 | 说明 |
|---------|--------|------|
| riscv_jump_branch_test | ~95% | 跳转密集型 |
| riscv_load_store_test | ~95% | load/store后接JALR |
| ds_ls_rand / ds_ls_stress | ~100% | 数据相关后接JALR |
| ds_branch_medium / ds_branch_dense | ~90% | 分支+JALR |
| ds_rand_medium / ds_rand_large | ~90% | 随机含函数调用 |
| ds_arith_short / ds_arith_long | 0% | 纯算术，无JALR ✓ |
| ds_rand_tiny | 0% | 极短，未触发该场景 ✓ |

#### 根本原因 (已确认)

**文件**: `archgen-5pipe-stall/core/Hazard_Control_Unit.sv`, **第105行**

```systemverilog
// 当前（有bug）:
assign jal_one_regfile_write_eanble = (control_hazard_flag && !data_hazard_flag &&
    ((current_state==IDLE) && (next_state == CONTROL_STALL)));
```

**触发条件**: JALR的rs1寄存器与流水线中某条正在执行的指令存在数据相关（写后读）。

**FSM路径问题**:
1. JALR进入ID级，同时存在数据冲突 → FSM进入 `DATA_STALL`
2. 数据冲突解除，控制冲突仍然存在 → FSM转移到 `CONTROL_STALL`
3. `jal_one_regfile_write_eanble` 只检查 `current_state==IDLE`，**不覆盖** `DATA_STALL→CONTROL_STALL` 路径
4. 结果：JALR的 `RegWrite=0`，返回地址（PC+4）**永远不写入rd**
5. 但跳转目标地址正确（`non_branch_case` 从 `CONTROL_STALL→CONTROL_UPDATE` 触发，与入口路径无关）

**表现**: RTL的trace中JALR条目消失（因RegWrite=0，WB级没有写操作，trace不记录该指令），后续代码使用rd时得到错误的旧值，导致完全执行流偏移。

**示例** (`riscv_jump_branch_test_seed4126`):
```
Spike[140]: pc=0x00400820  jalr a3,a3,0  -> a3=0x00400824  (写回PC+4)
RTL[140]:   pc=0x00400270  auipc a6,0x0  -> a6=0x00400270  (JALR被跳过，直接执行target处指令)
```

#### 修复方案

**一行改动** (`Hazard_Control_Unit.sv:105`):

```systemverilog
// 修复后：覆盖 IDLE→CONTROL_STALL 和 DATA_STALL→CONTROL_STALL 两条路径
assign jal_one_regfile_write_eanble = (control_hazard_flag && !data_hazard_flag &&
    (next_state == CONTROL_STALL));
```

`next_state == CONTROL_STALL` 仅在以下两种情况为真：
- `IDLE → CONTROL_STALL`（无数据冲突，纯控制冲突）✓ 原本已正确
- `DATA_STALL → CONTROL_STALL`（数据冲突解除后进入控制冲突）✓ 原来漏掉的情况

不会产生双写：JALR在CONTROL_STALL期间保持在ID级（stall_if_id=1），下一拍
（CONTROL_STALL→CONTROL_UPDATE）时 `next_state==CONTROL_UPDATE`，jal_one_regfile_write_eanble=0。

#### 相关文件

- **需修改**: `archgen-5pipe-stall/core/Hazard_Control_Unit.sv`（第105行）
- `archgen-5pipe-stall/core/Controller.sv`（JALR的RegWrite门控逻辑）
- `dv/out/5pipe-stall/riscv_jump_branch_test_seed4126/compare.log`（典型失败案例）
