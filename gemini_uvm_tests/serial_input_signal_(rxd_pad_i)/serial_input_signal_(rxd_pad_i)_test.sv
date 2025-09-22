```systemverilog
class rxd_transaction extends uvm_sequence_item;
  rand bit [7:0] data;
  rand bit [3:0] baud_rate;

  `uvm_object_utils_begin(rxd_transaction)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(baud_rate, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "rxd_transaction");
    super.new(name);
  endfunction
endclass

class rxd_sequence extends uvm_sequence #(rxd_transaction);
  `uvm_object_utils(rxd_sequence)

  function new(string name = "rxd_sequence");
    super.new(name);
  endfunction

  task body();
    rxd_transaction trans = new();
    repeat(10) begin
      trans.randomize();
      `uvm_info("rxd_sequence", $sformatf("Sending data: 0x%h, baud_rate: %d", trans.data, trans.baud_rate), UVM_MEDIUM)
      trans.print();
      seq_item_port.put(trans);
    end
  endtask
endclass

class rxd_testcase extends uvm_test;
  `uvm_component_utils(rxd_testcase)

  rxd_sequence seq;

  function new(string name = "rxd_testcase", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq = new();
    seq.start(env.agent.sequencer);
    phase.drop_objection(this);
  endtask
endclass

class rxd_scoreboard extends uvm_scoreboard #(rxd_transaction, rxd_transaction);
  `uvm_component_utils(rxd_scoreboard)

  uvm_tlm_analysis_fifo #(rxd_transaction) observed_fifo;

  function new(string name = "rxd_scoreboard", uvm_component parent);
    super.new(name, parent);
    observed_fifo = new("observed_fifo", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    rxd_transaction expected_trans;
    rxd_transaction observed_trans;

    while (1) begin
      seq_fifo.get(expected_trans);
      observed_fifo.get(observed_trans);

      if (expected_trans.data == observed_trans.data) begin
        `uvm_info("rxd_scoreboard", $sformatf("Data matched: 0x%h", expected_trans.data), UVM_MEDIUM)
      end else begin
        `uvm_error("rxd_scoreboard", $sformatf("Data mismatch: Expected 0x%h, Observed 0x%h", expected_trans.data, observed_trans.data))
      end

    end
  endtask
endclass
```