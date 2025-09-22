```systemverilog
class wb_transaction extends uvm_sequence_item;
  rand bit [7:0] data;
  rand time delay;

  `uvm_object_utils_begin(wb_transaction)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(delay, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "wb_transaction");
    super.new(name);
  endfunction
endclass

class wb_sequence extends uvm_sequence #(wb_transaction);

  `uvm_object_utils(wb_sequence)

  function new(string name = "wb_sequence");
    super.new(name);
  endfunction

  task body();
    wb_transaction trans = new();
    repeat(5) begin
      trans.randomize();
      trans.delay = trans.delay % 10ns + 1ns;
      `uvm_info("wb_sequence", $sformatf("Sending data: 0x%h, delay: %0t", trans.data, trans.delay), UVM_LOW)
      trans.print();
      seq_item_port.put(trans);
      #trans.delay;
    end
  endtask
endclass

class wb_monitor extends uvm_monitor;

  `uvm_component_utils(wb_monitor)

  virtual interface wb_if vif;
  uvm_analysis_port #(wb_transaction) mon_ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mon_ap = new("mon_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(vif == null) begin
      `uvm_fatal("WB_MONITOR", "Virtual interface is null");
    end
  endfunction

  task run_phase(uvm_phase phase);
    wb_transaction trans;
    forever begin
      @(posedge vif.clk);
      if (vif.wb_stb_i && vif.wb_cyc_i) begin
        trans = new();
        trans.data = vif.wb_dat_i;
        `uvm_info("wb_monitor", $sformatf("Monitored data: 0x%h", trans.data), UVM_LOW)
        mon_ap.write(trans);
      end
    end
  endtask
endclass

class wb_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(wb_scoreboard)

  uvm_blocking_get_port #(wb_transaction) get_port;
  virtual interface wb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    get_port = new("get_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      if(vif == null) begin
        `uvm_fatal("WB_SCOREBOARD", "Virtual interface is null");
      end
  endfunction

  task run_phase(uvm_phase phase);
    wb_transaction trans;
    bit prev_inttx_o;
    bit current_inttx_o;

    forever begin
      get_port.get(trans);

      prev_inttx_o = vif.IntTx_O;

      @(posedge vif.clk);

      current_inttx_o = vif.IntTx_O;

      if(prev_inttx_o && !current_inttx_o) begin
        `uvm_info("wb_scoreboard", "IntTx_O asserted low during transmission", UVM_LOW)
      end

      @(posedge vif.clk);
      if(!vif.IntTx_O) begin
          @(posedge vif.clk);
      end

      if(!vif.IntTx_O) begin
          @(posedge vif.clk);
      end
      if(vif.IntTx_O) begin
        `uvm_info("wb_scoreboard", "IntTx_O asserted high after transmission", UVM_LOW)
      end
       @(posedge vif.clk);
      if (vif.status_reg[0] == vif.IntTx_O) begin
        `uvm_info("wb_scoreboard", $sformatf("Status register bit 0 matches IntTx_O: %b", vif.IntTx_O), UVM_LOW)
      end else begin
        `uvm_error("wb_scoreboard", $sformatf("Status register bit 0 (%b) does not match IntTx_O (%b)", vif.status_reg[0], vif.IntTx_O))
      end
    end
  endtask
endclass

class environment extends uvm_env;

  `uvm_component_utils(environment)

  wb_monitor mon;
  wb_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = wb_monitor::type_id::create("mon", this);
    sb = wb_scoreboard::type_id::create("sb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    mon.mon_ap.connect(sb.get_port);
  endfunction

endclass

class wb_test extends uvm_test;

  `uvm_component_utils(wb_test)

  environment env;
  wb_sequence seq;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = environment::type_id::create("env", this);
    uvm_resource_db #(virtual wb_if)::set("top.env.mon", "vif", vif);
    uvm_resource_db #(virtual wb_if)::set("top.env.sb", "vif", vif);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq = wb_sequence::type_id::create("seq");
    seq.start(null);
    #100ns;
    phase.drop_objection(this);
  endtask

  virtual wb_if vif;

endclass
```