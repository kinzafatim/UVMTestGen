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
  rand bit [31:0] addr;
  rand bit wb_we;

  function new(string name = "seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint c_valid { valid inside {0, 1}; }
  constraint c_wb_we { wb_we inside {0, 1}; }

  function string convert2string();
    return $sformatf("data=%0h addr=%0h wb_we=%0b valid=%0b", data, addr, wb_we, valid);
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
    // Configure Baud Rate Divisor
    req = seq_item::type_id::create("req");
    start_item(req);
    req.addr = 'h00; // Address for Baud Rate Divisor
    req.data = 'h3ff; // Example divisor value
    req.wb_we = 1;
    req.valid = 1;
    finish_item(req);

    repeat (5) begin
      req = seq_item::type_id::create("req");
      start_item(req);

      // Customize stimulus generation here
      req.randomize();
      req.addr = 'h04; // Address for data register
      req.wb_we = 1; // Write Enable for data
      
      finish_item(req);
    end
  endtask
endclass

`endif

// monitor.sv
`ifndef MONITOR_SV
`define MONITOR_SV

`include "uvm_macros.svh"

class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)

  uvm_analysis_port #(seq_item) analysis_port;

  virtual interface uart_if vif;

  function new(string name = "monitor", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "uart_vif", vif)) begin
      `uvm_fatal("MONITOR", "Virtual interface must be set for monitor uart_vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    seq_item trans;
    forever begin
      @(posedge vif.WB_CLK_I);

      if(vif.WB_RST_I == 1) continue;

      if (vif.WB_WE_I && vif.WB_ADDR_I == 'h04) begin // Data register address
        trans = new();
        trans.data = vif.WB_DAT_I[7:0];
        trans.addr = vif.WB_ADDR_I;
        trans.wb_we = vif.WB_WE_I;
        trans.valid = 1;

        `uvm_info("MONITOR", $sformatf("Detected Write: %s", trans.convert2string()), UVM_MEDIUM)
        analysis_port.write(trans);
      end
    end
  endtask
endclass

`endif

// agent.sv
`ifndef AGENT_SV
`define AGENT_SV

`include "uvm_macros.svh"
`include "sequencer.sv"
`include "monitor.sv"

class agent extends uvm_agent;
  `uvm_component_utils(agent)

  sequencer seqr;
  monitor mon;

  virtual interface uart_if vif;

  function new(string name = "agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seqr = sequencer::type_id::create("sequencer", this);
    mon = monitor::type_id::create("monitor", this);

    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "uart_vif", vif)) begin
      `uvm_fatal("AGENT", "Virtual interface must be set for agent uart_vif")
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction
endclass

`endif

// sequencer.sv
`ifndef SEQUENCER_SV
`define SEQUENCER_SV

`include "uvm_macros.svh"
`include "seq_item.sv"

class sequencer extends uvm_sequencer #(seq_item);
  `uvm_component_utils(sequencer)

  function new(string name = "sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

`endif

// environment.sv
`ifndef ENVIRONMENT_SV
`define ENVIRONMENT_SV

`include "uvm_macros.svh"
`include "agent.sv"
`include "scoreboard.sv"

class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  agent agent;
  scoreboard scoreboard;

  function new(string name = "env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = agent::type_id::create("agent", this);
    scoreboard = scoreboard::type_id::create("scoreboard", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.analysis_port.connect(scoreboard.analysis_export);
  endfunction
endclass

`endif

// scoreboard.sv
`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

`include "uvm_macros.svh"
`include "seq_item.sv"

class scoreboard extends uvm_component;
  `uvm_component_utils(scoreboard)

  uvm_analysis_export #(seq_item) analysis_export;
  
  // Store expected data
  seq_item expected_data[$];
  
  // Store received data
  seq_item received_data[$];

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    seq_item trans;
    
    // Pre-populate expected data (this could come from a file or calculation)
    // This is a very simple example. In a real design, this would be much more complex.
    for (int i = 0; i < 5; i++) begin
      trans = new();
      trans.data = i + 1;  // Example expected data
      expected_data.push_back(trans);
    end

    forever begin
      analysis_export.get(trans);
      received_data.push_back(trans);
      `uvm_info("SCOREBOARD", $sformatf("Received Transaction: %s", trans.convert2string()), UVM_MEDIUM)
      compare_data();
    end
  endtask

  task compare_data();
    seq_item exp, rec;
    if(received_data.size() == 0 || expected_data.size() == 0) return;
      
    exp = expected_data[0];
    rec = received_data[0];

    if (exp.data != rec.data) begin
      `uvm_error("SCOREBOARD", $sformatf("Data mismatch! Expected: %0h, Received: %0h", exp.data, rec.data))
    end else begin
      `uvm_info("SCOREBOARD", $sformatf("Data match! Expected: %0h, Received: %0h", exp.data, rec.data), UVM_MEDIUM)
    end
    expected_data.delete(0);
    received_data.delete(0);
  endtask
endclass

`endif

// uart_if.sv
`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if;
  logic WB_CLK_I;
  logic WB_RST_I;
  logic [31:0] WB_ADDR_I;
  logic [31:0] WB_DAT_I;
  logic WB_WE_I;
  logic TxD_PAD_O;

  clocking cb @(posedge WB_CLK_I);
    default input #1 output #1;
    input WB_CLK_I, WB_RST_I, WB_ADDR_I, WB_DAT_I, WB_WE_I, TxD_PAD_O;
  endclocking

endinterface

`endif

// base_test.sv
`ifndef BASE_TEST_SV
`define BASE_TEST_SV

`include "uvm_macros.svh"
`include "environment.sv"
`include "base_seq.sv"
`include "uart_if.sv"

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  // Declare environment handle
  my_env env;

  virtual interface uart_if vif;

  // Constructor
  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "uart_vif", vif)) begin
      `uvm_fatal("TEST", "Virtual interface must be set for test uart_vif")
    end

    env = my_env::type_id::create("env", this);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    base_seq seq;
    phase.raise_objection(this);

    `uvm_info("BASE_TEST", "Starting test...", UVM_LOW)

    seq = base_seq::type_id::create("seq");
    seq.start(env.agent.seqr);

    phase.drop_objection(this);
  endtask
endclass

`endif
```