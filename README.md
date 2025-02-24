# RISC-V64 SoC with Floating-Point Support

## Overview
This project implements a **RISC-V64 System-on-Chip (SoC)** with support for integer and floating-point instructions. The design includes a **five-stage pipeline (IF, ID, EX, MEM, WB)**, a **floating-point unit (FPU)**, a **CSR (Control and Status Register) module**, and a **basic branch prediction mechanism**.

## Features
- **64-bit RISC-V Core** with integer and floating-point execution.
- **Pipelined Architecture** for improved performance.
- **Floating-Point Register File (FPRF)** and Floating-Point Control and Status Register (FCSR).
- **CSR instructions** for handling floating-point exceptions and rounding modes.
- **Basic Branch Prediction (Assume Not Taken).**
- **Memory subsystem with data read/write support.**
- **Support for RISC-V base integer instructions, multiplication/division, and atomic operations.**

## Architecture
The design follows a standard five-stage pipeline:
1. **Instruction Fetch (IF):** Fetches instructions from memory and updates the program counter.
2. **Instruction Decode (ID):** Decodes the instruction, reads registers, and identifies floating-point operations.
3. **Execute (EX):** Performs arithmetic/logic operations, invokes the ALU or FPU for computation.
4. **Memory Access (MEM):** Reads/writes data from memory.
5. **Write Back (WB):** Writes results back to the register file or floating-point register file.

## Pipeline Registers
To support pipelined execution, the design includes:
- **IF/ID:** Holds the instruction and program counter.
- **ID/EX:** Stores decoded instruction fields and register values.
- **EX/MEM:** Holds ALU/FPU computation results and memory addresses.
- **MEM/WB:** Stores the final result before writing back to the registers.

## Floating-Point Unit (FPU) Integration
- Detects **RV64F/D instructions** (opcode = `1010011`).
- Uses a **dedicated floating-point register file (FPRF)**.
- Updates the **FCSR** with exception flags and rounding modes.
- Supports **floating-point arithmetic operations** via an instantiated `fpu_core` module.

## Control and Status Register (CSR)
- Implements CSR instructions (`FSCSR`, `FRCSR`, `FSCVTX`, etc.).
- Supports exception flag management.
- Enables setting and reading the floating-point rounding mode.

## Memory System
- Implements a **memory array (64K entries)**.
- Supports **load (`LW`) and store (`SW`) instructions**.
- Memory write enable (`mem_write`) is controlled by store instructions.

## Branch Prediction
- Implements a **simple static predictor** (assume branches are not taken).
- Updates the program counter accordingly.

## How to Use
### **Simulation and Testing**
- The design can be simulated using Verilog-based simulation tools such as **ModelSim**.
- A testbench should provide:
  - A clock and reset signal.
  - Instruction and data memory initialization.
  - Verification of pipeline execution and floating-point operations.

### **FPGA Implementation**
- This design can be synthesized for FPGA targets.
- Ensure memory interfaces align with on-chip block RAM.

## Future Enhancements
- Implement **out-of-order execution** for improved performance.
- Add **caches (L1/L2) and MMU support**.
- Improve **branch prediction (dynamic schemes)**.
- Extend support for **RISC-V Vector (RVV) extensions**.


## Contributors
- Bintu Kappil George
- Open for contributions! Feel free to fork and submit PRs.

## Acknowledgments
This project follows the **RISC-V ISA Specification** and integrates key concepts from modern processor design principles.
