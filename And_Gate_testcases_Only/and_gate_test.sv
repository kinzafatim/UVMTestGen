```systemverilog
ifndef AND_GATE_TEST_SV
`define AND_GATE_TEST_SV

`include "uvm_macros.svh"
// Include environment and sequences here
`include "and_env.sv"
`include "and_base_seq.sv"

class and_gate_test extends uvm_test;
  `uvm_component_utils(and_gate_test)

  // Declare environment handle
  and_env env;

  // Constructor
  function new(string name = "and_gate_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = and_env::type_id::create("env", this);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    and_base_seq seq;
    phase.raise_objection(this);

    `uvm_info("AND_GATE_TEST", "Starting AND gate test...", UVM_LOW)

    seq = and_base_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif
```