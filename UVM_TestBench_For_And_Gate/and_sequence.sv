```systemverilog
class and_sequence extends uvm_sequence #(and_sequence_item);

  `uvm_object_utils(and_sequence)

  function new(string name = "and_sequence");
    super.new(name);
  endfunction

  task body();
    and_sequence_item req = and_sequence_item::type_id::create("req");

    // F001: Logical AND Operation
    `uvm_info("and_sequence", "Executing F001 sequence: Logical AND Operation", UVM_MEDIUM)
    repeat (4) begin
      assert(req.randomize());
      req.Y = req.A & req.B;
      `uvm_info("and_sequence", $sformatf("Driving A=%b, B=%b, Expected Y=%b", req.A, req.B, req.Y), UVM_HIGH)
      req.print();
      seq_item_port.put(req);
    end

    // F002: A=0, B=0 -> Y=0
    `uvm_info("and_sequence", "Executing F002 sequence: A=0, B=0 -> Y=0", UVM_MEDIUM)
    req = and_sequence_item::type_id::create("req");
    req.A = 0;
    req.B = 0;
    req.Y = 0;
    `uvm_info("and_sequence", $sformatf("Driving A=%b, B=%b, Expected Y=%b", req.A, req.B, req.Y), UVM_HIGH)
    seq_item_port.put(req);

    // F003: Output Y is 0 when A=0 and B=1
    `uvm_info("and_sequence", "Executing F003 sequence: Output Y is 0 when A=0 and B=1", UVM_MEDIUM)
    req = and_sequence_item::type_id::create("req");
    req.A = 0;
    req.B = 1;
    req.Y = 0;
    `uvm_info("and_sequence", $sformatf("Driving A=%b, B=%b, Expected Y=%b", req.A, req.B, req.Y), UVM_HIGH)
    seq_item_port.put(req);

    // F004: Y is 0 when A=1 and B=0
    `uvm_info("and_sequence", "Executing F004 sequence: Y is 0 when A=1 and B=0", UVM_MEDIUM)
    req = and_sequence_item::type_id::create("req");
    req.A = 1;
    req.B = 0;
    req.Y = 0;
    `uvm_info("and_sequence", $sformatf("Driving A=%b, B=%b, Expected Y=%b", req.A, req.B, req.Y), UVM_HIGH)
    seq_item_port.put(req);

    // F005: Output Y is 1 when A=1 and B=1
    `uvm_info("and_sequence", "Executing F005 sequence: Output Y is 1 when A=1 and B=1", UVM_MEDIUM)
    req = and_sequence_item::type_id::create("req");
    req.A = 1;
    req.B = 1;
    req.Y = 1;
    `uvm_info("and_sequence", $sformatf("Driving A=%b, B=%b, Expected Y=%b", req.A, req.B, req.Y), UVM_HIGH)
    seq_item_port.put(req);

    // F006: Input signal A
    `uvm_info("and_sequence", "Executing F006 sequence: Input signal A", UVM_MEDIUM)
    repeat (4) begin
        req = and_sequence_item::type_id::create("req");
        assert(req.randomize() with {A inside {0, 1}; B inside {0, 1};});
        req.Y = req.A & req.B;
        `uvm_info("and_sequence", $sformatf("Driving A=%b, B=%b, Expected Y=%b", req.A, req.B, req.Y), UVM_HIGH);
        seq_item_port.put(req);
    end

    // F007: Input signal B
    `uvm_info("and_sequence", "Executing F007 sequence: Input signal B", UVM_MEDIUM)
     repeat (4) begin
        req = and_sequence_item::type_id::create("req");
        assert(req.randomize() with {A inside {0, 1}; B inside {0, 1};});
        req.Y = req.A & req.B;
        `uvm_info("and_sequence", $sformatf("Driving A=%b, B=%b, Expected Y=%b", req.A, req.B, req.Y), UVM_HIGH);
        seq_item_port.put(req);
    end

    // F008: AND Gate Functionality
    `uvm_info("and_sequence", "Executing F008 sequence: AND Gate Functionality", UVM_MEDIUM)
      repeat (4) begin
        req = and_sequence_item::type_id::create("req");
        assert(req.randomize());
        req.Y = req.A & req.B;
        `uvm_info("and_sequence", $sformatf("Driving A=%b, B=%b, Expected Y=%b", req.A, req.B, req.Y), UVM_HIGH);
        seq_item_port.put(req);
      end
  endtask

endclass
```