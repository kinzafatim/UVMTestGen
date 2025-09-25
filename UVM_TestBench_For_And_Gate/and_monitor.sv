```systemverilog
class and_monitor extends uvm_monitor;

  `uvm_component_utils(and_monitor)

  virtual interface and_if vif;
  uvm_analysis_port #(and_sequence_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface and_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("AND_MONITOR", "virtual interface must be set for vif!!!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.cb);
      and_sequence_item item = new("item");
      item.A = vif.A;
      item.B = vif.B;
      item.Y = vif.Y;
      `uvm_info("and_monitor", $sformatf("Monitored A=%b, B=%b, Y=%b", item.A, item.B, item.Y), UVM_HIGH)
      analysis_port.write(item);
    end
  endtask

endclass
```