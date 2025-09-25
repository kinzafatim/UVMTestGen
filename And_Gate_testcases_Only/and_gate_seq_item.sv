```systemverilog
`ifndef AND_GATE_SEQ_ITEM_SV
`define AND_GATE_SEQ_ITEM_SV

`include "uvm_macros.svh"

class and_gate_seq_item extends uvm_sequence_item;
  `uvm_object_utils(and_gate_seq_item)

  // Define transaction variables
  rand bit A;
  rand bit B;
  bit Y;  // Observed output, not randomized

  function new(string name = "and_gate_seq_item");
    super.new(name);
  endfunction

  // Optional constraints
  constraint valid_A { A inside {0,1}; }
  constraint valid_B { B inside {0,1}; }


  function string convert2string();
    return $sformatf("A=%0b B=%0b Y=%0b", A, B, Y);
  endfunction
endclass

`endif
```