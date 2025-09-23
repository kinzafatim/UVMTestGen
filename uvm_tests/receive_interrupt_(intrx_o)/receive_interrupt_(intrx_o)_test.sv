```systemverilog
`ifndef INTRX_TEST_SV
`define INTRX_TEST_SV

`include "uvm_macros.svh"
`include "intr_env.sv"
`include "intr_seq.sv"

class intrx_test extends uvm_test;
  `uvm_component_utils(intrx_test)

  intr_env env;

  function new(string name = "intrx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = intr_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    intr_seq seq;
    phase.raise_objection(this);

    `uvm_info("INTRX_TEST", "Starting Interrupt Receive Test...", UVM_LOW)

    seq = intr_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif

`ifndef INTR_SEQ_SV
`define INTR_SEQ_SV

`include "uvm_macros.svh"
`include "intr_item.sv"

class intr_seq extends uvm_sequence #(intr_item);
  `uvm_object_utils(intr_seq)

  function new(string name = "intr_seq");
    super.new(name);
  endfunction

  task body();
    intr_item req;

    `uvm_info("INTR_SEQ", "Starting Interrupt Sequence", UVM_LOW)
    repeat (5) begin
      req = intr_item::type_id::create("req");
      start_item(req);
      assert (req.randomize());
      `uvm_info("INTR_SEQ", $sformatf("Sending item: %s", req.convert2string()), UVM_HIGH)
      finish_item(req);
    end
  endtask
endclass

`endif

`ifndef INTR_ITEM_SV
`define INTR_ITEM_SV

`include "uvm_macros.svh"

class intr_item extends uvm_sequence_item;
  `uvm_object_utils(intr_item)

  rand bit [7:0] data;
  rand bit wb_stb_i;
  rand int delay;

  constraint delay_range { delay inside {[0:5]}; }

  function new(string name = "intr_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("data=0x%h wb_stb_i=%0b delay=%0d", data, wb_stb_i, delay);
  endfunction
endclass

`endif

`ifndef INTR_ENV_SV
`define INTR_ENV_SV

`include "uvm_macros.svh"
`include "intr_agent.sv"
`include "intr_scoreboard.sv"

class intr_env extends uvm_env;
  `uvm_component_utils(intr_env)

  intr_agent agent;
  intr_scoreboard scoreboard;

  function new(string name = "intr_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = intr_agent::type_id::create("agent", this);
    scoreboard = intr_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.analysis_port.connect(scoreboard.analysis_imp);
  endfunction
endclass

`endif

`ifndef INTR_AGENT_SV
`define INTR_AGENT_SV

`include "uvm_macros.svh"
`include "intr_sequencer.sv"
`include "intr_driver.sv"
`include "intr_monitor.sv"

class intr_agent extends uvm_agent;
  `uvm_component_utils(intr_agent)

  intr_sequencer sequencer;
  intr_driver driver;
  intr_monitor monitor;

  function new(string name = "intr_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = intr_sequencer::type_id::create("sequencer", this);
    driver = intr_driver::type_id::create("driver", this);
    monitor = intr_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_port.connect(sequencer.seq_export);
  endfunction
endclass

`endif

`ifndef INTR_SEQUENCER_SV
`define INTR_SEQUENCER_SV

`include "uvm_macros.svh"

class intr_sequencer extends uvm_sequencer;
  `uvm_component_utils(intr_sequencer)

  function new(string name = "intr_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

`endif

`ifndef INTR_DRIVER_SV
`define INTR_DRIVER_SV

`include "uvm_macros.svh"

class intr_driver extends uvm_driver #(intr_item);
  `uvm_component_utils(intr_driver)

  virtual interface uart_if vif;

  function new(string name = "intr_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("INTR_DRIVER", "virtual interface must be set for vif!!!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    intr_item req;
    forever begin
      seq_port.get_next_item(req);
      drive_transaction(req);
      seq_port.item_done();
    end
  endtask

  task drive_transaction(intr_item req);
    `uvm_info("INTR_DRIVER", $sformatf("Driving item: %s", req.convert2string()), UVM_HIGH)

    vif.RxD_PAD_I <= req.data;
    vif.WB_STB_I <= req.wb_stb_i;

    repeat (req.delay) @(posedge vif.BR_CLK_I);
  endtask
endclass

`endif

`ifndef INTR_MONITOR_SV
`define INTR_MONITOR_SV

`include "uvm_macros.svh"
`include "intr_item.sv"

class intr_monitor extends uvm_monitor;
  `uvm_component_utils(intr_monitor)

  virtual interface uart_if vif;
  uvm_analysis_port #(intr_item) analysis_port;

  function new(string name = "intr_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port", this);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("INTR_MONITOR", "virtual interface must be set for vif!!!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.BR_CLK_I);
      collect_transaction();
    end
  endtask

  task collect_transaction();
    intr_item tr = new("tr");
    tr.data = vif.RxD_PAD_I;
    tr.wb_stb_i = vif.WB_STB_I;

    `uvm_info("INTR_MONITOR", $sformatf("Monitored: data=0x%h, WB_STB_I=%0b, IntRx_O=%0b", vif.RxD_PAD_I, vif.WB_STB_I, vif.IntRx_O), UVM_HIGH)

    analysis_port.write(tr);
  endtask
endclass

`endif

`ifndef INTR_SCOREBOARD_SV
`define INTR_SCOREBOARD_SV

`include "uvm_macros.svh"
`include "intr_item.sv"

class intr_scoreboard extends uvm_component;
  `uvm_component_utils(intr_scoreboard)

  uvm_analysis_imp #(intr_item, intr_scoreboard) analysis_imp;
  virtual interface uart_if vif;

  bit [7:0] expected_data;
  bit       expected_intr;

  function new(string name = "intr_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_imp = new("analysis_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("INTR_SCOREBOARD", "virtual interface must be set for vif!!!")
    end
  endfunction


  task write(intr_item tr);

      if(tr.wb_stb_i == 1) begin
        `uvm_info("INTR_SCOREBOARD", "WB_STB_I asserted", UVM_MEDIUM)
        //check data
        if(vif.WB_DAT_O != tr.data) begin
          `uvm_error("INTR_SCOREBOARD", $sformatf("Data mismatch! Expected 0x%h, Received 0x%h", tr.data, vif.WB_DAT_O))
        end else begin
          `uvm_info("INTR_SCOREBOARD", $sformatf("Data Match: Data = 0x%h", vif.WB_DAT_O), UVM_MEDIUM)
        end
        //check interrupt deassertion
        @(posedge vif.WB_ACK_O);
        if(vif.IntRx_O == 1) begin
            `uvm_error("INTR_SCOREBOARD", "Interrupt not deasserted after WB_ACK_O");
        end else begin
            `uvm_info("INTR_SCOREBOARD", "Interrupt Deasserted after WB_ACK_O", UVM_MEDIUM)
        end
      end else begin
        //check interrupt assertion
        if(vif.IntRx_O == 0) begin
            `uvm_error("INTR_SCOREBOARD", "Interrupt not asserted");
        end else begin
            `uvm_info("INTR_SCOREBOARD", "Interrupt Asserted", UVM_MEDIUM)
        end
      end

  endtask

endclass

`endif

`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if;
  logic BR_CLK_I;
  logic RxD_PAD_I;
  logic WB_STB_I;
  logic WB_ACK_O;
  logic [7:0] WB_DAT_O;
  logic IntRx_O;
endinterface

`endif
```