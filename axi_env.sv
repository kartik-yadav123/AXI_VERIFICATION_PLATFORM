`include "axi_scoreboard.sv"
`include "axi_protocol_checker.sv"

import axi_pkg::*;
import axi_logger_pkg::*;
import axi_config_pkg::*;
import axi_agent_pkg::*;
import axi_coverage_pkg::*;

class axi_env;
    // Core verification components
    axi_agent agent;
    axi_scoreboard sb;
    axi_coverage cov;
    axi_logger logger;
    axi_protocol_checker protocol_checker;
    
    // Configuration object
    axi_config cfg;
    
    // ? FIXED: Store base interface (no modport)
    axi_vif_t base_vif;
    
    // Internal state variables
    bit env_ready;
    bit connections_made;
    int transaction_count;
    
    // Constructor
    function new(axi_config cfg_param = null);
        env_ready = 1'b0;
        connections_made = 1'b0;
        transaction_count = 0;
        
        if (cfg_param == null) begin
            cfg = new();
        end else begin
            cfg = cfg_param;
        end
        
        if (cfg.enable_logging) begin
            logger = new("axi_verification.log", cfg);
            logger.log_transaction(axi_logger::INFO, "AXI Environment initialized");
        end
        
        agent = new("axi_agent", 1);
        
        if (cfg.enable_scoreboard) begin
            sb = new("axi_scoreboard", cfg);
            if (logger != null) sb.set_logger(logger);
        end
        
        if (cfg.enable_coverage) begin
            cov = new("axi_coverage");
        end
        
        if (cfg.enable_protocol_checks) begin
            protocol_checker = new(cfg, logger);
        end
        
        if (logger != null) begin
            cfg.print_config();
        end
        
        env_ready = 1'b1;
    endfunction
    
    // ? FIXED: Accept master modport from testbench, store as base interface
    function void set_virtual_interface(axi_vif_master_t vif);
        // Cast to base interface type
        this.base_vif = vif;
        
        if (agent != null) begin
            // Pass base interface - agent will extract modports
            agent.set_virtual_interface(base_vif);
        end
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Virtual interface connected to environment");
        end
    endfunction
    
    // Build phase
    function void build();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Building AXI Environment");
        end
        
        if (agent != null) begin
            if (agent.cfg != null) agent.cfg = cfg;
        end
        if (sb != null) sb.build();
        
        // Connect components after building
        connect_components();
    endfunction
    
    // ? FIXED: Simplified component connections
    function void connect_components();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Component connections completed");
        end
        // Individual component connections handled in their respective classes
    endfunction
    
    // Connect phase
    function void connect();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Connecting AXI Environment");
        end
        
        // Agent internal connections
        if (agent != null) begin
            agent.connect();
        end
        
        connections_made = 1'b1;
    endfunction
    
    // Main run task
    task run();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Starting AXI Environment");
        end
        
        fork
            if (agent != null) agent.run();
            if (sb != null) sb.run();
            if (cov != null) cov.run();
            // Protocol checker run() depends on your implementation
        join_none
    endtask
    
    // Final report function  
    function void final_report();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "=== AXI Environment Final Report ===");
            
            if (protocol_checker != null) protocol_checker.print_statistics();
            if (sb != null) sb.print_report();
            if (cov != null) cov.report();
            
            logger.log_transaction(axi_logger::INFO, "========================================");
            logger.close_log();
        end else begin
            $display("=== AXI Environment Final Report ===");
            if (protocol_checker != null) protocol_checker.print_statistics();
            if (sb != null) sb.print_report();
            if (cov != null) cov.report();
            $display("Environment completed successfully");
            $display("====================================");
        end
    endfunction
    
    // Configuration methods
    function void set_config(axi_config cfg_param);
        if (cfg_param == null) begin
            if (logger != null) begin
                logger.log_transaction(axi_logger::ERROR, "Cannot set null configuration");
            end
            return;
        end
        
        cfg = cfg_param;
        
        if (agent != null && agent.cfg != null) begin
            agent.cfg = cfg;
        end
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Configuration updated and propagated to components");
            cfg.print_config();
        end
    endfunction
    
    function axi_config get_config();
        return cfg;
    endfunction
    
    function axi_logger get_logger();
        return logger;
    endfunction
    
    function axi_protocol_checker get_protocol_checker();
        return protocol_checker;
    endfunction
    
    // Utility functions
    function bit is_environment_ready();
        return env_ready && connections_made;
    endfunction
    
    function int get_transaction_count();
        return transaction_count;
    endfunction
    
    function void increment_transaction_count();
        transaction_count++;
    endfunction
    
    function void reset_environment();
        transaction_count = 0;
        env_ready = 1'b0;
        connections_made = 1'b0;
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Environment reset completed");
        end
    endfunction
    
    // Wait for transactions task
    task wait_for_transactions(int num_transactions, int timeout_cycles = 10000);
        int start_time;
        int timeout_time;
        
        start_time = $time;
        timeout_time = start_time + timeout_cycles;
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO,
                $sformatf("Waiting for %0d transactions (timeout: %0d cycles)", num_transactions, timeout_cycles));
        end
        
        while (transaction_count < num_transactions && $time < timeout_time) begin
            #10;
        end
        
        if (transaction_count >= num_transactions) begin
            if (logger != null) begin
                logger.log_transaction(axi_logger::INFO,
                    $sformatf("Transaction target reached: %0d transactions completed", transaction_count));
            end
        end else begin
            if (logger != null) begin
                logger.log_transaction(axi_logger::WARNING,
                    $sformatf("Transaction wait timed out: %0d/%0d completed", transaction_count, num_transactions));
            end
        end
    endtask
endclass
