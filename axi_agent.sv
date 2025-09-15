package axi_agent_pkg;
    
    // Import required packages
    import axi_pkg::*;
    import axi_config_pkg::*;   // for axi_config
    import axi_logger_pkg::*;   // optional if you want to pass a logger
    
    // Include the separate files (you already have these)
    `include "axi_driver.sv"
    `include "axi_monitor.sv"
    `include "axi_sequencer.sv"
    
    class axi_agent;
        
        axi_driver    driver;
        axi_monitor   monitor;
        axi_sequencer sequencer;
        axi_config    cfg;
        mailbox #(axi_item) ap;
        bit is_active = 1;
        
        function new(string name = "axi_agent", bit is_active = 1);
            this.is_active = is_active;
            cfg = new();
            monitor = new("monitor");
            ap = monitor.ap;
            
            if (is_active) begin
                driver = new("driver", cfg);
                sequencer = new("sequencer");
                sequencer.set_config(cfg);
            end
        endfunction
        
        // ? FIXED: Accept master and monitor modports separately
        function void set_virtual_interface(axi_vif_t vif);
        monitor.set_virtual_interface(vif.monitor);   // Extract monitor modport
        if (is_active) begin
            driver.set_virtual_interface(vif.master); // Extract master modport
        end
    endfunction
        
        function void connect();
            if (is_active) begin
                driver.seq_item_port = sequencer.seq_item_export;
            end
        endfunction
        
        task run();
            if (is_active) begin
                fork
                    driver.run();
                    sequencer.run();
                join_none
            end
            fork
                monitor.run();
            join_none
        endtask
        
    endclass
endpackage : axi_agent_pkg
