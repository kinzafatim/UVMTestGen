```systemverilog
class and_test extends uvm_test;

  `uvm_component_utils(and_test)

  and_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = and_env::type_id::create("env", this);
    uvm_config_db #(uvm_active_passive_enum)::set(this, "env.agent", "is_active", UVM_ACTIVE);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    and_sequence seq = new();
    seq.start(env.agent.sequencer);
    #100ns; // Allow time for simulation to complete
    phase.drop_objection(this);
  endtask

endclass
```