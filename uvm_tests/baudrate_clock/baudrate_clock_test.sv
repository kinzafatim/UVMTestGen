```systemverilog
// seq_item.sv
`ifndef SEQ_ITEM_SV
`define SEQ_ITEM_SV

`include "uvm_macros.svh"

class seq_item extends uvm_sequence_item;
  `uvm_object_utils(seq_item)

  // Define transaction variables
  rand bit [7:0] data;
  rand bit valid;

  function new(string name = "seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint c_valid { valid == 1; }

  function string convert2string();
    return $sformatf("data=%0d valid=%0b", data, valid);
  endfunction
endclass

`endif

// tx_seq.sv
`ifndef TX_SEQ_SV
`define TX_SEQ_SV

`include "uvm_macros.svh"
`include "seq_item.sv"

class tx_seq extends uvm_sequence #(seq_item);
  `uvm_object_utils(tx_seq)

  function new(string name = "tx_seq");
    super.new(name);
  endfunction

  // Sequence body: generate stimulus
  task body();
    seq_item req;

    `uvm_info("TX_SEQ", "Starting TX sequence", UVM_LOW)
    repeat (10) begin
      req = seq_item::type_id::create("req");
      assert(req.randomize());
      `uvm_info("TX_SEQ", $sformatf("Sending transaction: %s", req.convert2string()), UVM_MEDIUM)

      start_item(req);
      finish_item(req);
    end
  endtask
endclass

`endif

// env.sv
`ifndef ENV_SV
`define ENV_SV

`include "uvm_macros.svh"

class my_agent extends uvm_agent;
  `uvm_component_utils(my_agent)

  uvm_sequencer #(seq_item) sequencer;

  function new(string name = "my_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uvm_sequencer #(seq_item)::type_id::create("sequencer", this);
  endfunction
endclass


class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)

  uvm_queue #(seq_item) expected_q;
  uvm_queue #(seq_item) observed_q;

  function new(string name = "scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    seq_item expected, observed;
    phase.raise_objection(this);

    forever begin
      wait(expected_q.size() > 0 && observed_q.size() > 0);

      expected = expected_q.pop_front();
      observed = observed_q.pop_front();

      if (expected.data != observed.data || expected.valid != observed.valid) begin
        `uvm_error("SCOREBOARD", $sformatf("Mismatch! Expected: %s, Observed: %s", expected.convert2string(), observed.convert2string()))
      end else begin
        `uvm_info("SCOREBOARD", $sformatf("Match! Expected: %s, Observed: %s", expected.convert2string(), observed.convert2string()), UVM_MEDIUM)
      end
    end
    phase.drop_objection(this);
  endtask

  virtual function void write_expected(seq_item item);
    expected_q.push_back(item);
  endfunction

  virtual function void write_observed(seq_item item);
    observed_q.push_back(item);
  endfunction
endclass

class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  my_agent agent;
  scoreboard scb;

  rand bit [31:0] BR_CLK_I_freq;
  rand bit [7:0] BRDIVISOR;

  function new(string name = "my_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = my_agent::type_id::create("agent", this);
    scb = scoreboard::type_id::create("scb", this);

    // Configuration: Example constraints for BR_CLK_I_freq and BRDIVISOR
    if (!randomize()) `uvm_error("ENV", "Randomization failed for BR_CLK_I_freq and BRDIVISOR");
  endfunction

  virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Connect agent output to scoreboard here (example using TLM ports)
        // agent.data_out_port.connect(scb.data_in_export);
    endfunction

endclass

`endif

// baudrate_test.sv
`ifndef BAUDRATE_TEST_SV
`define BAUDRATE_TEST_SV

`include "uvm_macros.svh"
`include "env.sv"
`include "tx_seq.sv"

class baudrate_test extends uvm_test;
  `uvm_component_utils(baudrate_test)

  // Declare environment handle
  my_env env;

  // Constructor
  function new(string name = "baudrate_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    tx_seq seq;
    phase.raise_objection(this);

    `uvm_info("BAUDRATE_TEST", "Starting Baudrate test...", UVM_LOW)

    seq = tx_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif
```