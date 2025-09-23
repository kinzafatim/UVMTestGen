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
  rand int baud_rate; // Add baud_rate

  function new(string name = "seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint c_valid { valid == 1; }
  constraint c_baud_rate { baud_rate inside {9600, 19200, 38400, 115200}; }

  function string convert2string();
    return $sformatf("data=%0d valid=%0b baud_rate=%0d", data, valid, baud_rate);
  endfunction
endclass

`endif


// base_seq.sv
`ifndef BASE_SEQ_SV
`define BASE_SEQ_SV

`include "uvm_macros.svh"
`include "seq_item.sv"

class base_seq extends uvm_sequence #(seq_item);
  `uvm_object_utils(base_seq)

  function new(string name = "base_seq");
    super.new(name);
  endfunction

  // Sequence body: generate stimulus
  task body();
    seq_item req;

    `uvm_info("BASE_SEQ", "Starting base sequence", UVM_LOW)
    repeat (10) begin
      req = seq_item::type_id::create("req");
      start_item(req);

      // Customize stimulus generation here
      assert(req.randomize());
      `uvm_info("BASE_SEQ", $sformatf("Sending item: %s", req.convert2string()), UVM_MEDIUM)
      
      finish_item(req);
    end
  endtask
endclass

`endif


// status_register_env.sv
`ifndef STATUS_REGISTER_ENV_SV
`define STATUS_REGISTER_ENV_SV

`include "uvm_macros.svh"

// Assuming you have an agent and other components defined elsewhere.
// Replace placeholders with your actual agent and monitor classes.

class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uvm_sequencer #(seq_item) sequencer;
  uvm_driver #(seq_item)  driver;
  uvm_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uvm_sequencer #(seq_item)::type_id::create("sequencer", this);
    driver    = uvm_driver #(seq_item)::type_id::create("driver", this); // Replace with actual driver
    monitor   = uvm_monitor::type_id::create("monitor", this); // Replace with actual monitor
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_port.connect(sequencer.seq_export);
  endfunction

endclass

class status_register_env extends uvm_env;
  `uvm_component_utils(status_register_env)

  uart_agent agent;
  scoreboard sb; // Replace with your scoreboard

  function new(string name = "status_register_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = uart_agent::type_id::create("agent", this);
    sb    = scoreboard::type_id::create("scoreboard", this); // Replace with actual scoreboard
  endfunction

  function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.monitor.analysis_port.connect(sb.analysis_imp);
  endfunction
endclass

`endif

//scoreboard.sv

`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

`include "uvm_macros.svh"
`include "seq_item.sv"

class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)

  uvm_analysis_imp #(seq_item, scoreboard) analysis_imp;

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_imp = new("analysis_imp", this);
  endfunction

  task run_phase(uvm_phase phase);
    seq_item received_item;
    bit status_bit_after_receive;
    bit status_bit_after_read;

    forever begin
      analysis_imp.get(received_item);

      // 1. Monitor RxD_PAD_I (handled by the monitor and seq_item)
      // 2. Monitor IntRx_O (handled by the monitor)

      // 3. Read Status Register and verify bit 1 is '1'.

      // Simulate reading the status register and get the status bit.  Replace with DUT interaction
      status_bit_after_receive = $urandom_range(0,1);  //Simulate DUT status bit.  Normally read from DUT
      if (status_bit_after_receive != 1) begin
        `uvm_error("SCOREBOARD", $sformatf("Status bit is incorrect after receiving data.  Expected 1, got %0d", status_bit_after_receive))
      end else begin
        `uvm_info("SCOREBOARD", "Status bit is correct (1) after receiving data.", UVM_MEDIUM)
      end

      // 4. Read Data Output Register.
      // Simulate reading the data register

      // 5. Read Status Register and verify bit 1 is '0'.
      status_bit_after_read = $urandom_range(0,1);  //Simulate DUT status bit.  Normally read from DUT

      if (status_bit_after_read != 0) begin
        `uvm_error("SCOREBOARD", $sformatf("Status bit is incorrect after reading data. Expected 0, got %0d", status_bit_after_read))
      end else begin
        `uvm_info("SCOREBOARD", "Status bit is correct (0) after reading data.", UVM_MEDIUM)
      end

    end
  endtask
endclass

`endif


// status_register_test.sv
`ifndef STATUS_REGISTER_TEST_SV
`define STATUS_REGISTER_TEST_SV

`include "uvm_macros.svh"
`include "status_register_env.sv"
`include "base_seq.sv"

class status_register_test extends uvm_test;
  `uvm_component_utils(status_register_test)

  // Declare environment handle
  status_register_env env;

  // Constructor
  function new(string name = "status_register_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = status_register_env::type_id::create("env", this);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    base_seq seq;
    phase.raise_objection(this);

    `uvm_info("STATUS_REGISTER_TEST", "Starting test...", UVM_LOW)

    seq = base_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif
```