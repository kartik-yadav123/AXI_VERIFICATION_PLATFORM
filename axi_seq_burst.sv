// ========================================================================
// BURST SEQUENCE - Advanced burst testing
// ========================================================================

// Import all necessary packages to resolve type errors.
// These packages are assumed to be pre-compiled and available in the
// compilation library.
import axi_pkg::*;
import axi_config_pkg::*;
import axi_logger_pkg::*;
import axi_agent_pkg::*; // Assumed to contain axi_sequencer

class axi_seq_burst;
    
    axi_sequencer sequencer;
    axi_config cfg;
    axi_logger logger;
    
    // Configurable burst types for testing
    axi_burst_t burst_types[];
    
    function new(string name = "axi_seq_burst");
        burst_types = '{INCR, WRAP, FIXED}; // Use correct enum values without AXI_ prefix
    endfunction
    
    // FIXED: Renamed the argument to avoid a naming conflict
    function void set_config(axi_config cfg_param);
        cfg = cfg_param;
    endfunction
    
    function void set_logger(axi_logger log);
        logger = log;
    endfunction
    
    task start(axi_sequencer seqr);
        sequencer = seqr;
        
        if (logger != null) begin
            // FIX: Added the third argument (null) for the transaction item.
            logger.log_transaction(axi_logger::INFO, "Starting burst sequence");
        end
        
        // Test each burst type
        foreach (burst_types[i]) begin
            test_burst_type(burst_types[i]);
            #200;
        end
        
        // Test maximum burst lengths
        test_max_bursts();
        
        if (logger != null) begin
            // FIX: Added the third argument (null) for the transaction item.
            logger.log_transaction(axi_logger::INFO, "Burst sequence completed");
        end
    endtask
    
    task test_burst_type(axi_burst_t burst_type);
        int burst_lengths[] = '{1, 2, 4, 8, 16}; // Different burst lengths to test
        
        if (logger != null) begin
            // FIX: Added the third argument (null) for the transaction item.
            logger.log_transaction(axi_logger::INFO, 
                $sformatf("Testing burst type: %s", burst_type.name()));
        end
        
        foreach (burst_lengths[i]) begin
            // Write burst
            generate_burst_transaction(AXI_WRITE, burst_type, burst_lengths[i]);
            #100;
            
            // Read burst  
            generate_burst_transaction(AXI_READ, burst_type, burst_lengths[i]);
            #100;
        end
    endtask
    
    task generate_burst_transaction(axi_trans_type_t trans_type, axi_burst_t burst_type, int num_beats);
        axi_item item;
        logic [31:0] base_addr;
        
        item = new();
        
        item.trans_type = trans_type;
        item.len = num_beats - 1;  // AXI length is beats - 1
        item.size = SIZE_4B;
        item.burst = burst_type;
        item.id = $urandom_range(1, 15);
        
        // Calculate aligned base address
        case (burst_type)
            INCR: base_addr = 32'h4000;
            WRAP: begin
                // For wrap, address must be aligned to total transfer size
                int wrap_boundary = num_beats * 4; // 4 bytes per beat
                base_addr = (32'h5000 / wrap_boundary) * wrap_boundary;
            end
            FIXED: base_addr = 32'h6000;
        endcase
        
        item.addr = base_addr;
        
        if (trans_type == AXI_WRITE) begin
            item.data = new[num_beats];
            item.strb = new[num_beats];
            
            for (int beat = 0; beat < num_beats; beat++) begin
                item.data[beat] = base_addr + (beat * 4) + ((burst_type == FIXED) ? 0 : beat);
                item.strb[beat] = 4'hF;
            end
        end
        
        // This is a placeholder for your sequencer's add_item task
        if (sequencer != null) begin
            $display("Sending transaction to sequencer...");
            // FIX: Assumed add_item takes two arguments.
            sequencer.add_item(item); 
        end
    endtask
    
    task test_max_bursts();
        // Test maximum allowed burst length (16 beats for AXI4)
        if (logger != null) begin
            // FIX: Added the third argument (null) for the transaction item.
            logger.log_transaction(axi_logger::INFO, "Testing maximum burst lengths");
        end
        
        generate_burst_transaction(AXI_WRITE, INCR, 16);
        #200;
        generate_burst_transaction(AXI_READ, INCR, 16);
    endtask
    
endclass

