# [cite_start]Design and Implementation of a Motion Control System Using DC Motor and STM32 Microcontroller [cite: 10, 11]

[cite_start]This repository contains the source code, simulation models, and documentation for a model-based digital motion control system[cite: 674]. [cite_start]The project focuses on achieving precise and repeatable position control of a DC motor using an STM32F407 microcontroller, a discrete PID controller, and MATLAB-based system identification[cite: 30, 32, 33, 34].

---

## 📌 Project Overview
* [cite_start]**Target:** Precise 90° positioning ($\approx$ 515 encoder counts) with minimal overshoot and fast settling time[cite: 30].
* [cite_start]**Challenges Addressed:** Nonlinearities such as gearbox friction, PWM deadzone, and sensor quantization noise[cite: 30, 655, 658].
* [cite_start]**Workflow:** Hardware Prototyping → Open-Loop System Identification → Controller Design & Discretization → Simulation Validation → Real-Time Hardware Telemetry[cite: 674].

---

## [cite_start]⚙️ System Architecture [cite: 17]

### 1. Hardware Components
[cite_start]The prototype is built with cost-efficiency and performance in mind, totaling a hardware cost of approximately $38.50[cite: 106]:
* [cite_start]**MCU:** STM32F407VG Discovery Board (168 MHz ARM Cortex-M4) [cite: 92, 96]
* [cite_start]**Actuator:** 12V DC Motor with Quadrature Encoder (2060 pulses/rev in X4 mode) [cite: 98, 404]
* [cite_start]**Motor Driver:** L298N H-Bridge (Dual full-bridge driver) [cite: 94, 99]
* [cite_start]**Telemetry:** CH340 USB-UART module for real-time monitoring [cite: 95, 101]

### 2. System Diagram & Connections
* [cite_start]**PWM Generation:** `TIM1` configured to output a PWM signal on pin `PE9`[cite: 380].
* [cite_start]**Encoder Feedback:** `TIM2` operating in X4 Quadrature Decoding mode tracking channels A and B (`PA5`, `PB3`) with 4.7 kΩ pull-up resistors to the 3.3V rail[cite: 380, 382].
* [cite_start]**Serial Interface:** `USART2` running at 115200 baud (`PA2`/`PA3`) feeding live data into the PC via Teleplot[cite: 383].

<p align="center">
  <img src="Result/System%20Overview.png" alt="System Overview" width="90%">
</p>

---

## [cite_start]📊 Methodology & Mathematical Modeling [cite: 19]

### Open-Loop System Identification (MATLAB)
[cite_start]Using an open-loop experiment (PWM = 450) collecting 84 data points over 0.83 seconds, three models were compared using `tfest()`[cite: 411, 412, 417, 418]:
* [cite_start]**TF(1p):** 12.05% fit (Rejected) [cite: 437, 439]
* [cite_start]**TF(2p, 1z):** 98.09% fit (Rejected due to unnecessary complexity) [cite: 437, 452, 453]
* [cite_start]**TF(2p, 0z):** **99.51% fit (Selected)** [cite: 437, 441]

[cite_start]The identified plant transfer function is[cite: 406]:
$$G(s) = \frac{8.9958}{s^2 + 3.9716s + 2.531 \times 10^{-4}}$$

---

## 💻 Hardware Verification & PID Tuning

### Signal Verification
[cite_start]Before running closed-loop tests, the generated PWM control signals were fully verified using a digital oscilloscope[cite: 369, 372]:

<p align="center">
  <img src="Result/Oscilloscope%20Measurement.png" alt="Oscilloscope Measurement" width="80%">
</p>

### [cite_start]PID Controller Design [cite: 20]
[cite_start]Automated optimization was conducted via MATLAB's `pidtune()`, then manually adjusted to suppress derivative quantization noise in hardware[cite: 34, 500]:

| Parameter | Continuous (MATLAB) | Discrete (Firmware, $Ts = 10\text{ ms}$) |
| :--- | :--- | :--- |
| **Kp** | 4.1671 | [cite_start]4.1671 (unchanged) [cite: 501] |
| **Ki** | 4.2523 | [cite_start]0.0425 (x Ts) [cite: 501] |
| **Kd** | 91.17 | [cite_start]3.0 (adjusted for noise) [cite: 501] |

### Simulation Results
[cite_start]The optimized PID parameters yielded a **49% faster settling time** compared to manual tuning (reduced from 3.73s to 1.90s)[cite: 586, 591, 592]:

<p align="center">
  <img src="Result/Manual%20vs.%20Optimized%20PID%20Response.png" alt="Manual vs Optimized PID" width="80%">
</p>

---

## [cite_start]📈 Real-Time Hardware Performance [cite: 22]

[cite_start]The embedded firmware runs inside a 10 ms control loop using a Finite State Machine (FSM)[cite: 509, 563]:
* **Anti-Windup:** Integral accumulates only when $|error| [cite_start]< 100$[cite: 568].
* **Deadzone & Stiction Compensation:** PWM cut to 0 when $|error| [cite_start]\le 6$ counts, with a +40 PWM offset to overcome static friction[cite: 568, 569].

### [cite_start]Telemetry Profiles & Prototype [cite: 22, 35]

<table align="center">
  <tr>
    <td align="center"><b>Hardware Setup Prototype</b></td>
    <td align="center"><b>Target Position (Step Input)</b></td>
  </tr>
  <tr>
    <td align="center"><img src="Result/Hardware%20Prototype.png" width="100%" alt="Hardware Prototype"></td>
    <td align="center"><img src="Result/Real-time%20Telemetry%20Data%20-%20Target.png" width="100%" alt="Target Position"></td>
  </tr>
  <tr>
    <td align="center"><b>Actual Encoder Position</b></td>
    <td align="center"><b>Bidirectional PWM Output</b></td>
  </tr>
  <tr>
    <td align="center"><img src="Result/Real-time%20Telemetry%20Data%20-%20Encoder.png" width="100%" alt="Encoder Position"></td>
    <td align="center"><img src="Result/Real-time%20Telemetry%20Data%20-%20PWM.png" width="100%" alt="PWM Output"></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><b>Transient Position Error</b></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="Result/Real-time%20Telemetry%20Data%20-%20Error.png" width="60%" alt="Position Error"></td>
  </tr>
</table>

---

## [cite_start]🚀 Future Work [cite: 25]
* [cite_start]Custom PCB to reduce electromagnetic interference (EMI)[cite: 669].
* [cite_start]Implementing trapezoidal motion profiling for smoother transitions[cite: 670].
* [cite_start]Developing advanced controller variants such as LQR or Fuzzy Logic control[cite: 671].

---

## 👥 Author & Information
* [cite_start]**Developer:** Do Buu Phuoc (EEACIU21137) [cite: 12]
* [cite_start]**Advisor:** Dr. Nguyen Van Binh [cite: 12]
* [cite_start]**Institution:** School of Electrical Engineering, International University, VNU-HCMC [cite: 7, 13]
* [cite_start]**Date:** June 2026 [cite: 13]
