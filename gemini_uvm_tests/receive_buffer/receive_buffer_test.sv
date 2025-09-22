```systemverilog
class uart_rx_transaction extends uvm_sequence_item;
  rand bit [7:0] data;

  `uvm_object_utils_begin(uart_rx_transaction)
    `uvm_field_int(data, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_rx_transaction");
    super.new(name);
  endfunction

endclass

class uart_rx_sequence extends uvm_sequence #(uart_rx_transaction);

  `uvm_object_utils(uart_rx_sequence)

  function new(string name = "uart_rx_sequence");
    super.new(name);
  endfunction

  task body();
    uart_rx_transaction req;
    repeat (1) begin
      req = uart_rx_transaction::type_id::create("req");
      assert(req.randomize());
      req.print();
      seq_item_port.put(req);
    end
  endtask

endclass

class uart_rx_test extends uvm_test;
  `uvm_component_utils(uart_rx_test)

  uart_rx_sequence seq;

  function new(string name = "uart_rx_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seq = uart_rx_sequence::type_id::create("seq", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.start(null);
    #100ns;
    phase.drop_objection(this);
  endtask

endclass

class uart_env_config extends uvm_object;
  rand int brdivisor;

  `uvm_object_utils_begin(uart_env_config)
    `uvm_field_int(brdivisor, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_env_config");
    super.new(name);
  endfunction
endclass

class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_env_config cfg;
  uvm_analysis_port #(uart_rx_transaction) analysis_port;

  function new(string name = "uart_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db #(uart_env_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("CONFIG_ERR", "Failed to get cfg from uvm_config_db")
    end
    analysis_port = new("analysis_port", this);
  endfunction
endclass

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  uvm_blocking_peek_port #(bit [7:0]) peek_port;
  bit [7:0] expected_data;
  bit [7:0] received_data;
  bit int_rx_o;
  bit [7:0] wb_dat_o;
  bit [7:0] wb_dat_i;
  bit wb_adr_i;

  function new(string name = "uart_scoreboard", uvm_component parent);
    super.new(name, parent);
    peek_port = new("peek_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    `uvm_info("SCOREBOARD", $sformatf("Starting scoreboard"), UVM_MEDIUM)

    forever begin
      peek_port.peek(received_data);

      if (received_data != expected_data) begin
        `uvm_error("SCOREBOARD", $sformatf("Data mismatch! Expected: 0x%h, Received: 0x%h", expected_data, received_data));
      end else begin
        `uvm_info("SCOREBOARD", $sformatf("Data match! Expected: 0x%h, Received: 0x%h", expected_data, received_data), UVM_MEDIUM);
      end
    end

    phase.drop_objection(this);
  endtask

  virtual task write_data(bit [7:0] expected);
      expected_data = expected;
  endtask

endclass
```