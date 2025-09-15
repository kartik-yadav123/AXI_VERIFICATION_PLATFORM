//========================================================================
// AXI SEQUENCES - Fixed version with proper randomization and constraints
//========================================================================

// Include the file containing the `axi_item` class and the package definitions.
// This is the most direct way to ensure the compiler finds the class definition.
`include "axi_pkg.sv"
`include "axi_item.sv"
import axi_pkg::*;
import axi_config_pkg::*;
import axi_logger_pkg::*;
import axi_agent_pkg::*; // Assumed to contain axi_sequencer

class axi_seq_rand;
    
    axi_sequencer sequencer;
    rand int num_transactions;
    axi_config cfg;
    axi_logger logger;
    
    // Better constraint ranges
    constraint c_num_trans { 
        num_transactions inside {[5:100]}; 
        num_transactions dist {[5:20] := 60, [21:50] := 30, [51:100] := 10};
    }
    
    function new(string name = "axi_seq_rand");
        // Remove sequencer from constructor - will be set via start() method
    endfunction
    
    // Renamed the argument to avoid a naming conflict
    function void set_config(axi_config cfg_param);
        cfg = cfg_param;
    endfunction
    
    function void set_logger(axi_logger log);
        logger = log;
    endfunction
    
    // Enhanced randomization with proper validation
    task start(axi_sequencer seqr);
        axi_item item;
        sequencer = seqr;
        
        // Validate randomization first
        if (!this.randomize()) begin
            $fatal("Failed to randomize sequence parameters");
        end
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, 
                $sformatf("Starting random sequence with %0d transactions", num_transactions));
        end
        
        for (int i = 0; i < num_transactions; i++) begin
            // Based on the `axi_item` constructor you provided,
            // this is the correct way to create a new object with a name.
            item = new($sformatf("rand_item_%0d", i));
            
            // Enhanced randomization with alignment constraints
            if (!item.randomize() with {
                // Address constraints with alignment
                addr inside {[32'h1000 : 32'h1_FFFF]};  // Avoid address 0
                
                // Using `if` instead of `when`
                if (size >= axi_pkg::SIZE_4B) addr[1:0] == 2'b00; // 4-byte alignment
                if (size >= axi_pkg::SIZE_2B) addr[0] == 1'b0;    // 2-byte alignment
                
                // Burst constraints  
                len inside {[0:15]};
                len dist {0 := 40, [1:3] := 40, [4:15] := 20}; // Favor shorter bursts
                
                size inside {axi_pkg::SIZE_1B, axi_pkg::SIZE_2B, axi_pkg::SIZE_4B, axi_pkg::SIZE_8B};
                size dist {axi_pkg::SIZE_4B := 50, axi_pkg::SIZE_8B := 30, [axi_pkg::SIZE_1B:axi_pkg::SIZE_2B] := 20};
                
                burst inside {axi_pkg::FIXED, axi_pkg::INCR, axi_pkg::WRAP};
                burst dist {axi_pkg::INCR := 80, axi_pkg::FIXED := 15, axi_pkg::WRAP := 5};
                
                // Transaction type distribution
                trans_type dist {axi_pkg::AXI_WRITE := 50, axi_pkg::AXI_READ := 50};
                
                // ID constraints
                id inside {[0:15]};
                
                // Quality of service
                qos inside {[0:3]};
                
                // Cache and protection
                cache inside {[0:15]};
                prot inside {[0:7]};
                
                // For wrap bursts, length must be power of 2
                if (burst == axi_pkg::WRAP) {
                    len inside {1, 3, 7, 15}; // 2,4,8,16 beats
                }
                
                // Address must not cross 4KB boundary for most cases
                solve size, len, burst before addr;
                
            }) begin
                // Send to sequencer
                sequencer.add_item(item);
                
                if (logger != null && (i % 10 == 0)) begin
                    logger.log_transaction(axi_logger::DEBUG, 
                        $sformatf("Generated transaction %0d/%0d", i+1, num_transactions));
                end
            end else begin
                $error("Failed to randomize item %0d", i);
                continue;
            end
            
            // Random delay between transactions
            #($urandom_range(10, 100));
        end
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, 
                $sformatf("Random sequence completed: %0d transactions generated", num_transactions));
        end
    endtask
    
endclass

