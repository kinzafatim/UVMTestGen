`ifndef BASE_TEST_SV
`define BASE_TEST_SV

`include "uvm_macros.svh"
// Include environment and sequences here
// `include "env.sv"
// `include "base_seq.sv"

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  // Declare environment handle
  my_env env;  // Replace 'my_env' with your environment name

  // Constructor
  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    base_seq seq;  // Replace with your base sequence name
    phase.raise_objection(this);

    `uvm_info("BASE_TEST", "Starting test...", UVM_LOW)

    seq = base_seq::type_id::create("seq");
    seq.start(env.agent.sequencer); // start sequence on agent's sequencer

    phase.drop_objection(this);
  endtask
endclass

`endif
