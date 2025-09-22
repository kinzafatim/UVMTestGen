# UVMTestGen

UVMTestGen is a tool designed to automate test case generation for UVM-based verification environments using Large Language Models (LLMs).
It takes inputs from the Verification Platform (VP) and leverages LLMs to produce ready-to-use testcases for verification, significantly streamlining the verification workflow and reducing manual effort.

## 📜 Overview

Functional verification in hardware design often involves creating a large number of testcases to validate all features defined in the Verification Plan (VP).
UVMTestGen simplifies this by:

- Reading the Verification Plan.
- Automatically generating UVM-compatible testcases.
- Ensuring full coverage of functional features.

This eliminates repetitive manual work and reduces the risk of missing critical test scenarios.

## 🏗 UVM Architecture

The overall UVM testbench architecture as shown below:

![UVM Architecture](/uvm_test.svg)
