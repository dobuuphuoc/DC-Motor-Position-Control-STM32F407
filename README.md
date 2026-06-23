# Design and Implementation of a Motion Control System Using DC Motor and STM32 Microcontroller



This repository contains the source code, simulation models, and documentation for a model-based digital motion control system. The project focuses on achieving precise and repeatable position control of a DC motor using an STM32F407 microcontroller, a discrete PID controller, and MATLAB-based system identification.



---



## 📌 Project Overview

* **Target:** Precise 90° positioning ($\approx$ 515 encoder counts) with minimal overshoot and fast settling time.

* **Challenges Addressed:** Nonlinearities such as gearbox friction, PWM deadzone, and sensor quantization noise.

* **Workflow:** Hardware Prototyping → Open-Loop System Identification → Controller Design & Discretization → Simulation Validation → Real-Time Hardware Telemetry.



---



## ⚙️ System Architecture



### 1. Hardware Components

The prototype is built with cost-efficiency and performance in mind, totaling a hardware cost of approximately $38.50:

* **MCU:** STM32F407VG Discovery Board (168 MHz ARM Cortex-M4)

* **Actuator:** 12V DC Motor with Quadrature Encoder (2060 pulses/rev in X4 mode)

* **Motor Driver:** L298N H-Bridge (Dual full-bridge driver)

* **Telemetry:** CH340 USB-UART module for real-time monitoring



### 2. System Diagram & Connections

* **PWM Generation:** `TIM1` configured to output a PWM signal on pin `PE9`.

* **Encoder Feedback:** `TIM2` operating in X4 Quadrature Decoding mode tracking channels A and B (`PA5`, `PB3`) with 4.7 kΩ pull-up resistors to the 3.3V rail.

* **Serial Interface:** `USART2` running at 115200 baud (`PA2`/`PA3`) feeding live data into the PC via Teleplot.



<p align="center">

  <img src="Result/System Overview.png" alt="System Overview" width="90%">

</p>



---



## 📊 Methodology & Mathematical Modeling



### Open-Loop System Identification (MATLAB)

Using an open-loop experiment (PWM = 450) collecting 84 data points over 0.83 seconds, three models were compared using `tfest()`:

* **TF(1p):** 12.05% fit (Rejected)

* **TF(2p, 1z):** 98.09% fit (Rejected due to unnecessary complexity)

* **TF(2p, 0z):** **99.51% fit (Selected)**



The identified plant transfer function is:

$$G(s) = \frac{8.9958}{s^2 + 3.9716s + 2.531 \times 10^{-4}}$$



---



## 💻 Hardware Verification & PID Tuning



### Signal Verification

Before running closed-loop tests, the generated PWM control signals were fully verified using a digital oscilloscope:



<p align="center">

  <img src="Result/Oscilloscope Measurement.png" alt="Oscilloscope Measurement" width="80%">

</p>



### PID Controller Design

Automated optimization was conducted via MATLAB's `pidtune()`, then manually adjusted to suppress derivative quantization noise in hardware:



| Parameter | Continuous (MATLAB) | Discrete (Firmware, $Ts = 10\text{ ms}$) |

| :--- | :--- | :--- |

| **Kp** | 4.1671 | 4.1671 (unchanged) |

| **Ki** | 4.2523 | 0.0425 (x Ts) |

| **Kd** | 91.17 | 3.0 (adjusted for noise) |



### Simulation Results

The optimized PID parameters yielded a **49% faster settling time** compared to manual tuning (reduced from 3.73s to 1.90s):



<p align="center">

  <img src="Result/Manual vs. Optimized PID Response.png" alt="Manual vs Optimized PID" width="80%">

</p>



---



## 📈 Real-Time Hardware Performance



The embedded firmware runs inside a 10 ms control loop using a Finite State Machine (FSM):

* **Anti-Windup:** Integral accumulates only when $|error| < 100$.

* **Deadzone & Stiction Compensation:** PWM cut to 0 when $|error| \le 6$ counts, with a +40 PWM offset to overcome static friction.



### Telemetry Profiles & Prototype



<table align="center">

  <tr>

    <td align="center"><b>Hardware Setup Prototype</b></td>

    <td align="center"><b>Target Position (Step Input)</b></td>

  </tr>

  <tr>

    <td><img src="Result/Hardware Prototype.png" width="100%"></td>

    <td><img src="Result/Real-time Telemetry Data - Target.png" width="100%"></td>

  </tr>

  <tr>

    <td align="center"><b>Actual Encoder Position</b></td>

    <td align="center"><b>Bidirectional PWM Output</b></td>

  </tr>

  <tr>

    <td><img src="Result/Real-time Telemetry Data - Encoder.png" width="100%"></td>

    <td><img src="Result/Real-time Telemetry Data - PWM.png" width="100%"></td>

  </tr>

  <tr>

    <td colspan="2" align="center"><b>Transient Position Error</b></td>

  </tr>

  <tr>

    <td colspan="2" align="center"><img src="Result/Real-time Telemetry Data - Error.png" width="60%"></td>

  </tr>

</table>



---



## 🚀 Future Work

* Custom PCB to reduce electromagnetic interference (EMI).

* Implementing trapezoidal motion profiling for smoother transitions.

* Developing advanced controller variants such as LQR or Fuzzy Logic control.



---



## 👥 Author & Information

* **Developer:** Do Buu Phuoc (EEACIU21137)

* **Advisor:** Dr. Nguyen Van Binh

* **Institution:** School of Electrical Engineering, International University, VNU-HCMC

* **Date:** June 2026
