```systemverilog
class uart_tx_transaction extends uvm_sequence_item;
  rand bit [7:0] data;

  `uvm_object_utils_begin(uart_tx_transaction)
    `uvm_field_int(data, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_tx_transaction");
    super.new(name);
  endfunction
endclass

class uart_tx_sequence extends uvm_sequence #(uart_tx_transaction);
  `uvm_object_utils(uart_tx_sequence)

  function new(string name = "uart_tx_sequence");
    super.new(name);
  endfunction

  task body();
    uart_tx_transaction tx;
    repeat (5) begin
      tx = uart_tx_transaction::type_id::create("tx");
      assert(tx.randomize());
      `uvm_info("UART_TX_SEQ", $sformatf("Sending data: 0x%h", tx.data), UVM_LOW)
      tx.print();
      seq_item_port.put(tx);
      #10;
    end
  endtask
endclass

class uart_tx_test extends uvm_test;
  `uvm_component_utils(uart_tx_test)

  uart_tx_sequence seq;

  function new(string name = "uart_tx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_resource_db#(string)::set({"*",get_full_name()}, "coverage_model", "functional", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq = new("seq");
    seq.start(null);
    #100;
    phase.drop_objection(this);
  endtask
endclass

class uart_tx_monitor extends uvm_monitor;
  `uvm_component_utils(uart_tx_monitor)

  uvm_analysis_port #(bit [7:0]) data_ap;
  uvm_analysis_port #(bit) tx_empty_ap;
  virtual interface uart_if vif;

  function new(string name = "uart_tx_monitor", uvm_component parent = null);
    super.new(name, parent);
    data_ap = new("data_ap", this);
    tx_empty_ap = new("tx_empty_ap", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual interface uart_if)::get(this, "", "uart_vif", vif)) begin
      `uvm_fatal("UART_MON", "virtual interface must be set for: uart_vif");
    end
  endfunction

  task run_phase(uvm_phase phase);
    bit [7:0] data;
    bit int_tx;

    forever begin
      @(posedge vif.wb_clk_i);
      if(vif.wb_we_i && vif.wb_addr_i == 0) begin
        data = vif.wb_dat_i;
        `uvm_info("UART_TX_MON", $sformatf("Monitored data: 0x%h", data), UVM_MEDIUM)
        data_ap.write(data);
      end
      @(posedge vif.wb_clk_i);
      int_tx = vif.IntTx_O;
      tx_empty_ap.write(int_tx);
    end
  endtask
endclass

class uart_tx_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_tx_scoreboard)

  uvm_blocking_get_port #(bit [7:0]) data_gp;
  uvm_blocking_get_port #(bit) tx_empty_gp;

  bit [7:0] expected_data_q[$];
  bit expected_tx_empty_q[$];

  function new(string name = "uart_tx_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    data_gp = new("data_gp", this);
    tx_empty_gp = new("tx_empty_gp", this);
  endfunction

  task run_phase(uvm_phase phase);
    bit [7:0] received_data;
    bit received_tx_empty;

    fork
      begin
        forever begin
          data_gp.get(received_data);
          expected_data_q.push_back(received_data);
        end
      end

      begin
        forever begin
          tx_empty_gp.get(received_tx_empty);
          expected_tx_empty_q.push_back(received_tx_empty);
        end
      end

      begin
        wait (expected_data_q.size() >= 5 && expected_tx_empty_q.size() >= 5);
        compare_data();
      end
    join_none
    #100;
  endtask

  task compare_data();
    bit [7:0] expected_data;
    bit expected_tx_empty;
    for(int i = 0; i < 5; i++)begin
      expected_data = expected_data_q.pop_front();
      expected_tx_empty = expected_tx_empty_q.pop_front();
       `uvm_info("SCOREBOARD", $sformatf("Data 0x%h and IntTx %b",expected_data, expected_tx_empty), UVM_MEDIUM);
    end
  endtask
endclass

interface uart_if;
  logic wb_clk_i;
  logic wb_rst_i;
  logic [1:0] wb_addr_i;
  logic [7:0] wb_dat_i;
  logic wb_we_i;
  logic RxD_PAD_I;
  logic TxD_PAD_O;
  logic IntTx_O;
  logic wb_ack_o;
endinterface

class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_tx_monitor mon;
  uart_tx_scoreboard sb;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = uart_tx_monitor::type_id::create("mon", this);
    sb = uart_tx_scoreboard::type_id::create("sb", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.data_ap.connect(sb.data_gp);
    mon.tx_empty_ap.connect(sb.tx_empty_gp);
  endfunction
endclass

class uart_agent_configuration extends uvm_object;

  rand bit enable_coverage;
  rand bit enable_logging;
  `uvm_object_utils_begin(uart_agent_configuration)
    `uvm_field_int(enable_coverage, UVM_ALL_ON)
    `uvm_field_int(enable_logging, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_agent_configuration");
    super.new(name);
  endfunction

endclass

class uart_agent extends uvm_agent;
 `uvm_component_utils(uart_agent)

 uart_agent_configuration config;

  function new (string name = "uart_agent", uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    config = new("config");
  endfunction

endclass

module top;
  bit clk;
  bit rst;

  uart_if vif(clk, rst);

  initial begin
    clk = 0;
    rst = 1;
    #10 rst = 0;
    #1000 $finish;
  end

  always #5 clk = ~clk;

  initial begin
    uvm_config_db #(virtual interface uart_if)::set(null, "uvm_test_top.*", "uart_vif", vif);
    run_test("uart_tx_test");
  end

  uart dut (
    .WB_CLK_I(vif.wb_clk_i),
    .WB_RST_I(vif.wb_rst_i),
    .WB_ADDR_I(vif.wb_addr_i),
    .WB_DAT_I(vif.wb_dat_i),
    .WB_WE_I(vif.wb_we_i),
    .RxD_PAD_I(vif.RxD_PAD_I),
    .TxD_PAD_O(vif.TxD_PAD_O),
    .IntTx_O(vif.IntTx_O),
    .WB_ACK_O(vif.wb_ack_o)
  );
endmodule

module uart (
  input bit WB_CLK_I,
  input bit WB_RST_I,
  input bit [1:0] WB_ADDR_I,
  input bit [7:0] WB_DAT_I,
  input bit WB_WE_I,
  input bit RxD_PAD_I,
  output bit TxD_PAD_O,
  output bit IntTx_O,
  output bit WB_ACK_O
);

  reg [7:0] transmit_buffer;
  reg tx_busy;

  always @(posedge WB_CLK_I) begin
    if (WB_RST_I) begin
      transmit_buffer <= 0;
      tx_busy <= 0;
      IntTx_O <= 1;
      WB_ACK_O <= 0;
    end else begin
      if (WB_WE_I && WB_ADDR_I == 0 && !tx_busy) begin
        transmit_buffer <= WB_DAT_I;
        tx_busy <= 1;
        IntTx_O <= 0;
        WB_ACK_O <= 1;
        #1 WB_ACK_O <=0;

      end else begin
        WB_ACK_O <= 0;
      end
    end
  end

  always @(posedge WB_CLK_I) begin
    if (WB_RST_I) begin
      TxD_PAD_O <= 1;
    end else if (tx_busy) begin
      bit [10:0] shift_reg;
      shift_reg[0] = 0;
      shift_reg[8:1] = transmit_buffer;
      shift_reg[9] = 1;
      shift_reg[10] = 1;
      for (int i = 0; i < 10; i++) begin
        @(posedge WB_CLK_I);
        TxD_PAD_O <= shift_reg[0];
        shift_reg = {1'b1, shift_reg[10:1]};
      end
        tx_busy <=0;
        IntTx_O <=1;
    end
  end
endmodule
```