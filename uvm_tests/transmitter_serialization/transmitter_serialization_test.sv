```systemverilog
// seq_item.sv
`ifndef SEQ_ITEM_SV
`define SEQ_ITEM_SV

`include "uvm_macros.svh"

class seq_item extends uvm_sequence_item;
  `uvm_object_utils(seq_item)

  // Define transaction variables
  rand bit [7:0] wb_dat_i;
  rand bit [3:0] brdivisor;

  function new(string name = "seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint brdivisor_c { brdivisor inside { [0:15] }; }

  function string convert2string();
    return $sformatf("wb_dat_i=%0h brdivisor=%0h", wb_dat_i, brdivisor);
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
      if (!req.randomize()) begin
        `uvm_error("BASE_SEQ", "Failed to randomize seq_item")
      end

      `uvm_info("BASE_SEQ", $sformatf("Generated transaction: %s", req.convert2string()), UVM_HIGH)
      finish_item(req);
    end
  endtask
endclass

`endif


// tx_agent.sv
`ifndef TX_AGENT_SV
`define TX_AGENT_SV

`include "uvm_macros.svh"

class tx_agent extends uvm_agent;
  `uvm_component_utils(tx_agent)

  tx_sequencer sequencer;
  tx_driver driver;
  tx_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = tx_sequencer::type_id::create("sequencer", this);
    driver = tx_driver::type_id::create("driver", this);
    monitor = tx_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_port.connect(sequencer.seq_export);
  endfunction
endclass

class tx_sequencer extends uvm_sequencer;
  `uvm_component_utils(tx_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class tx_driver extends uvm_driver #(seq_item);
  `uvm_component_utils(tx_driver)

  virtual interface uart_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "uart_vif", vif)) begin
      `uvm_fatal("TX_DRIVER", "Virtual interface must be set for uart_vif!!!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    seq_item req;
    forever begin
      seq_port.get_next_item(req);
      `uvm_info("TX_DRIVER", $sformatf("Driving transaction: %s", req.convert2string()), UVM_HIGH)
      vif.brdivisor <= req.brdivisor;
      vif.wb_dat_i <= req.wb_dat_i;
      seq_port.item_done();
    end
  endtask
endclass

class tx_monitor extends uvm_monitor;
  `uvm_component_utils(tx_monitor)

  virtual interface uart_if vif;
  uvm_analysis_port #(seq_item) item_collected_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "uart_vif", vif)) begin
      `uvm_fatal("TX_MONITOR", "Virtual interface must be set for uart_vif!!!")
    end
    item_collected_port = new("item_collected_port", this);
  endfunction

  task run_phase(uvm_phase phase);
    seq_item item;
    bit [7:0] received_data;
    bit        start_bit;
    bit        stop_bit;
    real       bit_time;

    forever begin
      // Sample TxD_PAD_O, determine start bit
      @(posedge vif.clk);
      if (vif.txd_pad_o == 0) begin  // Start bit detected
        item = seq_item::type_id::create("item", this);
        start_bit = vif.txd_pad_o;

        // Get BRDIVISOR from interface
        item.brdivisor = vif.brdivisor;

        // Calculate bit time
        bit_time = 1.0 / (vif.clk_freq / (item.brdivisor + 1));

        // Sample data bits
        received_data = 0;
        for (int i = 0; i < 8; i++) begin
          #(bit_time * vif.clk_period); // Wait for middle of bit
          received_data[i] = vif.txd_pad_o;
        end

        // Sample stop bit
        #(bit_time * vif.clk_period); // Wait for middle of bit
        stop_bit = vif.txd_pad_o;

        item.wb_dat_i = received_data;
        `uvm_info("TX_MONITOR", $sformatf("Monitored TxD: start=%0b data=%0h stop=%0b, brdivisor=%0h",
                                      start_bit, received_data, stop_bit, item.brdivisor), UVM_HIGH)

        item_collected_port.write(item);
      end
    end
  endtask
endclass

`endif


// env.sv
`ifndef ENV_SV
`define ENV_SV

`include "uvm_macros.svh"
`include "tx_agent.sv"
//`include "rx_agent.sv" //If you have a receiver
`include "scoreboard.sv"


class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  tx_agent agent; // Transmit agent.
  //rx_agent rx_agent; //Receive agent if it is needed
  scoreboard scb;

  function new(string name = "my_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = tx_agent::type_id::create("agent", this);
    //rx_agent = rx_agent::type_id::create("rx_agent", this); //If you have a receiver
    scb = scoreboard::type_id::create("scb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
   super.connect_phase(phase);
   agent.monitor.item_collected_port.connect(scb.analysis_export);
   //rx_agent.monitor.item_collected_port.connect(scb.analysis_export); //If you have a receiver
  endfunction

endclass

`endif

// scoreboard.sv
`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

`include "uvm_macros.svh"
`include "seq_item.sv"

class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)

  uvm_analysis_export #(seq_item) analysis_export;

  seq_item expected_data_q[$];

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  task run_phase(uvm_phase phase);
    seq_item item;
    forever begin
      analysis_export.get(item);
      compare_data(item);
    end
  endtask

  function void compare_data(seq_item item);
    seq_item expected_item;

    //Find expected item in queue based on brdivisor
    foreach(expected_data_q[i]) begin
      if(expected_data_q[i].brdivisor == item.brdivisor) begin
        expected_item = expected_data_q[i];
        expected_data_q.delete(i);
        break;
      end
    end

    if (expected_item == null) begin
      `uvm_error("SCOREBOARD", $sformatf("No expected data found for brdivisor %0h. Received: %s", item.brdivisor, item.convert2string()))
      return;
    end

    if (item.wb_dat_i != expected_item.wb_dat_i) begin
      `uvm_error("SCOREBOARD", $sformatf("Data mismatch! Expected: %0h, Received: %0h, brdivisor: %0h",
                                       expected_item.wb_dat_i, item.wb_dat_i, item.brdivisor))
    end else begin
      `uvm_info("SCOREBOARD", $sformatf("Data match! Expected: %0h, Received: %0h, brdivisor: %0h",
                                       expected_item.wb_dat_i, item.wb_dat_i, item.brdivisor), UVM_MEDIUM)
    end
  endfunction

  function void add_expected_data(seq_item item);
    expected_data_q.push_back(item);
  endfunction

endclass

`endif

// base_test.sv
`ifndef BASE_TEST_SV
`define BASE_TEST_SV

`include "uvm_macros.svh"
`include "env.sv"
`include "base_seq.sv"

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  // Declare environment handle
  my_env env;

  virtual interface uart_if vif;

  // Constructor
  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "uart_vif", vif)) begin
      `uvm_fatal("BASE_TEST", "Virtual interface must be set for uart_vif!!!")
    end

    env = my_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    base_seq seq;
    phase.raise_objection(this);

    `uvm_info("BASE_TEST", "Starting test...", UVM_LOW)

    seq = base_seq::type_id::create("seq");

    // Pre-configure sequence with expected data and add to scoreboard queue
    seq.pre_body();
    
    seq.start(env.agent.sequencer, this);
   
    phase.drop_objection(this);
  endtask
endclass

class extended_base_seq extends base_seq;
    `uvm_object_utils(extended_base_seq)

  function new(string name = "extended_base_seq");
    super.new(name);
  endfunction

    task pre_body();
        seq_item req;
        repeat (10) begin
            req = seq_item::type_id::create("req");
            if (!req.randomize()) begin
              `uvm_error("EXTENDED_BASE_SEQ", "Failed to randomize seq_item")
            end
            my_env env = my_env::type_id::get(null,"env");
            env.scb.add_expected_data(req);
        end
    endtask
endclass


class extended_test extends base_test;
  `uvm_component_utils(extended_test)

  // Constructor
  function new(string name = "extended_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    extended_base_seq seq;
    phase.raise_objection(this);

    `uvm_info("EXTENDED_TEST", "Starting test...", UVM_LOW)

    seq = extended_base_seq::type_id::create("seq");
    seq.start(env.agent.sequencer, this);

    phase.drop_objection(this);
  endtask
endclass

`endif

// uart_if.sv
`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if (input bit clk);
  logic        wb_dat_i;
  logic [3:0]  brdivisor;
  logic        txd_pad_o;

  timeunit 1ns;
  timeprecision 1ps;

  real clk_period;
  real clk_freq;

  clocking drv_cb @(posedge clk);
    default input #1 output #0;
    output wb_dat_i;
    output brdivisor;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1 output #0;
    input  txd_pad_o;
  endclocking

  modport DRV (clocking drv_cb, input clk);
  modport MON (clocking mon_cb, input clk, input wb_dat_i, input brdivisor);
endinterface

`endif
```