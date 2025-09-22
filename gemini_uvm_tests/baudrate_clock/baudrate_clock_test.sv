```systemverilog
class baudrate_transaction extends uvm_sequence_item;
  rand bit [7:0] data;

  `uvm_object_utils_begin(baudrate_transaction)
    `uvm_field_int(data, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "baudrate_transaction");
    super.new(name);
  endfunction
endclass

class baudrate_sequence extends uvm_sequence #(baudrate_transaction);
  rand int num_transactions;

  constraint num_transactions_c {
    num_transactions inside {[1:10]};
  }

  `uvm_object_utils(baudrate_sequence)

  function new(string name = "baudrate_sequence");
    super.new(name);
  endfunction

  virtual task body();
    baudrate_transaction trans;
    repeat (num_transactions) begin
      trans = baudrate_transaction::type_id::create("trans");
      assert(trans.randomize());
      `uvm_info("baudrate_sequence", $sformatf("Sending data: 0x%h", trans.data), UVM_LOW)
      trans.print();
      seq_item_port.put(trans);
    end
  endtask
endclass

class baudrate_test extends uvm_test;
  `uvm_component_utils(baudrate_test)

  baudrate_sequence seq;

  function new(string name = "baudrate_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_report_server::get_server().set_severity_truncation(UVM_NONE);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq = baudrate_sequence::type_id::create("seq", this);
    seq.randomize();
    seq.start(null);
    phase.drop_objection(this);
  endtask
endclass
```