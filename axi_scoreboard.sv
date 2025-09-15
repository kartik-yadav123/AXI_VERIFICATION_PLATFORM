//========================================================================
// UPDATED AXI SCOREBOARD CLASS
// ========================================================================
import axi_pkg::*;
import axi_config_pkg::*;
import axi_logger_pkg::*; // Import the package to access the logger class

class axi_scoreboard;
    // Ports for observed and expected transactions
    mailbox #(axi_item) sb_export;        // From monitor (observed)
    mailbox #(axi_item) exp_export;      // From sequencer (expected)
    
    axi_item expected_queue[$];
    axi_item observed_queue[$];
    
    // Configuration and logger
    axi_config cfg;
    axi_logger_pkg::axi_logger logger;
    
    // Statistics
    int transactions_compared;
    int transactions_passed;
    int transactions_failed;
    int expected_transactions;
    int observed_transactions;
    
    // Analysis queues for out-of-order handling
    axi_item pending_reads[$];
    axi_item pending_writes[$];
    
    // Helper function to convert transaction type enum to string
    function string trans_type_to_string(axi_trans_type_t trans_type);
        case (trans_type)
            AXI_READ:   return "READ";
            AXI_WRITE:   return "WRITE";
            default:     return "UNKNOWN";
        endcase
    endfunction
    
    // Helper function to convert burst type enum to string
  function string burst_to_string(axi_burst_t burst);
    case (burst)
        FIXED:    return "FIXED";
        INCR:     return "INCR";
        WRAP:     return "WRAP";
        default:  return "UNKNOWN";
    endcase
endfunction

    
    // Helper function to convert size enum to string
    function string size_to_string(axi_size_t size);
        case (size)
            SIZE_1B:    return "1B";
            SIZE_2B:    return "2B";
            SIZE_4B:    return "4B";
            SIZE_8B:    return "8B";
            SIZE_16B:   return "16B";
            SIZE_32B:   return "32B";
            SIZE_64B:   return "64B";
            SIZE_128B:  return "128B";
            default:    return "UNKNOWN";
        endcase
    endfunction
    
    // Helper function to convert response enum to string
    function string resp_to_string(axi_resp_t resp);
        case (resp)
            OKAY:       return "OKAY";
            EXOKAY:     return "EXOKAY";
            SLVERR:     return "SLVERR";
            DECERR:     return "DECERR";
            default:    return "UNKNOWN";
        endcase
    endfunction
    
    function new(string name, axi_config cfg_h);
        sb_export = new();
        exp_export = new();
        this.cfg = cfg_h;
        
        transactions_compared = 0;
        transactions_passed = 0;
        transactions_failed = 0;
        expected_transactions = 0;
        observed_transactions = 0;
    endfunction
    
    function void set_logger(axi_logger_pkg::axi_logger log);
        logger = log;
    endfunction
    
    function void build();
        if (logger != null) begin
            logger.log_transaction(logger.INFO, "Scoreboard build phase completed");
        end
    endfunction
    
    task run();
        fork
            // Collect expected transactions
            forever begin
                axi_item exp_item;
                exp_export.get(exp_item);
                add_expected(exp_item);
            end
            
            // Collect observed transactions and compare
            forever begin
                axi_item obs_item;
                sb_export.get(obs_item);
                compare_transaction(obs_item);
            end
        join
    endtask
    
    function void compare_transaction(axi_item observed);
        axi_item expected;
        bit found = 0;
        int queue_index = -1;
        
        transactions_compared++;
        observed_transactions++;


        if (logger != null) begin
    logger.log_transaction(
        logger.DEBUG, 
        $sformatf("Comparing transaction: ID=%0h, ADDR=%0h, TYPE=%s", 
                  observed.id, observed.addr, string'(trans_type_to_string(observed.trans_type)))
    );
end

        
        // Match expected transaction
        for (int i = 0; i < expected_queue.size(); i++) begin
            if (matches_transaction(expected_queue[i], observed)) begin
                expected = expected_queue[i];
                queue_index = i;
                found = 1;
                break;
            end
        end
        
        if (!found) begin
            $error("No expected transaction found for observed: ID=%0h, ADDR=0x%08x, TYPE=%s", 
                    observed.id, observed.addr, trans_type_to_string(axi_trans_type_t'(observed.trans_type)));
            transactions_failed++;
            
            if (logger != null) begin
                logger.log_transaction(logger.ERROR, 
                    $sformatf("Unmatched transaction: %s", observed.convert2string()));
            end
            return;
        end
        
        // Remove matched expected transaction
        expected_queue.delete(queue_index);
        
        // Compare transaction fields
        if (!compare_items(expected, observed)) begin
            transactions_failed++;
            $error("Transaction comparison failed");
            $display("EXPECTED: %s", expected.convert2string());
            $display("OBSERVED: %s", observed.convert2string());
            
            if (logger != null) begin
                logger.log_transaction(logger.ERROR, 
                    $sformatf("Transaction mismatch - Expected: %s", expected.convert2string()));
                logger.log_transaction(logger.ERROR, 
                    $sformatf("Transaction mismatch - Observed: %s", observed.convert2string()));
            end
        end else begin
            transactions_passed++;
            $display("Transaction passed: ID=%0h, ADDR=0x%08x, TYPE=%s", 
                    observed.id, observed.addr, trans_type_to_string(axi_trans_type_t'(observed.trans_type)));
            
            if (logger != null) begin
                logger.log_transaction(logger.INFO, 
                    $sformatf("Transaction passed: ID=%0h", observed.id));
            end
        end
    endfunction
    
    function bit matches_transaction(axi_item expected, axi_item observed);
        if (expected.id != observed.id) return 0;
        if (expected.addr != observed.addr) return 0;
        if (expected.trans_type != observed.trans_type) return 0;
        return 1;
    endfunction
    
    function bit compare_items(axi_item expected, axi_item observed);
        bit result = 1;
        
        if (expected.trans_type != observed.trans_type) begin
            $error("Transaction type mismatch: exp=%s, obs=%s",
                trans_type_to_string(axi_trans_type_t'(expected.trans_type)), trans_type_to_string(axi_trans_type_t'(observed.trans_type)));
            result = 0;
        end
        
        if (expected.len != observed.len) begin
            $error("Burst length mismatch: exp=%0d, obs=%0d", 
                expected.len, observed.len);
            result = 0;
        end
        
        if (expected.size != observed.size) begin
            $error("Burst size mismatch: exp=%s, obs=%s",
                size_to_string(axi_size_t'(expected.size)), size_to_string(axi_size_t'(observed.size)));
            result = 0;
        end
        
        if (expected.burst != observed.burst) begin
            $error("Burst type mismatch: exp=%s, obs=%s",
                burst_to_string(axi_burst_t'(expected.burst)), burst_to_string(axi_burst_t'(observed.burst)));
            result = 0;
        end
        
        if (!check_address_alignment(observed.addr, axi_size_t'(observed.size))) begin
            $error("Address alignment violation: addr=0x%08x, size=%s", 
                    observed.addr, size_to_string(axi_size_t'(observed.size)));
            result = 0;
        end
        
        if (expected.trans_type == AXI_WRITE && expected.data.size() > 0) begin
            for (int i = 0; i < expected.data.size(); i++) begin
                logic [AXI_DATA_WIDTH/8-1:0] active_strb = expected.strb[i] & observed.strb[i];
                
                for (int byte_idx = 0; byte_idx < AXI_DATA_WIDTH/8; byte_idx++) begin
                    if (active_strb[byte_idx]) begin
                        logic [7:0] exp_byte = expected.data[i][byte_idx*8 +: 8];
                        logic [7:0] obs_byte = observed.data[i][byte_idx*8 +: 8];
                        
                        if (exp_byte !== obs_byte) begin
                            $error("Write data mismatch at beat %0d, byte %0d: exp=0x%02x, obs=0x%02x",
                                    i, byte_idx, exp_byte, obs_byte);
                            result = 0;
                        end
                    end
                end
            end
        end
        
        if (expected.trans_type == AXI_READ && expected.read_data.size() > 0) begin
            for (int i = 0; i < expected.read_data.size(); i++) begin
                if (expected.read_data[i] !== observed.read_data[i]) begin
                    $error("Read data mismatch at beat %0d: exp=0x%08x, obs=0x%08x",
                            i, expected.read_data[i], observed.read_data[i]);
                    result = 0;
                end
            end
        end
        
        if (expected.resp != observed.resp) begin
            $error("Response mismatch: exp=%s, obs=%s", 
                    resp_to_string(axi_resp_t'(expected.resp)), resp_to_string(axi_resp_t'(observed.resp)));
            result = 0;
        end
        
        return result;
    endfunction
    
    function bit check_address_alignment(logic [AXI_ADDR_WIDTH-1:0] addr, axi_size_t size);
        case (size)
            SIZE_1B:    return 1;
            SIZE_2B:    return (addr[0] == 0);
            SIZE_4B:    return (addr[1:0] == 0);
            SIZE_8B:    return (addr[2:0] == 0);
            SIZE_16B:   return (addr[3:0] == 0);
            SIZE_32B:   return (addr[4:0] == 0);
            SIZE_64B:   return (addr[5:0] == 0);
            SIZE_128B:  return (addr[6:0] == 0);
            default: return 0;
        endcase
    endfunction
    
    function void add_expected(axi_item item);
        axi_item cloned_item;
        
        cloned_item = new();
        cloned_item.copy(item);
        
        expected_queue.push_back(cloned_item);
        expected_transactions++;
        
        if (logger != null) begin
            logger.log_transaction(logger.DEBUG, 
                $sformatf("Added expected transaction: ID=%0h, ADDR=%0h", 
                item.id, item.addr));
        end
    endfunction
    
    function void print_report();
        $display("==========================================");
        $display("AXI SCOREBOARD REPORT");
        $display("==========================================");
        $display("Expected transactions:     %0d", expected_transactions);
        $display("Observed transactions:     %0d", observed_transactions);
        $display("Transactions compared:     %0d", transactions_compared);
        $display("Transactions passed:       %0d", transactions_passed);
        $display("Transactions failed:       %0d", transactions_failed);
        
        if (transactions_compared > 0) begin
            $display("Pass Rate: %.2f%%", (transactions_passed * 100.0) / transactions_compared);
        end else begin
            $display("Pass Rate: N/A (no transactions compared)");
        end
        
        if (expected_queue.size() > 0) begin
            $warning("%0d expected transactions were not observed:", expected_queue.size());
            foreach (expected_queue[i]) begin
                $display("  Missing: %s", expected_queue[i].convert2string());
            end
        end
        
        if (transactions_failed > 0) begin
            $error("TEST FAILED - %0d transaction mismatches detected", transactions_failed);
        end else if (expected_queue.size() > 0) begin
            $error("TEST FAILED - %0d expected transactions not observed", expected_queue.size());
        end else begin
            $display("*** TEST PASSED! ***");
        end
        
        $display("==========================================");
        
        if (logger != null) begin
            logger.log_transaction(logger.INFO, 
                $sformatf("Scoreboard final: %0d/%0d passed", transactions_passed, transactions_compared));
        end
    endfunction
    
    function int get_pass_count();
        return transactions_passed;
    endfunction
    
    function int get_fail_count();
        return transactions_failed;
    endfunction
    
    function int get_pending_expected();
        return expected_queue.size();
    endfunction
    
    function bit is_complete();
        return (expected_queue.size() == 0) && (transactions_compared > 0);
    endfunction
endclass

