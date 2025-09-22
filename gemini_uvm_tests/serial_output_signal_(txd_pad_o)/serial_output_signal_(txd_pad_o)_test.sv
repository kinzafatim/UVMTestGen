```systemverilog
`ifndef UVM_TESTCASE_SV
`define UVM_TESTCASE_SV

class serial_transaction extends uvm_sequence_item;
  rand bit [7:0] data;
  rand bit [15:0] baud_rate_divisor;
  rand bit write_enable;
  rand bit [3:0] address;

  `uvm_object_utils_begin(serial_transaction)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(baud_rate_divisor, UVM_ALL_ON)
    `uvm_field_int(write_enable, UVM_ALL_ON)
    `uvm_field_int(address, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "serial_transaction");
    super.new(name);
  endfunction
endclass

class serial_sequence extends uvm_sequence #(serial_transaction);
  `uvm_object_utils(serial_sequence)

  function new(string name = "serial_sequence");
    super.new(name);
  endfunction

  task body();
    serial_transaction trans = new();

    // Configure Baud Rate Divisor
    trans.address = 4'h0; // Assuming address 0x0 is Baud Rate Divisor register
    trans.baud_rate_divisor = 16'd100; // Example divisor
    trans.write_enable = 1'b1;
    `uvm_info("SERIAL_SEQUENCE", $sformatf("Configuring Baud Rate Divisor: %0d", trans.baud_rate_divisor), UVM_MEDIUM)
    trans.print();
    seq_item_port.put(trans);

    // Write Data
    trans = new();
    trans.address = 4'h1; // Assuming address 0x1 is Data register
    trans.data = 8'h41;    // Example Data 'A'
    trans.baud_rate_divisor = 16'd0;
    trans.write_enable = 1'b1;
    `uvm_info("SERIAL_SEQUENCE", $sformatf("Writing Data: %0h", trans.data), UVM_MEDIUM)
    trans.print();
    seq_item_port.put(trans);

    trans = new();
    trans.address = 4'h1; // Assuming address 0x1 is Data register
    trans.data = 8'h42;    // Example Data 'B'
    trans.baud_rate_divisor = 16'd0;
    trans.write_enable = 1'b1;
    `uvm_info("SERIAL_SEQUENCE", $sformatf("Writing Data: %0h", trans.data), UVM_MEDIUM)
    trans.print();
    seq_item_port.put(trans);

    trans = new();
    trans.address = 4'h1; // Assuming address 0x1 is Data register
    trans.data = 8'h43;    // Example Data 'C'
    trans.baud_rate_divisor = 16'd0;
    trans.write_enable = 1'b1;
    `uvm_info("SERIAL_SEQUENCE", $sformatf("Writing Data: %0h", trans.data), UVM_MEDIUM)
    trans.print();
    seq_item_port.put(trans);
  endtask
endclass

class serial_test extends uvm_test;
  `uvm_component_utils(serial_test)

  serial_sequence seq;

  function new(string name = "serial_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_resource_db#(int)::set({"*", "env.agent.sequencer"}, "default_sequence", serial_sequence::get_type());
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq = serial_sequence::type_id::create("seq", this);
    seq.start(env.agent.sequencer);
    phase.drop_objection(this);
  endtask
endclass

class serial_scoreboard extends uvm_scoreboard #(serial_transaction);

  `uvm_component_utils(serial_scoreboard)

  uvm_queue #(bit [7:0]) expected_data_q;

  function new(string name = "serial_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    expected_data_q = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      serial_transaction trans;
      seq_analysis_port.get(trans);

      if (trans.address == 4'h1 && trans.write_enable == 1'b1) begin
        expected_data_q.push_back(trans.data);
        `uvm_info("SCOREBOARD", $sformatf("Expected data pushed: %0h", trans.data), UVM_MEDIUM)
      end
    end
  endtask

  virtual task check_phase(uvm_phase phase);
      uvm_queue #(bit [7:0]) received_data_q;
      received_data_q = env.serial_monitor.received_data_q; // Access the queue from monitor
      if(received_data_q.size() != expected_data_q.size()) begin
         `uvm_error("SCOREBOARD", $sformatf("Mismatch in number of received and expected data. Received: %0d, Expected: %0d",received_data_q.size(), expected_data_q.size()))
      end
      else begin
         while(expected_data_q.size() > 0) begin
            bit [7:0] expected = expected_data_q.pop_front();
            bit [7:0] received = received_data_q.pop_front();
            if(expected != received) begin
               `uvm_error("SCOREBOARD", $sformatf("Data mismatch. Expected: %0h, Received: %0h", expected, received))
            end
            else begin
               `uvm_info("SCOREBOARD", $sformatf("Data matched. Expected: %0h, Received: %0h", expected, received),UVM_MEDIUM)
            end
         end
      end
  endtask
endclass

`endif
```