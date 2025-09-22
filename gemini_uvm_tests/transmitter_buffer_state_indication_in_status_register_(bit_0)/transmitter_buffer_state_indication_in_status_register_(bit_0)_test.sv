```systemverilog
`ifndef UART_TX_BUFFER_TEST_SV
`define UART_TX_BUFFER_TEST_SV

class uart_tx_buffer_transaction extends uvm_sequence_item;

  rand byte data;
  rand int baud_rate;

  `uvm_object_utils_begin(uart_tx_buffer_transaction)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(baud_rate, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_tx_buffer_transaction");
    super.new(name);
  endfunction

endclass

class uart_tx_buffer_sequence extends uvm_sequence #(uart_tx_buffer_transaction);

  rand int num_transactions;

  `uvm_object_utils_begin(uart_tx_buffer_sequence)
    `uvm_field_int(num_transactions, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_tx_buffer_sequence");
    super.new(name);
  endfunction

  task body();
    uart_tx_buffer_transaction trans;

    repeat (num_transactions) begin
      trans = uart_tx_buffer_transaction::type_id::create("trans");
      assert trans.randomize() with {baud_rate inside {9600, 19200, 115200};};
      trans.print();
      seq_item_port.put(trans);
      `uvm_info("uart_tx_buffer_sequence", $sformatf("Sent transaction with data 0x%h and baud rate %d", trans.data, trans.baud_rate), UVM_LOW)
    end
  endtask

endclass

class uart_tx_buffer_test extends uvm_test;

  uart_tx_buffer_sequence seq;

  `uvm_component_utils(uart_tx_buffer_test)

  function new(string name = "uart_tx_buffer_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_report_info(get_type_name(), "build_phase", UVM_MEDIUM);
    seq = uart_tx_buffer_sequence::type_id::create("seq", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    uvm_report_info(get_type_name(), "run_phase", UVM_MEDIUM);
    seq.num_transactions = 5;
    seq.randomize();
    seq.print();
    seq.start(null);
    phase.drop_objection(this);
  endtask

endclass

class uart_tx_buffer_scoreboard extends uvm_scoreboard;

  uvm_blocking_get_port #(uart_tx_buffer_transaction) analysis_export;

  `uvm_component_utils(uart_tx_buffer_scoreboard)

  int expected_status;

  function new(string name = "uart_tx_buffer_scoreboard", uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    uart_tx_buffer_transaction trans;
    bit inttx_o;
    bit [7:0] status_reg;

    forever begin
      analysis_export.get(trans);

      `uvm_info("uart_tx_buffer_scoreboard", $sformatf("Received transaction with data 0x%h and baud rate %d", trans.data, trans.baud_rate), UVM_LOW)
      // Assuming access to the DUT signals and status register is possible here
      // Replace these dummy assignments with actual signal sampling from the DUT
      #10;
      inttx_o = $urandom_range(0,1); // Example - DUT Signal sampling required
      status_reg = $urandom();        // Example - DUT Register read required
      status_reg[0] = $urandom_range(0,1);

      expected_status = inttx_o;

      if (status_reg[0] != expected_status) begin
        `uvm_error("uart_tx_buffer_scoreboard", $sformatf("Mismatch: Status register bit 0 is %b, expected %b", status_reg[0], expected_status))
      end else begin
        `uvm_info("uart_tx_buffer_scoreboard", $sformatf("Match: Status register bit 0 is %b, expected %b", status_reg[0], expected_status), UVM_LOW)
      end
    end
  endtask

endclass

`endif
```