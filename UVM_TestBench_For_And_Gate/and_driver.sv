```systemverilog
class and_driver extends uvm_driver #(and_sequence_item);

  `uvm_component_utils(and_driver)

  virtual interface and_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual interface and_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("AND_DRIVER", "virtual interface must be set for vif!!!")
    end
  endfunction

  task run_phase(uvm_phase phase);
    and_sequence_item req;
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info("and_driver", $sformatf("Driving A=%b, B=%b", req.A, req.B), UVM_HIGH)
      vif.A <= req.A;
      vif.B <= req.B;
      seq_item_port.item_done();
    end
  endtask

endclass
```