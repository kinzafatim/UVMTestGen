```systemverilog
module testbench;
  import uvm_pkg::*;
  import tb_pkg::*;

  and_if intf();

  and_gate dut(
    .A (intf.A),
    .B (intf.B),
    .Y (intf.Y)
  );

  initial begin
    intf.clk = 0;
    forever #5ns intf.clk = ~intf.clk;
  end

  initial begin
    uvm_config_db #(virtual interface and_if)::set(null, "uvm_test_top.env.agent.driver", "vif", intf);
    uvm_config_db #(virtual interface and_if)::set(null, "uvm_test_top.env.agent.monitor", "vif", intf);
    run_test("and_test");
  end

endmodule
```