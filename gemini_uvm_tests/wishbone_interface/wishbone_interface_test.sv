```systemverilog
class wishbone_transaction extends uvm_sequence_item;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit we;
  rand bit stb;
  rand bit rst;

  bit [31:0] read_data;
  bit ack;

  `uvm_object_utils_begin(wishbone_transaction)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(we, UVM_ALL_ON)
    `uvm_field_int(stb, UVM_ALL_ON)
    `uvm_field_int(rst, UVM_ALL_ON)
    `uvm_field_int(read_data, UVM_ALL_ON)
    `uvm_field_int(ack, UVM_ALL_ON)
  `uvm_object_utils_end

  function new (string name = "wishbone_transaction");
    super.new(name);
  endfunction
endclass

class wishbone_sequence extends uvm_sequence #(wishbone_transaction);
  `uvm_object_utils(wishbone_sequence)

  function new (string name = "wishbone_sequence");
    super.new(name);
  endfunction

  task body();
    wishbone_transaction trans;

    // Reset
    trans = wishbone_transaction::type_id::create("trans");
    trans.addr = 0;
    trans.data = 0;
    trans.we = 0;
    trans.stb = 0;
    trans.rst = 1;
    start_item(trans);
    finish_item(trans);

    // Write to THR
    trans = wishbone_transaction::type_id::create("trans");
    trans.addr = 'h10; // THR address
    trans.data = 'hA5A5A5A5;
    trans.we = 1;
    trans.stb = 1;
    trans.rst = 0;
    start_item(trans);
    finish_item(trans);

    // Read from RBR
    trans = wishbone_transaction::type_id::create("trans");
    trans.addr = 'h00; // RBR address
    trans.data = 0;
    trans.we = 0;
    trans.stb = 1;
    trans.rst = 0;
    start_item(trans);
    finish_item(trans);
  endtask
endclass

class wishbone_driver extends uvm_driver #(wishbone_transaction);
  `uvm_component_utils(wishbone_driver)

  virtual interface wb_if vif;

  function new (string name = "wishbone_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface wb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "virtual interface must be set for: vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    wishbone_transaction trans;
    forever begin
      seq_item_port.get_next_item(trans);
      drive_transaction(trans);
      seq_item_port.item_done();
    end
  endtask

  task drive_transaction(wishbone_transaction trans);
    vif.WB_ADDR_I <= trans.addr;
    vif.WB_DAT_I <= trans.data;
    vif.WB_WE_I <= trans.we;
    vif.WB_STB_I <= trans.stb;
    vif.WB_RST_I <= trans.rst;

    @(posedge vif.clk);
    trans.read_data = vif.WB_DAT_O;
    trans.ack = vif.WB_ACK_O;
  endtask
endclass

class wishbone_monitor extends uvm_monitor;
  `uvm_component_utils(wishbone_monitor)

  virtual interface wb_if vif;
  uvm_analysis_port #(wishbone_transaction) item_collected_port;

  function new (string name = "wishbone_monitor", uvm_component parent = null);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface wb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "virtual interface must be set for: vif")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      wishbone_transaction trans = wishbone_transaction::type_id::create("trans");
      trans.addr = vif.WB_ADDR_I;
      trans.data = vif.WB_DAT_I;
      trans.we = vif.WB_WE_I;
      trans.stb = vif.WB_STB_I;
      trans.rst = vif.WB_RST_I;
      trans.read_data = vif.WB_DAT_O;
      trans.ack = vif.WB_ACK_O;
      item_collected_port.write(trans);
    end
  endtask
endclass

class wishbone_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(wishbone_scoreboard)

  uvm_blocking_get_port #(wishbone_transaction) analysis_export;
  wishbone_transaction expected_q[$];

  function new (string name = "wishbone_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  task run_phase(uvm_phase phase);
    wishbone_transaction trans;
    bit [31:0] expected_data;

    forever begin
      analysis_export.get(trans);

      if (trans.addr == 'h10 && trans.we == 1 && trans.stb == 1) begin
        expected_q.push_back(trans);
      end

      if (trans.addr == 'h00 && trans.we == 0 && trans.stb == 1) begin
        if (expected_q.size() > 0) begin
          expected_data = expected_q[0].data;
          expected_q.pop_front();
          if(trans.read_data != expected_data) begin
              `uvm_error("SCOREBOARD", $sformatf("Data mismatch. Expected: %h, Actual: %h", expected_data, trans.read_data));
          end else begin
              `uvm_info("SCOREBOARD", $sformatf("Data match. Expected: %h, Actual: %h", expected_data, trans.read_data), UVM_MEDIUM);
          end
          if(!trans.ack) begin
              `uvm_error("SCOREBOARD", "ACK not asserted");
          end else begin
              `uvm_info("SCOREBOARD", "ACK asserted", UVM_MEDIUM);
          end
        end else begin
          `uvm_error("SCOREBOARD", "No expected transaction found for RBR read");
        end
      end
    end
  endtask
endclass

class wishbone_env extends uvm_env;
  `uvm_component_utils(wishbone_env)

  wishbone_driver driver;
  wishbone_monitor monitor;
  wishbone_scoreboard scoreboard;

  function new (string name = "wishbone_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver = wishbone_driver::type_id::create("driver", this);
    monitor = wishbone_monitor::type_id::create("monitor", this);
    scoreboard = wishbone_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(m_sequencer.seq_item_export);
    monitor.item_collected_port.connect(scoreboard.analysis_export);
  endfunction
endclass

class wishbone_test extends uvm_test;
  `uvm_component_utils(wishbone_test)

  wishbone_env env;
  wishbone_sequence seq;

  function new (string name = "wishbone_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = wishbone_env::type_id::create("env", this);
    uvm_report_server rsp = uvm_report_server::get_server();
    rsp.set_severity_id_action(UVM_INFO, UVM_NO_ID, UVM_DISPLAY);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq = wishbone_sequence::type_id::create("seq");
    seq.start(env.m_sequencer);
    #100ns;
    phase.drop_objection(this);
  endtask
endclass
```