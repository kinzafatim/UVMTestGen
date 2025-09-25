```systemverilog
class and_scoreboard extends uvm_scoreboard #(and_sequence_item);

  `uvm_component_utils(and_scoreboard)

  uvm_analysis_imp #(and_sequence_item, and_scoreboard) analysis_imp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_imp = new("analysis_imp", this);
  endfunction

  function void write(and_sequence_item item);
    `uvm_info("and_scoreboard", $sformatf("Scoreboard received: A=%b, B=%b, Y=%b", item.A, item.B, item.Y), UVM_HIGH)
    bit expected_Y = item.A & item.B;
    if (item.Y != expected_Y) begin
      `uvm_error("and_scoreboard", $sformatf("Mismatch! A=%b, B=%b, Expected Y=%b, Actual Y=%b", item.A, item.B, expected_Y, item.Y))
    end else begin
      `uvm_info("and_scoreboard", "Match!", UVM_HIGH)
    end

    //F009 assertion check for zero delay
    time input_change_time;
    input_change_time = $time;
    -> zero_delay_check;
  endfunction

  task run_phase(uvm_phase phase);
    fork
      begin
        event zero_delay_check;
        @(zero_delay_check);
        if($time - input_change_time > 1)
          `uvm_error("and_scoreboard", "non zero delay");
      end
    join_none
  endtask

endclass
```