```systemverilog
class and_coverage extends uvm_component;

  `uvm_component_utils(and_coverage)

  uvm_analysis_imp #(and_sequence_item, and_coverage) analysis_imp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_imp = new("analysis_imp", this);
  endfunction

  covergroup and_cg;
    A: coverpoint and_cg.A{
      bins low_range = {0};
      bins high_range = {1};
    };
    B: coverpoint and_cg.B{
      bins low_range = {0};
      bins high_range = {1};
    };
    Y: coverpoint and_cg.Y{
      bins low_range = {0};
      bins high_range = {1};
    };
    ab_cross: cross A,B;
  endgroup

  and_cg cg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cg = new();
  endfunction

  function void write(and_sequence_item item);
    cg.sample(item.A, item.B, item.Y);
  endfunction

endclass
```