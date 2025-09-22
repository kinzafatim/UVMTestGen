```systemverilog
class uart_transaction extends uvm_sequence_item;
  rand byte data;
  rand real baud_rate;

  `uvm_object_utils_begin(uart_transaction)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_real(baud_rate, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_transaction");
    super.new(name);
  endfunction

endclass

class uart_sequence extends uvm_sequence #(uart_transaction);

  `uvm_object_utils(uart_sequence)

  function new(string name = "uart_sequence");
    super.new(name);
  endfunction

  task body();
    uart_transaction trans = new();

    repeat (5) begin
      trans.randomize();
      `uvm_info("uart_sequence", $sformatf("Sending data: 0x%h, Baud Rate: %0f", trans.data, trans.baud_rate), UVM_LOW)
      trans.start(this);
    end
  endtask

endclass

class uart_test extends uvm_test;
  `uvm_component_utils(uart_test)

  uart_sequence seq;

  function new(string name = "uart_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seq = new();
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.run();
    phase.drop_objection(this);
  endtask

endclass

class uart_scoreboard extends uvm_scoreboard #(uart_transaction);
  `uvm_component_utils(uart_scoreboard)

  uvm_tlm_fifo #(uart_transaction) expected_fifo;
  uvm_tlm_fifo #(bit) int_fifo;
  uvm_tlm_fifo #(byte) data_out_fifo;
  uvm_tlm_fifo #(bit) status_fifo;

  function new(string name = "uart_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    int_fifo = new("int_fifo", this);
    data_out_fifo = new("data_out_fifo", this);
    status_fifo = new("status_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    uart_transaction expected_trans;
    bit int_val;
    byte data_out;
    bit status;

    forever begin
      expected_fifo.get(expected_trans);
      int_fifo.get(int_val);
      data_out_fifo.get(data_out);
      status_fifo.get(status);

      `uvm_info("uart_scoreboard", $sformatf("Checking transaction: data = 0x%h", expected_trans.data), UVM_MEDIUM)

      if (int_val != 1) begin
        `uvm_error("uart_scoreboard", "IntRx_O did not assert")
      end

      if (status != 1) begin
        `uvm_error("uart_scoreboard", "Status register bit 1 should be '1' after receiving data")
      end
     
      status_fifo.get(status);

      if (status != 0) begin
        `uvm_error("uart_scoreboard", "Status register bit 1 should be '0' after reading data")
      end
    end
  endtask

endclass

class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_scoreboard sb;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sb = uart_scoreboard::type_id::create("sb", this);
  endfunction

endclass

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  uart_env env;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
    uvm_resource_db #(uvm_object_wrapper)::set({"env.sb"},"default_sequence",uart_sequence::type_id::get());
  endfunction

  virtual task run_phase(uvm_phase phase);
    uvm_object_wrapper type_wrapper;
    uvm_sequence_base seq;

    phase.raise_objection(this);
    if (!uvm_resource_db #(uvm_object_wrapper)::get(get_full_name(), "default_sequence", type_wrapper, this)) begin
      `uvm_fatal("TEST", "No default sequence specified")
    end

    seq = type_wrapper.create_object(get_full_name());
    if (seq == null) begin
      `uvm_fatal("TEST", "Failed to create default sequence")
    end

    seq.start(null);
    phase.drop_objection(this);
  endtask

endclass
```