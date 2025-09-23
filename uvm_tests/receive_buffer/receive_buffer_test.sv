```systemverilog
// uart_rx_test.sv
`ifndef UART_RX_TEST_SV
`define UART_RX_TEST_SV

`include "uvm_macros.svh"
`include "uart_env.sv"
`include "uart_rx_seq.sv"

class uart_rx_test extends uvm_test;
  `uvm_component_utils(uart_rx_test)

  uart_env env;

  function new(string name = "uart_rx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    uart_rx_seq seq;
    phase.raise_objection(this);

    `uvm_info("UART_RX_TEST", "Starting UART RX test...", UVM_LOW)

    seq = uart_rx_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif

// uart_rx_seq.sv
`ifndef UART_RX_SEQ_SV
`define UART_RX_SEQ_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_rx_seq extends uvm_sequence #(uart_seq_item);
  `uvm_object_utils(uart_rx_seq)

  function new(string name = "uart_rx_seq");
    super.new(name);
  endfunction

  task body();
    uart_seq_item req;

    `uvm_info("UART_RX_SEQ", "Starting UART RX sequence", UVM_LOW)

    // Configure BRDIVISOR (example value)
    req = uart_seq_item::type_id::create("req");
    req.addr = 1;  // Assuming address 1 is BRDIVISOR
    req.data = 10; // Example BRDIVISOR value
    req.write = 1;
    start_item(req);
    finish_item(req);

    // Send a byte
    req = uart_seq_item::type_id::create("req");
    req.addr = 0; //RX Data, will be ignored here as this is setup
    req.data = 8'h55; // Example byte to transmit
    req.write = 0; // read
    start_item(req);
    finish_item(req);

    // Attempt to write to RX buffer (address 0)
    req = uart_seq_item::type_id::create("req");
    req.addr = 0;
    req.data = 8'hAA; // Example data to write (should be ignored)
    req.write = 1;
    start_item(req);
    finish_item(req);
  endtask
endclass

`endif

// uart_seq_item.sv
`ifndef UART_SEQ_ITEM_SV
`define UART_SEQ_ITEM_SV

`include "uvm_macros.svh"

class uart_seq_item extends uvm_sequence_item;
  `uvm_object_utils(uart_seq_item)
  `uvm_field_int(addr, UVM_ALL_ON)
  `uvm_field_int(data, UVM_ALL_ON)
  `uvm_field_int(write, UVM_ALL_ON)

  rand bit [7:0] data;
  rand bit [7:0] addr;
  rand bit write;

  function new(string name = "uart_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("addr=%0d data=%0d write=%0b", addr, data, write);
  endfunction
endclass

`endif

// uart_env.sv
`ifndef UART_ENV_SV
`define UART_ENV_SV

`include "uvm_macros.svh"
`include "uart_agent.sv"
`include "uart_scoreboard.sv"

class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_agent agent;
  uart_scoreboard scoreboard;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = uart_agent::type_id::create("agent", this);
    scoreboard = uart_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.analysis_port.connect(scoreboard.analysis_export);
  endfunction
endclass

`endif

// uart_agent.sv
`ifndef UART_AGENT_SV
`define UART_AGENT_SV

`include "uvm_macros.svh"
`include "uart_sequencer.sv"
`include "uart_driver.sv"
`include "uart_monitor.sv"

class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uart_sequencer sequencer;
  uart_driver driver;
  uart_monitor mon;

  function new(string name = "uart_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uart_sequencer::type_id::create("sequencer", this);
    driver = uart_driver::type_id::create("driver", this);
    mon = uart_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_port.connect(sequencer.seq_port);
  endfunction
endclass

`endif

// uart_sequencer.sv
`ifndef UART_SEQUENCER_SV
`define UART_SEQUENCER_SV

`include "uvm_macros.svh"

class uart_sequencer extends uvm_sequencer;
  `uvm_component_utils(uart_sequencer)

  function new(string name = "uart_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

`endif

// uart_driver.sv
`ifndef UART_DRIVER_SV
`define UART_DRIVER_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_driver extends uvm_driver #(uart_seq_item);
  `uvm_component_utils(uart_driver)

  virtual interface uart_if vif;

  function new(string name = "uart_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("UART_DRIVER", "virtual interface must be set for vif!!!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_seq_item req;
    forever begin
      seq_port.get_next_item(req);
      `uvm_info("UART_DRIVER", $sformatf("Driving item:\n%s", req.convert2string()), UVM_MEDIUM)
      drive_transaction(req);
      seq_port.item_done();
    end
  endtask

  task drive_transaction(uart_seq_item req);
    // Drive signals based on req
    vif.WB_ADR_I <= req.addr;
    vif.WB_DAT_I <= req.data;
    vif.WB_WE_I  <= req.write;
    @(posedge vif.clk);
  endtask
endclass

`endif

// uart_monitor.sv
`ifndef UART_MONITOR_SV
`define UART_MONITOR_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_monitor extends uvm_monitor;
  `uvm_component_utils(uart_monitor)

  virtual interface uart_if vif;
  uvm_analysis_port #(uart_seq_item) analysis_port;

  function new(string name = "uart_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("UART_MONITOR", "virtual interface must be set for vif!!!")
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
    uart_seq_item observed_item = uart_seq_item::type_id::create("observed_item");
    observed_item.addr = vif.WB_ADR_I;
    observed_item.data = vif.WB_DAT_O;
    observed_item.write = vif.WB_WE_I;  // Assuming WB_WE_I indicates write enable
    `uvm_info("UART_MONITOR", $sformatf("Observed item:\n%s", observed_item.convert2string()), UVM_MEDIUM)
    analysis_port.write(observed_item);
  endtask
endclass

`endif

// uart_scoreboard.sv
`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  uvm_analysis_export #(uart_seq_item) analysis_export;

  uart_seq_item expected_item;
  uart_seq_item read_item;

  bit [7:0] rx_buffer; // Internal representation of RX buffer

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  task run_phase(uvm_phase phase);
    uart_seq_item item;
    forever begin
      analysis_export.get(item);
      `uvm_info("UART_SCOREBOARD", $sformatf("Received item:\n%s", item.convert2string()), UVM_MEDIUM)

      if (item.addr == 0 && item.write == 0) begin // Read from RX Buffer
        `uvm_info("UART_SCOREBOARD", "Read from RX Buffer detected", UVM_MEDIUM)
        read_item = item;
        compare_data();
      end else if (item.addr == 0 && item.write == 1) begin
         // Verify that writing to address 0 does not change the contents of the RX buffer
        `uvm_info("UART_SCOREBOARD", "Write Attempt to RX Buffer detected", UVM_MEDIUM)
        check_rx_buffer_unchanged();
      end else if (item.addr == 1) begin
          //BRDIVISOR Configuration, ignore this
      end
      else begin
        `uvm_error("UART_SCOREBOARD", "Unexpected transaction received.");
      end
    end
  endtask

  function void compare_data();
    if(read_item.data != rx_buffer) begin
      `uvm_error("UART_SCOREBOARD", $sformatf("Data mismatch: Expected 0x%h, Received 0x%h", rx_buffer, read_item.data));
    end else begin
      `uvm_info("UART_SCOREBOARD", "Data matched", UVM_MEDIUM);
    end
  endfunction

  function void check_rx_buffer_unchanged();

      // Read back RX buffer after attempt to write
      uart_seq_item read_req = new("read_req");
      read_req.addr = 0;
      read_req.write = 0;

      // Send read request to Driver
      uvm_test_top.env.agent.sequencer.seq_port.put(read_req);

      //Wait for response
      @(uvm_test_top.env.agent.mon.analysis_port.get(read_req));
      `uvm_info("UART_SCOREBOARD", $sformatf("Read After Write Attempt 0x%h, RX Buffer 0x%h", read_req.data, rx_buffer), UVM_MEDIUM);
      if (read_req.data != rx_buffer)
        `uvm_error("UART_SCOREBOARD", $sformatf("Write to RX buffer changed value , Expected 0x%h, Received 0x%h", rx_buffer, read_req.data));
      else
        `uvm_info("UART_SCOREBOARD", "RX Buffer value did not change after write", UVM_MEDIUM);

  endfunction

endclass

`endif

// uart_if.sv
`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if (input bit clk);
  logic WB_RST_I;
  logic WB_ADR_I;
  logic WB_DAT_I;
  logic WB_DAT_O;
  logic WB_WE_I;
  logic RxD_PAD_I;
  logic IntRx_O;

  clocking drv_cb @(posedge clk);
    default input #1ns output #1ns;
    output WB_RST_I;
    output WB_ADR_I;
    output WB_DAT_I;
    output WB_WE_I;
    output RxD_PAD_I;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1ns output #1ns;
    input WB_RST_I;
    input WB_ADR_I;
    input WB_DAT_I;
    input WB_DAT_O;
    input WB_WE_I;
    input RxD_PAD_I;
    input IntRx_O;
  endclocking
endinterface

`endif
```