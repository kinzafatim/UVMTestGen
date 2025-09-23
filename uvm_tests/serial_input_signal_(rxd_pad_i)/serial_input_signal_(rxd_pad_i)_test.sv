```systemverilog
// seq_item.sv
`ifndef RX_SEQ_ITEM_SV
`define RX_SEQ_ITEM_SV

`include "uvm_macros.svh"

class rx_seq_item extends uvm_sequence_item;
  `uvm_object_utils(rx_seq_item)

  // Define transaction variables
  rand bit [7:0] data;
  rand real baud_rate; // Added baud rate
  rand bit parity_enable; // Added parity enable
  rand bit parity_type;   // 0: even, 1: odd

  function new(string name = "rx_seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint c_data { data inside { [0:255] }; }
  constraint c_baud_rate { baud_rate inside { 100, 1000, 10000 }; } // Example baud rates

  function string convert2string();
    return $sformatf("data=%0d baud_rate=%0.0f parity_enable=%0b parity_type=%0b", data, baud_rate, parity_enable, parity_type);
  endfunction
endclass

`endif

// rx_sequence.sv
`ifndef RX_SEQUENCE_SV
`define RX_SEQUENCE_SV

`include "uvm_macros.svh"
`include "rx_seq_item.sv"

class rx_sequence extends uvm_sequence #(rx_seq_item);
  `uvm_object_utils(rx_sequence)

  function new(string name = "rx_sequence");
    super.new(name);
  endfunction

  task body();
    rx_seq_item req;

    `uvm_info("RX_SEQUENCE", "Starting rx sequence", UVM_LOW)

    repeat (10) begin
      req = rx_seq_item::type_id::create("req");
      assert(req.randomize());
      `uvm_info("RX_SEQUENCE", $sformatf("Sending transaction: %s", req.convert2string()), UVM_MEDIUM)
      send_one(req);
    end
  endtask

  virtual task send_one(rx_seq_item req);
    start_item(req);
    finish_item(req);
  endtask

endclass

`endif

// rx_agent.sv
`ifndef RX_AGENT_SV
`define RX_AGENT_SV

`include "uvm_macros.svh"
//`include "rx_sequencer.sv"
//`include "rx_driver.sv"
//`include "rx_monitor.sv"

class rx_agent extends uvm_agent;
  `uvm_component_utils(rx_agent)

  rx_sequencer sequencer;
  rx_driver driver;
  rx_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    sequencer = rx_sequencer::type_id::create("sequencer", this);
    driver    = rx_driver::type_id::create("driver", this);
    monitor   = rx_monitor::type_id::create("monitor", this);

  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    driver.seq_port.connect(sequencer.seq_export);
  endfunction

endclass

`endif

// rx_sequencer.sv
`ifndef RX_SEQUENCER_SV
`define RX_SEQUENCER_SV

`include "uvm_macros.svh"
`include "rx_seq_item.sv"

class rx_sequencer extends uvm_sequencer #(rx_seq_item);
  `uvm_component_utils(rx_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

`endif

// rx_driver.sv
`ifndef RX_DRIVER_SV
`define RX_DRIVER_SV

`include "uvm_macros.svh"
`include "rx_seq_item.sv"

class rx_driver extends uvm_driver #(rx_seq_item);
  `uvm_component_utils(rx_driver)

  virtual interface rxd_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface rxd_if)::get(this, "", "vif", vif)) begin
       `uvm_fatal("RX_DRIVER", "virtual interface must be set for: vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    rx_seq_item req;
    forever begin
      seq_port.get_next_item(req);
      drive_transaction(req);
      seq_port.item_done();
    end
  endtask

  virtual task drive_transaction(rx_seq_item req);
     // Dummy implementation for now.  Replace with actual driver logic.
     `uvm_info("RX_DRIVER", $sformatf("Driving transaction: %s", req.convert2string()), UVM_MEDIUM)
     vif.data <= req.data;
     vif.baud_rate <= req.baud_rate;
     vif.parity_enable <= req.parity_enable;
     vif.parity_type <= req.parity_type;
     @(posedge vif.clk);  // Synchronize with clock
  endtask

endclass

`endif

// rx_monitor.sv
`ifndef RX_MONITOR_SV
`define RX_MONITOR_SV

`include "uvm_macros.svh"
//`include "rx_seq_item.sv"

class rx_monitor extends uvm_monitor;
  `uvm_component_utils(rx_monitor)

  virtual interface rxd_if vif;
  uvm_analysis_port #(rx_seq_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface rxd_if)::get(this, "", "vif", vif)) begin
       `uvm_fatal("RX_MONITOR", "virtual interface must be set for: vif")
    end
    analysis_port = new("analysis_port", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk); // Sample on rising edge of clock
      collect_data();
    end
  endtask

  virtual task collect_data();
    rx_seq_item observed_item;
    observed_item = rx_seq_item::type_id::create("observed_item");

    //Sample data from interface
    observed_item.data = vif.rxd_pad_i; // Assume rxd_pad_i contains the received data
    observed_item.baud_rate = vif.baud_rate;
    observed_item.parity_enable = vif.parity_enable;
    observed_item.parity_type = vif.parity_type;


    `uvm_info("RX_MONITOR", $sformatf("Observed transaction: %s", observed_item.convert2string()), UVM_MEDIUM)

    analysis_port.write(observed_item);
  endtask

endclass

`endif

// rx_env.sv
`ifndef RX_ENV_SV
`define RX_ENV_SV

`include "uvm_macros.svh"
`include "rx_agent.sv"
`include "rx_scoreboard.sv"

class rx_env extends uvm_env;
  `uvm_component_utils(rx_env)

  rx_agent agent;
  rx_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = rx_agent::type_id::create("agent", this);
    scoreboard = rx_scoreboard::type_id::create("scoreboard", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.analysis_port.connect(scoreboard.analysis_export); // Connect monitor to scoreboard
  endfunction

endclass

`endif

// rx_scoreboard.sv
`ifndef RX_SCOREBOARD_SV
`define RX_SCOREBOARD_SV

`include "uvm_macros.svh"
`include "rx_seq_item.sv"

class rx_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(rx_scoreboard)

  uvm_analysis_export #(rx_seq_item) analysis_export;
  rx_seq_item expected_item;
  bit [7:0] observed_wb_data;
  bit observed_intrx_o;
  virtual interface rxd_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    if (!uvm_config_db #(virtual interface rxd_if)::get(this, "", "vif", vif)) begin
       `uvm_fatal("RX_SCOREBOARD", "virtual interface must be set for: vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      observed_wb_data = vif.wb_dat_o;
      observed_intrx_o = vif.intrx_o;
      if(analysis_export.try_get(expected_item)) begin
        compare_results(expected_item, observed_wb_data, observed_intrx_o);
      end
    end
  endtask


  virtual function void compare_results(rx_seq_item expected, bit [7:0] observed_data, bit observed_intr);
    //  This is a simplified comparison that assumes WB_DAT_O is ready in same clock cycle as the data is received
    //  In a more complex design, you would need to use a queue or a mailbox to handle latency.

    if (expected.data == observed_data) begin
      `uvm_info("RX_SCOREBOARD", "Data Match: Expected = "
                , UVM_MEDIUM)
    end else begin
      `uvm_error("RX_SCOREBOARD", "Data Mismatch: Expected = "
                , UVM_MEDIUM)
    end
    // Add assertions for IntRx_O here, need to define protocol for IntRx_O
  endfunction

endclass

`endif

// rx_test.sv
`ifndef RX_TEST_SV
`define RX_TEST_SV

`include "uvm_macros.svh"
`include "rx_env.sv"
`include "rx_sequence.sv"

class rx_test extends uvm_test;
  `uvm_component_utils(rx_test)

  rx_env env;

  function new(string name = "rx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = rx_env::type_id::create("env", this);
    uvm_resource_db #(real)::set("uvm_root.env.agent.driver", "min_trans_time", 10.0);
  endfunction

  task run_phase(uvm_phase phase);
    rx_sequence seq;
    phase.raise_objection(this);

    `uvm_info("RX_TEST", "Starting test...", UVM_LOW)

    seq = rx_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif

// rxd_if.sv
`ifndef RXD_IF_SV
`define RXD_IF_SV

interface rxd_if;
  logic clk;
  logic rxd_pad_i;
  logic [7:0] wb_dat_o;
  logic intrx_o;
  real baud_rate;
  logic parity_enable;
  logic parity_type;

  clocking drv_cb @(posedge clk);
    default input #1ns output #0ns;
    output rxd_pad_i;
    input wb_dat_o;
    input intrx_o;
    output baud_rate;
    output parity_enable;
    output parity_type;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1ns output #0ns;
    input rxd_pad_i;
    input wb_dat_o;
    input intrx_o;
    input baud_rate;
    input parity_enable;
    input parity_type;

  endclocking

endinterface

`endif
```