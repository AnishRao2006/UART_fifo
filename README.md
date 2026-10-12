# Configurable UART with FIFO & Robust Verification

A highly parameterizable RTL design integrating a Universal Asynchronous Receiver-Transmitter (UART) core with integrated TX/RX FIFOs. The design features adjustable data widths, configurable FIFO depths, and a programmable baud rate generator. It is verified using a hybrid approach combining a comprehensive Universal Verification Methodology (UVM) testbench and SystemVerilog Assertions (SVA).

---

## Key Architecture & Parameterization
* **Configurable Data Width:** Supports varying payload widths (e.g., 5, 6, 7, 8, or 9 bits).
* **Adjustable FIFO Depth:** Parameterized depth for both transmit and receive queues to prevent buffer overflow/underflow under varying load conditions.
* **Programmable Baud Rate:** Configurable clock-divider logic supporting custom baud rates and oversampling requirements.
* **Hardware Status Flags:** Built-in full and empty for safe flow control.

---

## Verification Methodology

### 1. Universal Verification Methodology (UVM) Environment
The design is verified using a class-based UVM architecture that ensures automated, coverage-driven verification:
* **Modular Agents:** Separate TX and RX interface agents containing drivers, monitors, and sequencers to drive transactions and capture signals.
* **Scoreboard & Self-Checking:** Automated data-integrity checking that compares transmitted data packets against received packets through an internal reference model.
* **Constrained-Random Sequences:** Generates corner-case traffic patterns, including fill-to-drain, drain-to-empty, directed data transmission and receiving test cases.
* **Functional Coverage:** Monitors and covergroups track received data, FIFO threshold crossings to check each of them is hit.

### 2. SystemVerilog Assertions (SVA)
Immediate and concurrent assertions are embedded across the RTL and interface wrappers to continuously monitor protocol compliance and design invariants:
* **FIFO Integrity:** Assertions ensure that read/write pointers never wrap incorrectly and that full/empty flags accurately reflect pointer metrics.
* **Protocol Safety:** Checks for illegal serial transitions, start/stop bit violations, and clock-domain safety.

---

## Repository Structure
* `UART_fifo.srcs/` - RTL source files, SVA assertion bindings, testbench components, and UVM environment classes.
* `UART_fifo.xpr/` - Vivado project file.

---

## Getting Started
1. Open the project in AMD Vivado using `UART_fifo.xpr`.
2. Compile and run simulations using your preferred UVM-enabled simulator (e.g., Questa, Xcelium, or Vivado Simulator with UVM/SVA package support).
