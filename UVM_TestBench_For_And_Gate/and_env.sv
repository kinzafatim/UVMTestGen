```systemverilog
class and_env extends uvm_env;

  `uvm_component_utils(and_env)

  and_agent agent;
  and_scoreboard scoreboard;
  and_coverage coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = and_agent::type_id::create("agent", this);
    scoreboard = and_scoreboard::type_id::create("scoreboard", this);
    coverage = and_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.analysis_port.connect(scoreboard.analysis_imp);
    agent.monitor.analysis_port.connect(coverage.analysis_imp);
  endfunction

endclass
```