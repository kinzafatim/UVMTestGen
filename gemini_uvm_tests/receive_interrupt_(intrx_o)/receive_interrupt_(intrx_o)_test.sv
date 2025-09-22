```systemverilog
class uart_rx_transaction extends uvm_sequence_item;
  rand bit [7:0] rxd_data;

  `uvm_object_utils_begin(uart_rx_transaction)
    `uvm_field_int(rxd_data, UVM_ALL_ON)
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
    uart_rx_transaction trans;
    repeat (5) begin
      trans = uart_rx_transaction::type_id::create("trans");
      assert(trans.randomize());
      trans.print();
      `uvm_do(trans)
    end
  endtask
endclass

class uart_rx_test extends uvm_test;

  `uvm_component_utils(uart_rx_test)

  uart_rx_sequence seq;

  function new(string name = "uart_rx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq = new("seq");
    seq.start(null);
    #100ns;
    phase.drop_objection(this);
  endtask
endclass

class uart_rx_scoreboard extends uvm_scoreboard #(uart_rx_transaction, bit [7:0], bit, bit);
  `uvm_component_utils(uart_rx_scoreboard)

  uvm_tlm_analysis_fifo #(uart_rx_transaction)  mon_rxd_fifo;
  uvm_tlm_analysis_fifo #(bit [7:0]) wb_dat_fifo;
  uvm_tlm_analysis_fifo #(bit) intrx_o_fifo;
  uvm_tlm_analysis_fifo #(bit) wb_ack_o_fifo;

  function new(string name = "uart_rx_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    mon_rxd_fifo = new("mon_rxd_fifo", this);
    wb_dat_fifo = new("wb_dat_fifo", this);
    intrx_o_fifo = new("intrx_o_fifo", this);
    wb_ack_o_fifo = new("wb_ack_o_fifo", this);

  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    uart_rx_transaction  mon_rxd_item;
    bit [7:0] wb_dat_item;
    bit intrx_o_item;
    bit wb_ack_o_item;

    forever begin
      mon_rxd_fifo.get(mon_rxd_item);
      wb_dat_fifo.get(wb_dat_item);
      intrx_o_fifo.get(intrx_o_item);
      wb_ack_o_fifo.get(wb_ack_o_item);

      if(mon_rxd_item.rxd_data != wb_dat_item) begin
        `uvm_error("SB", $sformatf("Data mismatch: Expected %h, Received %h", mon_rxd_item.rxd_data, wb_dat_item));
      end else begin
        `uvm_info("SB", $sformatf("Data match: Expected %h, Received %h", mon_rxd_item.rxd_data, wb_dat_item), UVM_LOW);
      end

      if(!intrx_o_item) begin
         `uvm_error("SB", $sformatf("IntRx_O should be asserted"));
      end else begin
        `uvm_info("SB", $sformatf("IntRx_O asserted as expected"), UVM_LOW);
      end

      if(!wb_ack_o_item) begin
         `uvm_error("SB", $sformatf("WB_ACK_O should be asserted"));
      end else begin
        `uvm_info("SB", $sformatf("WB_ACK_O asserted as expected"), UVM_LOW);
      end
    end
  endtask

  virtual function void write_rxd_data(uart_rx_transaction trans);
    mon_rxd_fifo.put(trans);
  endfunction

  virtual function void write_wb_data(bit [7:0] data);
    wb_dat_fifo.put(data);
  endfunction

  virtual function void write_intrx_o(bit data);
    intrx_o_fifo.put(data);
  endfunction
  virtual function void write_wb_ack_o(bit data);
    wb_ack_o_fifo.put(data);
  endfunction

endclass
```