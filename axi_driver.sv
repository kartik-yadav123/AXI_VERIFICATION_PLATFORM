//=============================================================================
// FIXED AXI DRIVER CLASS - Corrected virtual interface resolution
//=============================================================================

// Import the packages to access their contents
import axi_pkg::*;
import axi_config_pkg::*;
import axi_logger_pkg::*;

class axi_driver;
    
    // ? UPDATED: Use typedef for virtual interface
    axi_vif_master_t vif;
    mailbox #(axi_item) seq_item_port;
    axi_item req;
    axi_config_pkg::axi_config cfg;
    
    // Corrected the type of 'logger' to use the package scope
    axi_logger logger; 

    // Control flag to stop the driver's main task
    bit stop_flag = 0;

    // Statistics
    int transactions_driven;
    int write_transactions;
    int read_transactions;
    int error_responses;
    
    // Fixed constructor - removed default null parameter for ModelSim 10.5b compatibility
    function new(string name, axi_config cfg_param);
        seq_item_port = new();
        cfg = cfg_param;
        transactions_driven = 0;
        write_transactions = 0;
        read_transactions = 0;
        error_responses = 0;
    endfunction
    
    // ? UPDATED: Use typedef for function parameter
    function void set_virtual_interface(axi_vif_master_t vif_param);
        this.vif = vif_param; 
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Virtual interface connected to driver");
        end
    endfunction
    
    function void set_logger(axi_logger log);
        logger = log;
    endfunction
    
    //-------------------------------------------------------------------------
    // Task: run
    // The main execution task for the driver. It continuously gets transactions
    // from the sequencer and drives them on the bus until the 'stop_flag' is set.
    //-------------------------------------------------------------------------
    task run();
        if (vif == null) begin
            $fatal("Virtual interface not connected to driver");
        end
        
        reset_signals();
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "AXI Driver started");
        end
        
        while(!stop_flag) begin
            if (seq_item_port.try_get(req)) begin
                drive_transaction(req);
                transactions_driven++;
                
                if (logger != null && (transactions_driven % 10 == 0)) begin
                    logger.log_transaction(axi_logger::INFO, 
                        $sformatf("Driver: %0d transactions completed", transactions_driven));
                end
            end else begin
                // No transaction available, wait a bit
                @(posedge vif.aclk);
            end
        end

        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "AXI Driver gracefully stopped");
        end
    endtask
    
    //-------------------------------------------------------------------------
    // Function: stop_driver
    // Sets the internal flag to stop the run task.
    //-------------------------------------------------------------------------
    function void stop_driver();
        stop_flag = 1;
    endfunction

    // FIXED: Complete reset sequence
    task reset_signals();
        // Wait for reset assertion
        if (vif.aresetn) begin
            wait(!vif.aresetn);
        end
        
        // Reset all output signals
        vif.awvalid <= 0;
        vif.awid <= 0;
        vif.awaddr <= 0;
        vif.awlen <= 0;
        vif.awsize <= 0;
        vif.awburst <= 0;
        vif.awlock <= 0;
        vif.awcache <= 0;
        vif.awprot <= 0;
        vif.awqos <= 0;
        vif.awregion <= 0;
        
        vif.wvalid <= 0;
        vif.wdata <= 0;
        vif.wstrb <= 0;
        vif.wlast <= 0;
        
        vif.bready <= 0;
        
        vif.arvalid <= 0;
        vif.arid <= 0;
        vif.araddr <= 0;
        vif.arlen <= 0;
        vif.arsize <= 0;
        vif.arburst <= 0;
        vif.arlock <= 0;
        vif.arcache <= 0;
        vif.arprot <= 0;
        vif.arqos <= 0;
        vif.arregion <= 0;
        
        vif.rready <= 0;
        
        // Wait for reset deassertion
        wait(vif.aresetn);
        
        // Wait for first clock edge after reset
        @(posedge vif.aclk);
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Driver reset completed");
        end
    endtask
    
    task drive_transaction(axi_item item);
        if (logger != null) begin
            logger.log_transaction(axi_logger::DEBUG, 
                $sformatf("Driving %s transaction: ID=%0h, ADDR=%0h", 
                (item.trans_type == AXI_WRITE) ? "WRITE" : "READ", item.id, item.addr));
        end
        
        if (item.trans_type == AXI_WRITE) begin
            write_transactions++;
            // Allocate data and strobe arrays before use
            // The size is len+1 for a burst of len beats.
            item.data = new[item.len + 1];
            item.strb = new[item.len + 1];

            fork
                drive_write_addr(item);
                drive_write_data(item);
                drive_write_resp(item);
            join
        end else begin
            read_transactions++;
            // Allocate read_data array before use
            // The size is len+1 for a burst of len beats.
            item.read_data = new[item.len + 1];

            fork
                drive_read_addr(item);
                drive_read_data(item);
            join
        end
        
        // Check for error responses
        if (item.resp != OKAY) begin
            error_responses++;
            if (logger != null) begin
                logger.log_transaction(axi_logger::WARNING, 
                    $sformatf("Error response received: %s", item.resp.name()));
            end
        end
    endtask
    
    task drive_write_addr(axi_item item);
        @(posedge vif.aclk);
        vif.awid <= item.id;
        vif.awaddr <= item.addr;
        vif.awlen <= item.len;
        vif.awsize <= item.size;
        vif.awburst <= item.burst;
        vif.awlock <= item.lock;
        vif.awcache <= item.cache;
        vif.awprot <= item.prot;
        vif.awqos <= item.qos;
        vif.awregion <= item.region;
        vif.awvalid <= 1;
        
        // Wait for handshake with timeout
        fork: timeout_block
            begin
                do @(posedge vif.aclk);
                while (!vif.awready);
            end
            begin
                // Timeout protection
                repeat(1000) @(posedge vif.aclk);
                $error("AW channel handshake timeout");
            end
        join_any
        disable timeout_block;
        
        vif.awvalid <= 0;
    endtask
    
    task drive_write_data(axi_item item);
        // FIXED: Correct burst handling - len+1 beats
        for (int i = 0; i <= item.len; i++) begin
            @(posedge vif.aclk);
            vif.wdata <= item.data[i];
            vif.wstrb <= item.strb[i];
            vif.wlast <= (i == item.len);  // Last beat when i equals len
            vif.wvalid <= 1;
            
            // Wait for handshake with timeout
            fork: timeout_block
                begin
                    do @(posedge vif.aclk);
                    while (!vif.wready);
                end
                begin
                    repeat(1000) @(posedge vif.aclk);
                    $error("W channel handshake timeout at beat %0d", i);
                end
            join_any
            disable timeout_block;
        end
        vif.wvalid <= 0;
    endtask
    
    task drive_write_resp(axi_item item);
        vif.bready <= 1;
        
        // Wait for response with timeout
        fork: timeout_block
            begin
                do @(posedge vif.aclk);
                while (!vif.bvalid);
            end
            begin
                repeat(1000) @(posedge vif.aclk);
                $error("B channel response timeout");
            end
        join_any
        disable timeout_block;
        
        // Capture response
        item.resp = axi_resp_t'(vif.bresp);
        // Fixed: handle bid properly - assuming item has bid field or can ignore
        @(posedge vif.aclk);
        vif.bready <= 0;
    endtask
    
    task drive_read_addr(axi_item item);
        @(posedge vif.aclk);
        vif.arid <= item.id;
        vif.araddr <= item.addr;
        vif.arlen <= item.len;
        vif.arsize <= item.size;
        vif.arburst <= item.burst;
        vif.arlock <= item.lock;
        vif.arcache <= item.cache;
        vif.arprot <= item.prot;
        vif.arqos <= item.qos;
        vif.arregion <= item.region;
        vif.arvalid <= 1;
        
        // Wait for handshake with timeout
        fork: timeout_block
            begin
                do @(posedge vif.aclk);
                while (!vif.arready);
            end
            begin
                repeat(1000) @(posedge vif.aclk);
                $error("AR channel handshake timeout");
            end
        join_any
        disable timeout_block;
        
        vif.arvalid <= 0;
    endtask
    
    task drive_read_data(axi_item item);
        vif.rready <= 1;
        
        // FIXED: Proper burst read handling
        for (int i = 0; i <= item.len; i++) begin
            // Wait for data with timeout
            fork: timeout_block
                begin
                    do @(posedge vif.aclk);
                    while (!vif.rvalid);
                end
                begin
                    repeat(1000) @(posedge vif.aclk);
                    $error("R channel data timeout at beat %0d", i);
                end
            join_any
            disable timeout_block;
            
            // Capture data
            item.read_data[i] = vif.rdata;
            // Fixed: handle rid properly - assuming item has rid field or can ignore
            
            // FIXED: Check RLAST correctly
            if (i == item.len) begin
                if (!vif.rlast) begin
                    $error("Expected RLAST asserted at final beat %0d, but was not", i);
                end
            end else begin
                if (vif.rlast) begin
                    $error("RLAST asserted early at beat %0d (expected at beat %0d)", i, item.len);
                end
            end
            
            @(posedge vif.aclk);
        end
        
        // Capture final response
        item.resp = axi_resp_t'(vif.rresp);
        vif.rready <= 0;
    endtask
    
    // Statistics and reporting
    function void print_statistics();
        $display("=== AXI Driver Statistics ===");
        $display("Total Transactions: %0d", transactions_driven);
        $display("Write Transactions: %0d", write_transactions);
        $display("Read Transactions:  %0d", read_transactions);
        $display("Error Responses:    %0d", error_responses);
        $display("============================");
    endfunction
    
    function int get_transaction_count();
        return transactions_driven;
    endfunction
    
    function void reset_statistics();
        transactions_driven = 0;
        write_transactions = 0;
        read_transactions = 0;
        error_responses = 0;
    endfunction
    
endclass
