```systemverilog
// File: uart_tx_buffer_test.sv
`ifndef UART_TX_BUFFER_TEST_SV
`define UART_TX_BUFFER_TEST_SV

`include "uvm_macros.svh"
`include "uart_env.sv"
`include "uart_tx_buffer_seq.sv"

class uart_tx_buffer_test extends uvm_test;
  `uvm_component_utils(uart_tx_buffer_test)

  // Declare environment handle
  uart_env env;

  // Constructor
  function new(string name = "uart_tx_buffer_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    uart_tx_buffer_seq seq;
    phase.raise_objection(this);

    `uvm_info("UART_TX_BUFFER_TEST", "Starting test...", UVM_LOW)

    seq = uart_tx_buffer_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif

// File: uart_tx_buffer_seq.sv
`ifndef UART_TX_BUFFER_SEQ_SV
`define UART_TX_BUFFER_SEQ_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_tx_buffer_seq extends uvm_sequence #(uart_seq_item);
  `uvm_object_utils(uart_tx_buffer_seq)

  rand int baud_rate;

  constraint baud_rate_c {
    baud_rate inside {115200, 57600, 9600};
  }

  function new(string name = "uart_tx_buffer_seq");
    super.new(name);
  endfunction

  // Sequence body: generate stimulus
  task body();
    uart_seq_item req;

    `uvm_info("UART_TX_BUFFER_SEQ", "Starting UART TX Buffer test sequence", UVM_LOW)

    repeat (5) begin
      void'(randomize(baud_rate));
      `uvm_info("UART_TX_BUFFER_SEQ", $sformatf("Running iteration with baud rate: %0d", baud_rate), UVM_MEDIUM)

      // Configure UART baud rate (example: writing to a config register)
      req = uart_seq_item::type_id::create("req");
      req.addr = 8'h00; // Example address for baud rate config
      req.data = baud_rate;
      req.write_enable = 1;
      start_item(req);
      finish_item(req);

      // Send data
      req = uart_seq_item::type_id::create("req");
      req.addr = 8'h01; // Example address for TX data
      req.write_enable = 1;
      repeat (3) begin // Send multiple bytes
        void'(req.randomize());
        start_item(req);
        finish_item(req);
      end

      // Read Status Register (Bit 0)
      req = uart_seq_item::type_id::create("req");
      req.addr = 8'h02; // Example address for status register
      req.write_enable = 0;  // Read
      start_item(req);
      finish_item(req);

      // *IMPORTANT* The driver and monitor should capture the IntTx_O signal.
      // This sequence uses the status register data that will be stored to the item to be used later in the scoreboard.
    end
  endtask
endclass

`endif

// File: uart_seq_item.sv
`ifndef UART_SEQ_ITEM_SV
`define UART_SEQ_ITEM_SV

`include "uvm_macros.svh"

class uart_seq_item extends uvm_sequence_item;
  `uvm_object_utils(uart_seq_item)

  // Define transaction variables
  rand bit [7:0] data;
  rand bit [7:0] addr; // Address for write/read
  rand bit write_enable;

  // Status register value (captured by monitor)
  bit [7:0] status_reg_value;

  function new(string name = "uart_seq_item");
    super.new(name);
  endfunction

  constraint addr_c { addr inside {8'h00, 8'h01, 8'h02}; }

  function string convert2string();
    return $sformatf("addr=%0h data=%0h write_enable=%0b status=%0h", addr, data, write_enable, status_reg_value);
  endfunction
endclass

`endif

// File: uart_env.sv
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
    agent.ap.connect(scoreboard.analysis_port);
  endfunction
endclass

`endif

// File: uart_agent.sv
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
  uart_monitor monitor;

  uvm_analysis_port #(uart_seq_item) ap; // analysis port for scoreboard

  function new(string name = "uart_agent", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uart_sequencer::type_id::create("sequencer", this);
    driver = uart_driver::type_id::create("driver", this);
    monitor = uart_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_port.connect(sequencer.seq_port);
    monitor.ap.connect(ap); // monitor connects to agent's analysis port
  endfunction
endclass

`endif

// File: uart_sequencer.sv
`ifndef UART_SEQUENCER_SV
`define UART_SEQUENCER_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_sequencer extends uvm_sequencer #(uart_seq_item);
  `uvm_component_utils(uart_sequencer)

  function new(string name = "uart_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

`endif

// File: uart_driver.sv
`ifndef UART_DRIVER_SV
`define UART_DRIVER_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_driver extends uvm_driver #(uart_seq_item);
  `uvm_component_utils(uart_driver)

  virtual interface uart_if vif; // Declare virtual interface

  function new(string name = "uart_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("UART_DRIVER", "Virtual interface must be set for: vif");
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_seq_item req;
    forever begin
      seq_port.get_next_item(req);
      drive_transaction(req);
      seq_port.item_done();
    end
  endtask

  task drive_transaction(uart_seq_item req);
    `uvm_info("UART_DRIVER", $sformatf("Driving transaction: %s", req.convert2string()), UVM_HIGH)

    // Drive signals based on transaction data
    vif.WB_DAT_I <= req.data;
    vif.WB_WE_I  <= req.write_enable;
    vif.WB_ADDR_I <= req.addr;

    @(posedge vif.WB_CLK_I); // Wait for clock edge

    vif.WB_DAT_I <= '0; // Reset data after clock edge
    vif.WB_WE_I  <= '0;
    vif.WB_ADDR_I <= '0;

  endtask
endclass

`endif

// File: uart_monitor.sv
`ifndef UART_MONITOR_SV
`define UART_MONITOR_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_monitor extends uvm_monitor;
  `uvm_component_utils(uart_monitor)

  virtual interface uart_if vif; // Declare virtual interface

  uvm_analysis_port #(uart_seq_item) ap; // analysis port for scoreboard

  function new(string name = "uart_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("UART_MONITOR", "Virtual interface must be set for: vif");
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.WB_CLK_I);
      collect_transaction();
    end
  endtask

  task collect_transaction();
    uart_seq_item item;

    item = uart_seq_item::type_id::create("item");

    // Sample relevant signals
    item.data = vif.WB_DAT_I;
    item.addr = vif.WB_ADDR_I;
    item.write_enable = vif.WB_WE_I;

    // Sample Status Register (Bit 0)
    if (item.addr == 8'h02 && item.write_enable == 0) begin
      item.status_reg_value = vif.Status_O; //Read status register
    end else begin
      item.status_reg_value = 'x;
    end

    `uvm_info("UART_MONITOR", $sformatf("Collected transaction: %s, IntTx_O=%b", item.convert2string(), vif.IntTx_O), UVM_HIGH)

    // Send the transaction to the scoreboard.
    ap.write(item);
  endtask
endclass

`endif

// File: uart_scoreboard.sv
`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV

`include "uvm_macros.svh"
`include "uart_seq_item.sv"

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  uvm_analysis_imp #(uart_seq_item, uart_scoreboard) analysis_port;

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
  endtask

  function void write(uart_seq_item item);
    bit expected_status;
    `uvm_info("UART_SCOREBOARD", $sformatf("Received item: %s", item.convert2string()), UVM_MEDIUM)

    // Perform Scoreboard Checks
    if (item.addr == 8'h02 && item.write_enable == 0) begin  // Status Register Read
      expected_status = $urandom_range(0, 1); //Create a fake expected status bit
      // Check if Status Register bit 0 matches IntTx_O signal
      if ((item.status_reg_value[0] == 1'b1) == expected_status) begin
        `uvm_info("UART_SCOREBOARD", "Status Register bit 0 matches expected", UVM_LOW)
      end else begin
        `uvm_error("UART_SCOREBOARD", $sformatf("Status Register bit 0 MISMATCH: Expected %b, Received %b", expected_status, item.status_reg_value[0]))
      end
    end
  endfunction
endclass

`endif

// File: uart_if.sv
`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if;
  logic WB_CLK_I;
  logic WB_RST_I;
  logic [7:0] WB_DAT_I;
  logic WB_WE_I;
  logic [7:0] WB_ADDR_I;
  logic IntTx_O; // Interrupt Transmit Output (Tx buffer state indication)
  logic [7:0] Status_O; // Status output for read

  clocking drv_cb @(posedge WB_CLK_I);
    default input #1ns output #1ns;
    output WB_DAT_I;
    output WB_WE_I;
    output WB_ADDR_I;
  endclocking

  clocking mon_cb @(posedge WB_CLK_I);
    default input #1ns output #1ns;
    input WB_DAT_I;
    input WB_WE_I;
    input WB_ADDR_I;
    input IntTx_O;
    input Status_O;
  endclocking
endinterface

`endif
```