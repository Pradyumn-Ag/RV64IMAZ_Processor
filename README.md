# ⚡ RV64IMAZ Fully Pipelined RISC-V Processor

## 📌 Project Overview
This repository contains the complete RTL (Register Transfer Level) design of a 64-bit RISC-V microprocessor. Built entirely in **Verilog HDL**, this core implements the **RV64IMAZ** instruction set architecture, optimized for high-performance execution, SoC (System on Chip) integration, and low-power edge computing applications.

The design features a classic **5-stage pipeline** augmented with advanced hazard detection, data forwarding, and dynamic branch prediction to maximize Instruction Per Cycle (IPC) throughput and minimize pipeline stalls.

## 🏗️ Architectural Specifications
* **Base ISA:** RV64I (64-bit Integer operations)
* **Extensions Supported:** * `M` (Integer Multiplication and Division)
  * `A` (Atomic Instructions)
  * `Z` (Standard Extensions)
* **Datapath:** 64-bit fully pipelined architecture.
* **Pipeline Depth:** 5 Stages (Fetch, Decode, Execute, Memory, Writeback).
* **Operating Modes:** Machine Mode (M-Mode) support.

---

## ⚙️ Core Modules & Pipeline Breakdown

### 1. Instruction Fetch (IF)
* **Program Counter (PC) Logic:** Handles sequential execution and jumps.
* **Instruction Memory:** Stores the compiled RISC-V binaries.
* **Branch Predictor:** A dedicated `tb_branch_predictor` module mitigates control hazards by predicting branch outcomes early, significantly reducing the penalty of pipeline flushes.

### 2. Instruction Decode (ID)
* **Main Decoder & ALU Decoder:** Generates control signals for the rest of the datapath based on the fetched opcode.
* **Register File (`Regfile.v`):** 32 x 64-bit general-purpose registers with dual-read and single-write ports.
* **Sign Extension Unit (`Extend_Unit.v`):** Formats immediate values for various instruction types (I, S, B, U, J).

### 3. Execute (EX)
* **Arithmetic Logic Unit (`ALU.v`):** Executes 64-bit arithmetic, logical, and shift operations. 
* **Branch Target Adder:** Computes the destination address for branching instructions.

### 4. Memory Access (MEM)
* **Data Memory (`Data_Memory.v`):** Handles load and store operations.
* **Store Unit (`Store_unit.v`):** Aligns and formats byte/half-word/word/double-word data for memory storage.

### 5. Writeback (WB)
* **Muxing Logic:** Selects between ALU results, Memory read data, or PC+4 to write back to the destination register.

---

## 🛡️ Hazard Management
Pipelined architectures inherently suffer from data and control dependencies. This core solves these using a dedicated **Hazard Unit (`Hazard_Unit.v`)**:
* **Data Forwarding (Bypassing):** Intercepts results from the EX/MEM and MEM/WB pipeline registers and feeds them directly back to the ALU inputs, resolving Read-After-Write (RAW) data hazards without stalling.
* **Pipeline Stalling:** Detects Load-Use hazards and inserts NOPs (bubbles) into the pipeline only when forwarding cannot resolve the dependency.
* **Control Hazard Resolution:** Flushes the IF and ID stages immediately upon detecting a branch misprediction.

---

## 🛠️ Tech Stack & EDA Tools
* **Hardware Description Language:** Verilog HDL
* **Simulation & Synthesis:** Xilinx Vivado (2024.2)
* **Waveform Analysis:** Vivado Simulator (XSim) / ModelSim
* **Version Control:** Git & GitHub

---

## 📁 Repository Structure
```text
RV64IMAZ_Processor/
├── RISCV_CORE/                 # Main RTL Source Directory
│   ├── RISCV_TOP.v             # Top-level integration of Datapath & Control
│   ├── Datapath.v              # Interconnects for pipeline registers
│   ├── Control_Path.v          # Centralized control signal generation
│   ├── Hazard_Unit.v           # Forwarding and stall detection
│   ├── ALU.v & ALU_Decoder.v   # Execution units
│   ├── Regfile.v               # 64-bit Architecture Registers
│   ├── Branch_Predictor.v      # Dynamic branch prediction logic
│   └── *.v                     # Additional multiplexers, adders, and DFFs
├── .gitignore                  # Excludes .vcd, .wdb, and local Vivado caches
└── README.md                   # Project documentation
