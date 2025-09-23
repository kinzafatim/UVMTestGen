```systemverilog
// wb_seq_item.sv
`ifndef WB_SEQ_ITEM_SV
`define WB_SEQ_ITEM_SV

`include "uvm_macros.svh"

class wb_seq_item extends uvm_sequence_item;
  `uvm_object_utils(wb_seq_item)

  // Define transaction variables
  rand bit [31:0] wb_dat_i;
  rand bit [31:0] wb_addr_i;
  rand bit        wb_we_i;
  rand bit        wb_stb_i;
  rand bit        wb_rst_i;

  bit [31:0] wb_dat_o;  // Expected output data
  bit        wb_ack_o;  // Expected ACK signal

  function new(string name = "wb_seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint c_valid_write {
    wb_we_i == 1;
    wb_stb_i == 1;
  }

  constraint c_valid_read {
    wb_we_i == 0;
    wb_stb_i == 1;
  }

  function string convert2string();
    return $sformatf("wb_dat_i=0x%h wb_addr_i=0x%h wb_we_i=%0b wb_stb_i=%0b wb_rst_i=%0b",
                      wb_dat_i, wb_addr_i, wb_we_i, wb_stb_i, wb_rst_i);
  endfunction
endclass

`endif


// wb_base_sequence.sv
`ifndef WB_BASE_SEQ_SV
`define WB_BASE_SEQ_SV

`include "uvm_macros.svh"
`include "wb_seq_item.sv"

class wb_base_sequence extends uvm_sequence #(wb_seq_item);
  `uvm_object_utils(wb_base_sequence)

  function new(string name = "wb_base_sequence");
    super.new(name);
  endfunction

  // Sequence body: generate stimulus
  task body();
    wb_seq_item req;
    bit [31:0]  thr_data;  // Data to be written to THR
    bit [31:0]  rbr_data;  // Data to be read from RBR
    int i;

    `uvm_info("WB_BASE_SEQ", "Starting Wishbone base sequence", UVM_LOW)

    // Reset sequence
    req = wb_seq_item::type_id::create("req");
    start_item(req);
    req.wb_rst_i = 1;
    req.wb_stb_i = 0;
    req.wb_we_i = 0;
    req.wb_addr_i = 0;
    req.wb_dat_i = 0;
    finish_item(req);

    // Wait for reset to complete
    #10;  // Adjust delay as needed

    req = wb_seq_item::type_id::create("req");
    start_item(req);
    req.wb_rst_i = 0;
    req.wb_stb_i = 0;
    req.wb_we_i = 0;
    req.wb_addr_i = 0;
    req.wb_dat_i = 0;
    finish_item(req);
    
    // Write to THR and then read from RBR, 5 times
    repeat (5) begin
      // Write data to THR
      thr_data = $urandom();
      req = wb_seq_item::type_id::create("req");
      start_item(req);
      req.randomize();  // randomize non-address/reset signals.
      req.wb_addr_i = 'h00; // THR address
      req.wb_dat_i  = thr_data;
      req.wb_rst_i  = 0;
      req.wb_we_i   = 1;
      req.wb_stb_i  = 1;
      finish_item(req);

      // Read data from RBR
      rbr_data = thr_data; //assume data is immediately available
      req = wb_seq_item::type_id::create("req");
      start_item(req);
      req.randomize();
      req.wb_addr_i = 'h04; // RBR address
      req.wb_dat_i  = '0;    // Don't care
      req.wb_rst_i  = 0;
      req.wb_we_i   = 0;
      req.wb_stb_i  = 1;
      req.wb_dat_o  = rbr_data; // set the expected value
      req.wb_ack_o  = 1;    // Expect an ACK
      finish_item(req);

      `uvm_info("WB_BASE_SEQ", $sformatf("THR Write: data=0x%h, RBR expected: 0x%h", thr_data, rbr_data), UVM_MEDIUM)
    end
  endtask
endclass

`endif


// wb_env.sv
`ifndef WB_ENV_SV
`define WB_ENV_SV

`include "uvm_macros.svh"
`include "wb_agent.sv"
`include "wb_scoreboard.sv"

class wb_env extends uvm_env;
  `uvm_component_utils(wb_env)

  wb_agent agent;
  wb_scoreboard scoreboard;

  function new(string name = "wb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = wb_agent::type_id::create("agent", this);
    scoreboard = wb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.analysis_port.connect(scoreboard.analysis_export);
  endfunction
endclass

`endif


// wb_agent.sv
`ifndef WB_AGENT_SV
`define WB_AGENT_SV

`include "uvm_macros.svh"
`include "wb_sequencer.sv"
`include "wb_driver.sv"
`include "wb_monitor.sv"

class wb_agent extends uvm_agent;
  `uvm_component_utils(wb_agent)

  wb_sequencer sequencer;
  wb_driver driver;
  wb_monitor monitor;

  function new(string name = "wb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = wb_sequencer::type_id::create("sequencer", this);
    driver = wb_driver::type_id::create("driver", this);
    monitor = wb_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_port.connect(sequencer.seq_port);
  endfunction
endclass

`endif


// wb_driver.sv
`ifndef WB_DRIVER_SV
`define WB_DRIVER_SV

`include "uvm_macros.svh"
`include "wb_seq_item.sv"

class wb_driver extends uvm_driver #(wb_seq_item);
  `uvm_component_utils(wb_driver)

  virtual interface wb_if vif;

  function new(string name = "wb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface wb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("WB_DRIVER", "virtual interface must be set for: vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    wb_seq_item req;
    forever begin
      seq_port.get_next_item(req);
      drive_transaction(req);
      seq_port.item_done();
    end
  endtask

  task drive_transaction(wb_seq_item req);
    `uvm_info("WB_DRIVER", $sformatf("Driving transaction: %s", req.convert2string()), UVM_MEDIUM)

    vif.wb_rst_i  <= req.wb_rst_i;
    vif.wb_addr_i <= req.wb_addr_i;
    vif.wb_dat_i  <= req.wb_dat_i;
    vif.wb_we_i   <= req.wb_we_i;
    vif.wb_stb_i  <= req.wb_stb_i;

    @(posedge vif.clk); // Clock synchronization.
  endtask
endclass

`endif


// wb_monitor.sv
`ifndef WB_MONITOR_SV
`define WB_MONITOR_SV

`include "uvm_macros.svh"
`include "wb_seq_item.sv"

class wb_monitor extends uvm_monitor;
  `uvm_component_utils(wb_monitor)

  virtual interface wb_if vif;
  uvm_analysis_port #(wb_seq_item) analysis_port;

  function new(string name = "wb_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface wb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("WB_MONITOR", "virtual interface must be set for: vif")
    end
    analysis_port = new("analysis_port", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      collect_transaction();
    end
  endtask

  task collect_transaction();
    wb_seq_item trans = wb_seq_item::type_id::create("trans");
    trans.wb_addr_i = vif.wb_addr_i;
    trans.wb_dat_i  = vif.wb_dat_i;
    trans.wb_dat_o  = vif.wb_dat_o; // Capture the output
    trans.wb_we_i   = vif.wb_we_i;
    trans.wb_stb_i  = vif.wb_stb_i;
    trans.wb_rst_i  = vif.wb_rst_i;
    trans.wb_ack_o  = vif.wb_ack_o;

    `uvm_info("WB_MONITOR", $sformatf("Observed transaction: %s", trans.convert2string()), UVM_MEDIUM)
    analysis_port.write(trans);
  endtask
endclass

`endif


// wb_sequencer.sv
`ifndef WB_SEQUENCER_SV
`define WB_SEQUENCER_SV

`include "uvm_macros.svh"

class wb_sequencer extends uvm_sequencer;
  `uvm_component_utils(wb_sequencer)

  function new(string name = "wb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

`endif


// wb_scoreboard.sv
`ifndef WB_SCOREBOARD_SV
`define WB_SCOREBOARD_SV

`include "uvm_macros.svh"
`include "wb_seq_item.sv"

class wb_scoreboard extends uvm_component;
  `uvm_component_utils(wb_scoreboard)

  uvm_analysis_export #(wb_seq_item) analysis_export;

  function new(string name = "wb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  task run_phase(uvm_phase phase);
    wb_seq_item observed_transaction;

    forever begin
      analysis_export.get(observed_transaction);
      compare_transaction(observed_transaction);
    end
  endtask

  function void compare_transaction(wb_seq_item observed_transaction);
    // Scoreboard logic to compare observed results with expected values
    if (observed_transaction.wb_stb_i) begin
        if(observed_transaction.wb_we_i) begin
            //Write to THR so check ACK
            if(observed_transaction.wb_ack_o != 1) begin
                `uvm_error("WB_SCOREBOARD", $sformatf("Write transaction failed: ACK not asserted. Observed: %s", observed_transaction.convert2string()));
            end else begin
                `uvm_info("WB_SCOREBOARD", $sformatf("Write transaction PASSED! Observed: %s", observed_transaction.convert2string()), UVM_MEDIUM);
            end
        end else begin
            //Read from RBR
            if(observed_transaction.wb_ack_o != 1) begin
                `uvm_error("WB_SCOREBOARD", $sformatf("Read transaction failed: ACK not asserted. Observed: %s", observed_transaction.convert2string()));
            end else if (observed_transaction.wb_dat_o != observed_transaction.wb_dat_i) begin
                `uvm_error("WB_SCOREBOARD", $sformatf("Data mismatch: Expected 0x%h, Received 0x%h. Observed: %s",
                    observed_transaction.wb_dat_o, observed_transaction.wb_dat_i, observed_transaction.convert2string()));
            end else begin
                `uvm_info("WB_SCOREBOARD", $sformatf("Read transaction PASSED! Observed: %s", observed_transaction.convert2string()), UVM_MEDIUM);
            end
        end
    end

  endfunction
endclass

`endif


// wb_test.sv
`ifndef WB_TEST_SV
`define WB_TEST_SV

`include "uvm_macros.svh"
`include "wb_env.sv"
`include "wb_base_sequence.sv"

class wb_test extends uvm_test;
  `uvm_component_utils(wb_test)

  // Declare environment handle
  wb_env env;

  // Constructor
  function new(string name = "wb_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = wb_env::type_id::create("env", this);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    wb_base_sequence seq;
    phase.raise_objection(this);

    `uvm_info("WB_TEST", "Starting Wishbone test...", UVM_LOW)

    seq = wb_base_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif


// wb_if.sv
`ifndef WB_IF_SV
`define WB_IF_SV

interface wb_if (input bit clk);
  logic        wb_rst_i;
  logic [31:0] wb_addr_i;
  logic [31:0] wb_dat_i;
  logic        wb_we_i;
  logic        wb_stb_i;
  logic [31:0] wb_dat_o;
  logic        wb_ack_o;
  
  clocking drv_cb @(posedge clk);
      output wb_rst_i;
      output wb_addr_i;
      output wb_dat_i;
      output wb_we_i;
      output wb_stb_i;
  endclocking

  clocking mon_cb @(posedge clk);
      input wb_rst_i;
      input wb_addr_i;
      input wb_dat_i;
      input wb_we_i;
      input wb_stb_i;
      input wb_dat_o;
      input wb_ack_o;
  endclocking
endinterface

`endif
```