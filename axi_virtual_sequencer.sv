// ========================================================================
// AXI Virtual Sequencer Class - Fixed version
// ========================================================================

import axi_pkg::*;
import axi_config_pkg::*;
import axi_logger_pkg::*;
import axi_agent_pkg::*; // Must contain axi_sequencer

// Include the axi_seq_rand class file
`include "axi_seq_rand.sv"

class axi_virtual_sequencer;
    axi_sequencer master_seqr[];
    axi_sequencer slave_seqr[];
    axi_config cfg;
    axi_logger logger;
    
    int num_masters = 1;
    int num_slaves = 1;
    
    function new(int masters = 1, int slaves = 1, axi_config cfg_param = null);
        num_masters = masters;
        num_slaves = slaves;
        cfg = cfg_param;
        
        // Create sequencer arrays
        master_seqr = new[num_masters];
        slave_seqr = new[num_slaves];
        
        // Initialize sequencers
        for (int i = 0; i < num_masters; i++) begin
            master_seqr[i] = new();
        end
        
        for (int i = 0; i < num_slaves; i++) begin
            slave_seqr[i] = new();
        end
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, 
                $sformatf("Virtual Sequencer created: %0d masters, %0d slaves", 
                         num_masters, num_slaves));
        end
    endfunction
    
    // Coordinate sequences across multiple interfaces
    task run_coordinated_sequence();
        fork
            // Start sequences on all master interfaces
            for (int i = 0; i < num_masters; i++) begin
                fork
                    automatic int master_id = i;
                    run_master_sequence(master_id);
                join_none
            end
            
            // Start sequences on all slave interfaces
            for (int i = 0; i < num_slaves; i++) begin
                fork
                    automatic int slave_id = i;
                    run_slave_sequence(slave_id);
                join_none
            end
        join
    endtask
    
    task run_master_sequence(int master_id);
        axi_seq_rand rand_seq; // Move declaration here where it's used
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, 
                $sformatf("Starting sequence on master %0d", master_id));
        end
        
        rand_seq = new();
        rand_seq.start(master_seqr[master_id]);
    endtask
    
    task run_slave_sequence(int slave_id);
        // Slave sequences would be response-based
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, 
                $sformatf("Starting slave response on slave %0d", slave_id));
        end
        
        // Implement slave response logic here
    endtask
    
    // Synchronization between interfaces
    task sync_all_interfaces();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Synchronizing all interfaces");
        end
        
        // Wait for all outstanding transactions
        fork
            for (int i = 0; i < num_masters; i++) begin
                wait_for_master_idle(i);
            end
        join
    endtask
    
    task wait_for_master_idle(int master_id);
        // Wait for specific master to be idle
        // Implementation depends on your sequencer design
        #1000; // Placeholder
    endtask
    
    function void set_logger(axi_logger log);
        logger = log;
    endfunction
    
    function void print_status();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "=== Virtual Sequencer Status ===");
            logger.log_transaction(axi_logger::INFO, 
                $sformatf("Masters: %0d, Slaves: %0d", num_masters, num_slaves));
            logger.log_transaction(axi_logger::INFO, "===============================");
        end
    endfunction
endclass
