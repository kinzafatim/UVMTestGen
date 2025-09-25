```systemverilog
class and_sequence_item extends uvm_sequence_item;
  rand bit A;
  rand bit B;
  bit Y;

  `uvm_object_utils_begin(and_sequence_item)
    `uvm_field_int(A, UVM_ALL_ON)
    `uvm_field_int(B, UVM_ALL_ON)
    `uvm_field_int(Y, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "and_sequence_item");
    super.new(name);
  endfunction

endclass
```