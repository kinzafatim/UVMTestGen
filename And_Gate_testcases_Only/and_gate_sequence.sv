```systemverilog
`ifndef AND_GATE_SEQ_SV
`define AND_GATE_SEQ_SV

`include "uvm_macros.svh"

// Assuming seq_item has members 'a', 'b', and 'y_expect'
//  and a randomize() function that constrains them as needed.

class and_gate_seq extends uvm_sequence #(seq_item);
  `uvm_object_utils(and_gate_seq)

  rand bit a;
  rand bit b;

  function new(string name = "and_gate_seq");
    super.new(name);
  endfunction

  task body();
    seq_item req;

    `uvm_info("AND_GATE_SEQ", "Starting AND gate sequence", UVM_LOW)

    // Cover all possible input combinations: (0,0), (0,1), (1,0), (1,1)
    //  Plus some random iterations.

    // Test Case F002: A=0, B=0, Y=0
    req = seq_item::type_id::create("req");
    start_item(req);
    req.a = 0;
    req.b = 0;
    req.y_expect = 0;  // Set expected output for scoreboard
    finish_item(req);

    // Test Case F003: A=0, B=1, Y=0
    req = seq_item::type_id::create("req");
    start_item(req);
    req.a = 0;
    req.b = 1;
    req.y_expect = 0;  // Set expected output for scoreboard
    finish_item(req);
  
    // Test Case F004: A=1, B=0, Y=0
    req = seq_item::type_id::create("req");
    start_item(req);
    req.a = 1;
    req.b = 0;
    req.y_expect = 0;  // Set expected output for scoreboard
    finish_item(req);

    // Test Case F005: A=1, B=1, Y=1
    req = seq_item::type_id::create("req");
    start_item(req);
    req.a = 1;
    req.b = 1;
    req.y_expect = 1;  // Set expected output for scoreboard
    finish_item(req);
    
    // F001, F006, F007, F008, F009, F010:  Random Stimulus
    repeat (6) begin
      req = seq_item::type_id::create("req");
      start_item(req);

      // Customize stimulus generation here
      // Randomize A and B independently
      assert(req.randomize());
      req.y_expect = req.a & req.b; //calculate expected value

      finish_item(req);
    end

    `uvm_info("AND_GATE_SEQ", "Finished AND gate sequence", UVM_LOW)
  endtask
endclass

`endif
```