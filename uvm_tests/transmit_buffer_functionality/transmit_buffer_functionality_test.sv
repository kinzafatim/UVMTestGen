```systemverilog
// seq_item.sv
`ifndef SEQ_ITEM_SV
`define SEQ_ITEM_SV

`include "uvm_macros.svh"

class seq_item extends uvm_sequence_item;
  `uvm_object_utils(seq_item)

  // Define transaction variables
  rand bit [7:0] data;
  rand bit       write_enable;
  rand bit [1:0] addr; //Address for UART, only 2 bits needed in this case
  

  function new(string name = "seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint addr_c { addr == 0; }  //Constrain the address to 0 for transmit buffer
  constraint write_enable_c { write_enable == 1; }  //Constrain write_enable to 1 for write operation
  constraint data_c {data inside { [0:255] }; }

  function string convert2string();
    return $sformatf("data=%0h write_enable=%0b addr=%0h", data, write_enable, addr);
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
      assert(req.randomize()); // Randomize the request item

      `uvm_info("BASE_SEQ", $sformatf("Generated transaction: %s", req.convert2string()), UVM_MEDIUM)
      start_item(req);
      finish_item(req);
    end
  endtask
endclass

`endif


// uart_agent.sv (Example agent - adapt to your specific agent)
`ifndef UART_AGENT_SV
`define UART_AGENT_SV

`include "uvm_macros.svh"

class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uvm_sequencer #(seq_item) sequencer;
  // Add monitor and driver handles here

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uvm_sequencer #(seq_item)::type_id::create("sequencer", this);
    //Create monitor and driver here
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect monitor and driver to interface here
  endfunction
endclass

`endif


// my_env.sv
`ifndef MY_ENV_SV
`define MY_ENV_SV

`include "uvm_macros.svh"
`include "uart_agent.sv"

class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  uart_agent agent;

  function new(string name = "my_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = uart_agent::type_id::create("agent", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction
endclass

`endif


// scoreboard.sv
`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

`include "uvm_macros.svh"

class scoreboard extends uvm_component;
  `uvm_component_utils(scoreboard)

  uvm_blocking_subscriber_port #(seq_item) analysis_export;

  function new(string name = "scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    seq_item  item;
    bit [7:0] expected_data;
    bit [7:0] actual_data;

    forever begin
      analysis_export.get(item); // get the item from the analysis port
	  expected_data = item.data;
      `uvm_info("SCOREBOARD", $sformatf("Received transaction: %s", item.convert2string()), UVM_MEDIUM)
		// Add scoreboard logic to compare expected data to actual data received from monitor.
      // Check TxD_PAD_O, IntTx_O, WB_ACK_O, and Status Register
      // Report any discrepancies
	  
      //Example Scoreboard comparison, needs to be updated based on DUT
      //Add monitor class that collects actual_data from the design using uvm_tlm_analysis_port
      //if(expected_data != actual_data) begin
      //  `uvm_error("SCOREBOARD", $sformatf("Data mismatch. Expected: %h, Actual: %h", expected_data, actual_data))
      //end
    end
  endtask
endclass

`endif


// base_test.sv
`ifndef BASE_TEST_SV
`define BASE_TEST_SV

`include "uvm_macros.svh"
`include "my_env.sv"
`include "base_seq.sv"
`include "scoreboard.sv"

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  // Declare environment handle
  my_env env;

  // Declare scoreboard handle
  scoreboard sb;

  // Constructor
  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment and scoreboard
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
    sb = scoreboard::type_id::create("scoreboard", this);
  endfunction

  // Connect phase: connect monitor analysis port to scoreboard
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    //Assuming your uart_agent has an analysis_port named monitor_ap
	// env.agent.monitor.monitor_ap.connect(sb.analysis_export);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    base_seq seq;
    phase.raise_objection(this);

    `uvm_info("BASE_TEST", "Starting test...", UVM_LOW)

    seq = base_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif
```