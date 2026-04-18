# Pipelined Softmax Hardware Accelerator

![Language](https://img.shields.io/badge/Language-Verilog--2001-blue)
![Architecture](https://img.shields.io/badge/Architecture-Pipelined_FSM-success)
![Math](https://img.shields.io/badge/Math-Q16.16_Fixed_Point-orange)
![Verification](https://img.shields.io/badge/Verification-100%25_Pass-brightgreen)

A deterministic, cycle-accurate, and fully pipelined Softmax hardware accelerator designed from scratch in standard Verilog-2001. Built for high-performance deep neural network (DNN) inference on FPGAs and ASICs, this module mathematically calculates 10-class probability distributions entirely in hardware—eliminating the latency and resource overhead of software loops and floating-point processors.

---

## What is Softmax and Why is it Used?

In Machine Learning, a neural network classifying an image (like a handwritten digit from the MNIST dataset) outputs raw, unnormalized scores called **logits**. These numbers can range from $-\infty$ to $+\infty$ and are difficult to interpret.

The **Softmax function** takes these raw logits and squashes them into a normalized probability distribution where every value is between $0$ and $1$, and all values sum to exactly $1.0$. 

$$P_i = \frac{e^{Z_i - \max(Z)}}{\sum_{j=0}^{N-1} e^{Z_j - \max(Z)}}$$

By placing this function at the final layer of a classifier, the network outputs a clear "confidence percentage" for each class, allowing the system to easily pick the most probable prediction.

---

## Hardware Engineering Challenges & Solutions

Implementing Softmax in software (Python/C++) is a single line of code. Implementing it in hardware requires solving several severe bottlenecks:

1. **The Exponential Problem ($e^x$):** Hardware hates non-linear functions. Calculating infinite series in silicon wastes massive amounts of area.
   * *Solution:* Implemented a highly optimized Look-Up Table (LUT) with a step-size of 0.5. To prevent integer overflow, the hardware first finds and subtracts the maximum input logit from all other inputs, ensuring all exponential inputs are $\le 0$ ($e^x$ is strictly bounded between $0$ and $1$).
2. **The Division Problem ($1/x$):** Standard binary division is notoriously slow and stalls processing pipelines.
   * *Solution:* Replaced traditional division with a 2-cycle **Newton-Raphson division** module. The hardware uses a pre-calculated initial guess and iterative multiplication to find the reciprocal extremely fast.
3. **The Floating-Point Penalty:** IEEE-754 floating-point math consumes immense DSP and logic resources.
   * *Solution:* Engineered the entire data path using **Q16.16 Fixed-Point Arithmetic**. This maintains decimal precision for neural network inference while allowing the use of fast, standard integer adders and multipliers.

---

## What This Project Achieves

* **Deterministic Latency:** The master FSM guarantees a prediction in exactly **26 clock cycles**.
* **Parallel Processing:** Calculates 10 exponentials and scales 10 probabilities simultaneously using unrolled parallel data paths.
* **Mathematical Robustness:** Safely handles dead-ties, absolute zeros, and massive extreme outliers without overflowing or locking up.
* **Synthesis-Ready:** Written in strict, synthesizable Verilog-2001, making it highly portable to any Xilinx, Intel, or ASIC standard cell library.

---

## 📂 File Structure & Module Descriptions

```text
softmax-hardware-accelerator/
├── rtl/                    # Source code for the accelerator
│   ├── softmax_top.v       # Master FSM: Orchestrates data flow across all 7 stages.
│   ├── max_function.v      # Stage 1: 4-cycle pipelined tree to find the maximum logit.
│   ├── subtract.v          # Stage 2: 3-cycle FSM that normalizes the 10 inputs.
│   ├── exp_top.v           # Stage 3: Wrapper to parallelize the 10 exponential LUTs.
│   ├── exp.v               # Stage 3: 1-cycle latency Exponential LUT.
│   ├── adder_tree.v        # Stage 4: 4-cycle pipelined tree to sum all exponentials.
│   ├── reciprocal.v        # Stage 5: 2-cycle Newton-Raphson division for 1/sum.
│   ├── multiplier.v        # Stage 6: 1-cycle parallel scaling to find probabilities.
│   └── argmax.v            # Stage 7: 10-cycle FSM to predict the highest probability class.
|
├── sim/                    # Testbenches
│   ├── exp_tb.v            # Unit test verifying the 0.5 step-size exponential LUT.
│   ├── adder_tree_tb.v     # Unit test for the 4-cycle summation pipeline.
│   ├── reciprocal_tb.v     # Unit test checking the Newton-Raphson division accuracy.
│   ├── multiplier_tb.v     # Unit test verifying the Q16.16 probability scaling.
│   ├── argmax_tb.v         # Unit test checking the max-finding and tie-breaking logic.
│   └── softmax_stress_tb.v # The primary 20-case self-checking verification suite.
|
└── README.md
```
## Verification & Results

The architecture has achieved a **100% Pass Rate** against a rigorous, automated self-checking testbench (`softmax_stress_tb.v`). The verification suite tests 20 distinct corner cases, including:

* **Realistic MNIST Data:** 10 test vectors directly mirroring logit distributions from a real neural network classifying handwritten digits (e.g., highly confident predictions, confused classes, and blurry inputs).
* **The "Flatline":** All zero inputs and all uniform large inputs to ensure divider stability and subtractor saturation.
* **Extreme Outliers:** Deep negative two's complement boundaries and massive positive spikes.
* **Exact Mathematical Ties:** Proving the hardware's deterministic tie-breaking logic predictability.

### Final Pipeline Latency

| Stage | Operation | Cycles |
| :--- | :--- | :---: |
| 1 | Max Finder | 4 |
| 2 | Subtractor | 3 |
| 3 | Exponential LUT | 1 |
| 4 | Adder Tree | 4 |
| 5 | Newton-Raphson Reciprocal | 2 |
| 6 | Parallel Multipliers | 1 |
| 7 | Argmax Predictor | 10 |
| **Total** | **Hardware Prediction Latency** | **25+1 = 26 Cycles** |

---

## How to Run the Simulation

To execute the verification suite locally:

1. Clone this repository to your local machine.
2. Create a new RTL project in **Xilinx Vivado** (or ModelSim/Verilator).
3. Add all `.v` files from the `/rtl/` directory to your **Design Sources**.
4. Add all `.v` files from the `/sim/` directory to your **Simulation Sources**.
5. Set `softmax_stress_tb.v` as the **Top Module** in your simulation settings.
6. Run Behavioral Simulation. 
7. Ensure your simulator is set to run for at least `6500 ns` (or type `run all` in the Vivado TCL console) to allow all 20 stress tests to complete and view the self-checking log.
