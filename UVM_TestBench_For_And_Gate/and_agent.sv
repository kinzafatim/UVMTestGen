```systemverilog
class and_agent extends uvm_agent;

  `uvm_component_utils(and_agent)

  and_sequencer sequencer;
  and_driver driver;
  and_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = and_sequencer::type_id::create("sequencer", this);
    if (is_active == UVM_ACTIVE) begin
      driver = and_driver::type_id::create("driver", this);
    end
    monitor = and_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass
```