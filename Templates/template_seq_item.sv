`ifndef SEQ_ITEM_SV
`define SEQ_ITEM_SV

`include "uvm_macros.svh"

class seq_item extends uvm_sequence_item;
  `uvm_object_utils(seq_item)

  // Define transaction variables
  rand bit [7:0] data;
  rand bit valid;

  function new(string name = "seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint c_valid { valid == 1; }

  function string convert2string();
    return $sformatf("data=%0d valid=%0b", data, valid);
  endfunction
endclass

`endif
