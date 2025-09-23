`ifndef BASE_SEQ_SV
`define BASE_SEQ_SV

`include "uvm_macros.svh"
// `include "seq_item.sv"

class base_seq extends uvm_sequence #(seq_item);
  `uvm_object_utils(base_seq)

  function new(string name = "base_seq");
    super.new(name);
  endfunction

  // Sequence body: generate stimulus
  task body();
    seq_item req;

    `uvm_info("BASE_SEQ", "Starting base sequence", UVM_LOW)
    repeat (10) begin
      req = seq_item::type_id::create("req");
      start_item(req);

      // Customize stimulus generation here
      // Example: req.randomize();
      
      finish_item(req);
    end
  endtask
endclass

`endif
