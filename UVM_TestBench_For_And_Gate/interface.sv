```systemverilog
interface and_if;
  logic A;
  logic B;
  logic Y;

  clocking cb @(posedge clk);
    input A, B, Y;
  endclocking

  logic clk;
endinterface
```