```systemverilog
// seq_item.sv
`ifndef SEQ_ITEM_SV
`define SEQ_ITEM_SV

`include "uvm_macros.svh"

class seq_item extends uvm_sequence_item;
  `uvm_object_utils(seq_item)

  // Define transaction variables
  rand bit [7:0] data;
  rand time delay;
  rand bit valid;

  // Constraints
  constraint delay_c { delay inside { [10ns : 100ns] }; }
  constraint valid_c { valid == 1; }

  function new(string name = "seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("data=%0d delay=%00t valid=%0b", data, delay, valid);
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
      assert(req.randomize());
      `uvm_info("BASE_SEQ", $sformatf("Sending item: %s", req.convert2string()), UVM_LOW)
      start_item(req);
      finish_item(req);
    end
  endtask
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

  function new(string name = "wb_agent", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = wb_sequencer::type_id::create("sequencer", this);
    driver = wb_driver::type_id::create("driver", this);
    monitor = wb_monitor::type_id::create("monitor", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_port.connect(sequencer.seq_export);
  endfunction
endclass

`endif

// wb_driver.sv
`ifndef WB_DRIVER_SV
`define WB_DRIVER_SV

`include "uvm_macros.svh"
`include "seq_item.sv"

class wb_driver extends uvm_driver #(seq_item);
  `uvm_component_utils(wb_driver)

  // Virtual interface to the DUT
  virtual interface wb_if vif;

  function new(string name = "wb_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface wb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
    end
  endfunction

  task run_phase(uvm_phase phase);
    seq_item req;
    forever begin
      seq_port.get_next_item(req);
      drive_transaction(req);
      seq_port.item_done();
    end
  endtask

  task drive_transaction(seq_item req);
    `uvm_info("WB_DRIVER", $sformatf("Driving transaction: %s", req.convert2string()), UVM_MEDIUM)
    vif.WB_DAT_I <= req.data;
    vif.valid <= req.valid;
    @(posedge vif.clk);
    vif.WB_DAT_I <= 0;
    vif.valid <= 0;
    #req.delay;
  endtask
endclass

`endif

// wb_monitor.sv
`ifndef WB_MONITOR_SV
`define WB_MONITOR_SV

`include "uvm_macros.svh"
`include "seq_item.sv"

class wb_monitor extends uvm_monitor;
  `uvm_component_utils(wb_monitor)

  // Virtual interface to the DUT
  virtual interface wb_if vif;

  uvm_analysis_port #(seq_item) item_collected_port;

  function new(string name = "wb_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface wb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
    end
    item_collected_port = new("item_collected_port", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      collect_transaction();
    end
  endtask

  task collect_transaction();
    seq_item collected_item = new("collected_item");
    collected_item.data = vif.WB_DAT_I;
    collected_item.valid = vif.valid;
	`uvm_info("WB_MONITOR", $sformatf("Observed transaction: %s, IntTx_O=%b", collected_item.convert2string(), vif.IntTx_O), UVM_MEDIUM)

    item_collected_port.write(collected_item);
  endtask
endclass

`endif

// wb_sequencer.sv
`ifndef WB_SEQUENCER_SV
`define WB_SEQUENCER_SV

`include "uvm_macros.svh"

class wb_sequencer extends uvm_sequencer;
  `uvm_component_utils(wb_sequencer)

  function new(string name = "wb_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

`endif

// env.sv
`ifndef ENV_SV
`define ENV_SV

`include "uvm_macros.svh"
`include "wb_agent.sv"
`include "scoreboard.sv"

class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  wb_agent agent;
  scoreboard sb;

  function new(string name = "my_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = wb_agent::type_id::create("agent", this);
    sb = scoreboard::type_id::create("sb", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.item_collected_port.connect(sb.analysis_export);
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

  // Expected IntTx_O value (update as needed)
  bit expected_inttx_o;

  // Expected Status Register value (update as needed)
  bit [7:0] expected_status;

  // Virtual interface to the DUT for reading the Status Register
  virtual interface wb_if vif;

  function new(string name = "scoreboard", uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface wb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
    end
  endfunction

  task run_phase(uvm_phase phase);
    seq_item item;
    forever begin
      analysis_export.get(item);
      compare(item);
    end
  endtask

  virtual function void compare(seq_item item);

    // Read the Status Register (Assuming there's a read_status function)
    // and update expected_status based on item.data being transmitted.
    bit [7:0] actual_status = read_status();

    // Check IntTx_O signal. Assumes IntTx_O is low during transfer and high when ready.
    // This logic will depend on how IntTx_O should behave for this specific core.
    if (vif.IntTx_O == 0) begin
       expected_inttx_o = 0;
    end else begin
       expected_inttx_o = 1;
    end

    // Expected status[0] based on IntTx_O.
    expected_status[0] = expected_inttx_o;

    // Check IntTx_O
    if (vif.IntTx_O != expected_inttx_o) begin
      `uvm_error("INTTX_O_MISMATCH", $sformatf("IntTx_O mismatch! Expected: %b, Actual: %b", expected_inttx_o, vif.IntTx_O))
    end else begin
      `uvm_info("INTTX_O_MATCH", $sformatf("IntTx_O match! Expected: %b, Actual: %b", expected_inttx_o, vif.IntTx_O), UVM_LOW)
    end

    // Check Status Register
    if (actual_status != expected_status) begin
      `uvm_error("STATUS_MISMATCH", $sformatf("Status Register mismatch! Expected: %h, Actual: %h", expected_status, actual_status))
    end else begin
      `uvm_info("STATUS_MATCH", $sformatf("Status Register match! Expected: %h, Actual: %h", expected_status, actual_status), UVM_LOW)
    end
  endfunction

  // Dummy function for reading the status register (IMPLEMENT THIS)
  function bit [7:0] read_status();
    // Replace this with the actual code to read the status register
    read_status = 8'b0;
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

  // Constructor
  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: Create environment
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);

    // Configure the virtual interface in the configuration database
    virtual interface wb_if vif;
    if (!uvm_config_db #(virtual interface wb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "No virtual interface specified for the DUT")
    end
    uvm_config_db #(virtual interface wb_if)::set(this, "env.agent.driver", "vif", vif);
    uvm_config_db #(virtual interface wb_if)::set(this, "env.agent.monitor", "vif", vif);
    uvm_config_db #(virtual interface wb_if)::set(this, "env.sb", "vif", vif);
  endfunction

  // Run phase: Run sequences here
  task run_phase(uvm_phase phase);
    base_seq seq;
    phase.raise_objection(this);

    `uvm_info("BASE_TEST", "Starting test...", UVM_LOW)

    seq = base_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #10us;  // Allow time for the sequence to complete and the scoreboard to process
    phase.drop_objection(this);
  endtask
endclass

`endif

// wb_if.sv
`ifndef WB_IF_SV
`define WB_IF_SV

interface wb_if(input bit clk);
  logic [7:0] WB_DAT_I;
  logic valid;
  logic IntTx_O;

  clocking drv_cb @(posedge clk);
    default input #1ns output #1ns;
	output WB_DAT_I;
    output valid;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1ns output #1ns;
	input WB_DAT_I;
    input valid;
    input IntTx_O;
  endclocking
endinterface

`endif

// top.sv
`include "wb_if.sv"
`include "base_test.sv"

module top;
  bit clk;
  wb_if intf(clk);

  // Instantiate DUT here
  // Example: dut dut_inst (.*);

  initial begin
    clk = 0;
    forever #5ns clk = ~clk;
  end

  initial begin
    uvm_config_db #(virtual interface wb_if)::set(null, "uvm_test_top.env.agent.driver", "vif", intf);
    uvm_config_db #(virtual interface wb_if)::set(null, "uvm_test_top.env.agent.monitor", "vif", intf);
    uvm_config_db #(virtual interface wb_if)::set(null, "uvm_test_top.env.sb", "vif", intf);
	run_test("base_test");
  end
endmodule
```