// ========================================================================
// AXI Protocol Checker Class
// ========================================================================

`include "axi_config.sv"
`include "axi_pkg.sv"
`include "axi_logger.sv"

import axi_config_pkg::*;
import axi_pkg::*;
import axi_logger_pkg::*;  // Import the logger package

class axi_protocol_checker;
    axi_config cfg;
    axi_logger_pkg::axi_logger logger;  // Use the fully qualified class name
    
    // Outstanding transaction tracking
    int outstanding_writes = 0;
    int outstanding_reads = 0;
    
    // Transaction queues for ordering checks
    axi_item write_addr_queue[$];
    axi_item write_data_queue[$];
    axi_item read_addr_queue[$];
    
    function new(axi_config cfg_param, axi_logger_pkg::axi_logger log_param);
        cfg = cfg_param;
        logger = log_param;
    endfunction

    // Check AXI Write Address Channel
    function void check_write_addr(axi_item item);
        if (!cfg.enable_protocol_checks) return;
        
        // Check address alignment
        check_addr_alignment(item.addr, item.size);
        
        // Check burst type
        check_burst_type(item.burst);
        
        // Check burst length
        check_burst_length(item.len, item.burst);
        
        // Check outstanding transactions
        if (outstanding_writes >= cfg.max_outstanding) begin
            logger.log_transaction(axi_logger_pkg::axi_logger::ERROR, 
                $sformatf("Too many outstanding writes: %0d", outstanding_writes));
        end
        
        outstanding_writes++;
        write_addr_queue.push_back(item);
        
        logger.log_transaction(axi_logger_pkg::axi_logger::PROTOCOL, 
            $sformatf("Write Address: ADDR=0x%08x, LEN=%0d, SIZE=%0d", 
                     item.addr, item.len, item.size));
    endfunction
    
    // Check AXI Write Data Channel
    function void check_write_data(axi_item item);
        if (!cfg.enable_protocol_checks) return;
        
        // Check strobe alignment - Fixed: handle different strb types
        if (item.strb.size() > 0) begin
            bit [31:0] strb_packed = 0;
            for (int i = 0; i < item.strb.size() && i < 32; i++) begin
                strb_packed[i] = item.strb[i];
            end
            check_strobe_alignment(strb_packed[3:0], item.size);
        end
        
        write_data_queue.push_back(item);
    endfunction
    
    // Check AXI Write Response Channel
    function void check_write_response(axi_item item);
        if (!cfg.enable_protocol_checks) return;
        
        if (outstanding_writes <= 0) begin
            logger.log_transaction(axi_logger_pkg::axi_logger::ERROR, 
                "Write response without outstanding write");
        end else begin
            outstanding_writes--;
        end
        
        // Check response
        check_response(item.resp);
        
        logger.log_transaction(axi_logger_pkg::axi_logger::PROTOCOL, 
            $sformatf("Write Response: ID=%0d, RESP=%0d", item.id, item.resp));
    endfunction
    
    // Check AXI Read Address Channel
    function void check_read_addr(axi_item item);
        if (!cfg.enable_protocol_checks) return;
        
        check_addr_alignment(item.addr, item.size);
        check_burst_type(item.burst);
        check_burst_length(item.len, item.burst);
        
        if (outstanding_reads >= cfg.max_outstanding) begin
            logger.log_transaction(axi_logger_pkg::axi_logger::ERROR, 
                $sformatf("Too many outstanding reads: %0d", outstanding_reads));
        end
        
        outstanding_reads++;
        read_addr_queue.push_back(item);
        
        logger.log_transaction(axi_logger_pkg::axi_logger::PROTOCOL, 
            $sformatf("Read Address: ADDR=0x%08x, LEN=%0d, SIZE=%0d", 
                     item.addr, item.len, item.size));
    endfunction
    
    // Check AXI Read Data Channel
    function void check_read_data(axi_item item);
        if (!cfg.enable_protocol_checks) return;
        
        if (outstanding_reads <= 0) begin
            logger.log_transaction(axi_logger_pkg::axi_logger::ERROR, 
                "Read data without outstanding read");
        end
        
        check_response(item.resp);
        
        // Handle burst completion - check if this is the last beat
        // For read bursts, we need to track based on len field from addr phase
        // For now, decrement on each data beat (simplified approach)
        outstanding_reads--;
        
        logger.log_transaction(axi_logger_pkg::axi_logger::PROTOCOL, 
            $sformatf("Read Data: ID=%0d, DATA=0x%08x", 
                     item.id, (item.read_data.size() > 0 ? item.read_data[0] : item.data.size() > 0 ? item.data[0] : 0)));
    endfunction
    
    // Helper functions
    function void check_addr_alignment(bit [31:0] addr, bit [2:0] size);
        int bytes = 1 << size;
        if (addr % bytes != 0) begin
            logger.log_transaction(axi_logger_pkg::axi_logger::ERROR, 
                $sformatf("Address misaligned: ADDR=0x%08x, SIZE=%0d", addr, size));
        end
    endfunction
    
    function void check_burst_type(bit [1:0] burst);
        if (burst == 2'b11) begin // Reserved
            logger.log_transaction(axi_logger_pkg::axi_logger::ERROR, "Reserved burst type used");
        end
    endfunction
    
    function void check_burst_length(bit [7:0] len, bit [1:0] burst);
        if (burst == 2'b10 && len != 8'h01 && len != 8'h03 && 
            len != 8'h07 && len != 8'h0F) begin // WRAP burst
            logger.log_transaction(axi_logger_pkg::axi_logger::ERROR, 
                $sformatf("Invalid WRAP burst length: %0d", len + 1));
        end
        
        if (len > 8'h0F) begin // Max 16 transfers
            logger.log_transaction(axi_logger_pkg::axi_logger::ERROR, 
                $sformatf("Burst length too long: %0d", len + 1));
        end
    endfunction
    
    function void check_strobe_alignment(bit [3:0] strb, bit [2:0] size);
        // Check that strobe is contiguous and aligned
        bit found_gap = 0;
        bit found_after_gap = 0;
        
        for (int i = 0; i < 4; i++) begin
            if (!strb[i]) begin
                found_gap = 1;
            end else if (found_gap) begin
                found_after_gap = 1;
            end
        end
        
        if (found_after_gap) begin
            logger.log_transaction(axi_logger_pkg::axi_logger::WARNING, 
                $sformatf("Non-contiguous strobe: 0x%x", strb));
        end
    endfunction
    
    function void check_response(bit [1:0] resp);
        if (resp == 2'b01) begin // EXOKAY
            logger.log_transaction(axi_logger_pkg::axi_logger::INFO, "Exclusive access successful");
        end else if (resp == 2'b10) begin // SLVERR
            logger.log_transaction(axi_logger_pkg::axi_logger::WARNING, "Slave error response");
        end else if (resp == 2'b11) begin // DECERR
            logger.log_transaction(axi_logger_pkg::axi_logger::WARNING, "Decode error response");
        end
    endfunction
    
    function void print_statistics();
        logger.log_transaction(axi_logger_pkg::axi_logger::INFO, "=== Protocol Checker Statistics ===");
        logger.log_transaction(axi_logger_pkg::axi_logger::INFO, 
            $sformatf("Outstanding Writes: %0d", outstanding_writes));
        logger.log_transaction(axi_logger_pkg::axi_logger::INFO, 
            $sformatf("Outstanding Reads: %0d", outstanding_reads));
        logger.log_transaction(axi_logger_pkg::axi_logger::INFO, 
            $sformatf("Write Addr Queue Size: %0d", write_addr_queue.size()));
        logger.log_transaction(axi_logger_pkg::axi_logger::INFO, 
            $sformatf("Read Addr Queue Size: %0d", read_addr_queue.size()));
        logger.log_transaction(axi_logger_pkg::axi_logger::INFO, "==================================");
    endfunction
endclass
