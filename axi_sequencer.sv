//=============================================================================
// axi_sequencer.sv
//
// This file contains the AXI sequencer class. It is responsible for
// managing the flow of transactions from sequences to the driver and
// also sending expected transactions to the scoreboard for analysis.
//
// This is a fixed version of the provided code, completed for
// a non-UVM SystemVerilog testbench.
//
// NOTE: Compile axi_logger.sv BEFORE this file to avoid compilation errors
//=============================================================================

// Include the logger file to make the class visible
import axi_pkg::*;
import axi_config_pkg::*;
import axi_logger_pkg::*;  // <-- This gives access to axi_logger


class axi_sequencer;
    
    // Communication ports
    // This is the mailbox for sequences to send items to the sequencer
    mailbox #(axi_item) seq_mailbox;
    mailbox #(axi_item) seq_item_export;     // To driver
    mailbox #(axi_item) sb_expected_port;    // To scoreboard expected port
    
    // Configuration and logging
    axi_config cfg;
    axi_logger logger;
    
    // Internal queue to track sent items for debugging/analysis
    axi_item sent_items[$];
    
    // Control - renamed 'stop' variable to avoid conflict with stop() function
    bit stop_flag = 0;
    bit auto_generate = 0;
    
    // Statistics
    int items_sent;
    
    //-------------------------------------------------------------------------
    // Function: new
    // The constructor initializes mailboxes and counters.
    //-------------------------------------------------------------------------
    function new(string name = "axi_sequencer");
        seq_mailbox = new();
        seq_item_export = new();
        sb_expected_port = new();
        items_sent = 0;
    endfunction
    
    //-------------------------------------------------------------------------
    // Function: set_config
    // Sets the configuration object for the sequencer.
    // Renamed 'config' to 'cfg_h' to avoid a SystemVerilog keyword conflict.
    //-------------------------------------------------------------------------
    function void set_config(axi_config cfg_h);
        cfg = cfg_h;
    endfunction
    
    //-------------------------------------------------------------------------
    // Function: set_logger
    // Sets the logger object for the sequencer.
    //-------------------------------------------------------------------------
    function void set_logger(axi_logger log);
        logger = log;
    endfunction
    
    //-------------------------------------------------------------------------
    // Function: connect_scoreboard
    // Connects the sequencer's expected port to the scoreboard's port.
    // This allows the sequencer to send copies of items to the scoreboard.
    //-------------------------------------------------------------------------
    function void connect_scoreboard(mailbox #(axi_item) sb_exp_port);
        this.sb_expected_port = sb_exp_port;
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Sequencer connected to scoreboard");
        end
    endfunction
    
    //-------------------------------------------------------------------------
    // Task: run
    // The main execution task for the sequencer.
    // It starts a fork-join block to handle item generation and processing
    // concurrently.
    //-------------------------------------------------------------------------
    task run();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Sequencer started");
        end
        
        fork
            // Main sequencer loop that processes queued items
            sequence_loop();
            
            // Optional auto-generation (only if enabled)
            if (auto_generate) begin
                auto_generation_loop();
            end
        join_any
        
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO,
                $sformatf("Sequencer stopped - %0d items sent", items_sent));
        end
    endtask
    
    //-------------------------------------------------------------------------
    // Task: sequence_loop
    // This loop continuously gets new items from the sequences via the mailbox
    // and sends them to the driver.
    //-------------------------------------------------------------------------
    task sequence_loop();
        axi_item item;
        forever begin
            if (stop_flag) break;
            
            // Wait for an item to be available in the mailbox
            seq_mailbox.get(item);
            send_item(item);
        end
    endtask
    
    //-------------------------------------------------------------------------
    // Task: auto_generation_loop
    // This loop randomly generates transactions and adds them to the
    // sequencer's queue for processing.
    //-------------------------------------------------------------------------
    task auto_generation_loop();
        axi_item auto_item;
        while (!stop_flag) begin
            // Create and randomize a new item
            auto_item = new();
            if (auto_item.randomize()) begin
                // Add to mailbox instead of internal queue
                add_item(auto_item);
            end else begin
                if (logger != null) begin
                    logger.log_transaction(axi_logger::ERROR, "Auto-generation failed to randomize an item!");
                end
            end
            
            // Add a check to ensure cfg is not null before accessing its members
            if (cfg != null) begin
                #(cfg.clock_period * 2);
            end else begin
                if (logger != null) begin
                    logger.log_transaction(axi_logger::ERROR, "Configuration object not set!");
                end
                #2; // Wait a little to avoid a tight loop on error
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Task: send_item
    // Sends a single transaction item to both the driver and the scoreboard.
    //-------------------------------------------------------------------------
    task send_item(axi_item item);
        axi_item item_copy;
        
        // Log the item before sending
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO, "Sending item to driver...");
        end

        // Send a copy to the scoreboard's expected port
        // The try_put is non-blocking, so it won't wait if the mailbox is full
        if (!sb_expected_port.try_put(item.clone())) begin
            if (logger != null) begin
                logger.log_transaction(axi_logger::WARNING, "Scoreboard mailbox is full");
            end
        end

        // Send the original item to the driver
        // The try_put is non-blocking, so it won't wait if the mailbox is full
        if (!seq_item_export.try_put(item)) begin
            if (logger != null) begin
                logger.log_transaction(axi_logger::WARNING, "Driver mailbox is full");
            end
        end
        sent_items.push_back(item);
        items_sent++;
    endtask
    
    //-------------------------------------------------------------------------
    // Task: add_item
    // Adds a transaction item to the sequencer's mailbox. Sequences call this
    // task to provide items for the driver.
    //-------------------------------------------------------------------------
    task add_item(axi_item item);
        seq_mailbox.put(item);
    endtask
    
    //-------------------------------------------------------------------------
    // Function: stop_sequencer
    // Halts the sequencer's run task. Renamed from 'stop' to avoid conflict.
    //-------------------------------------------------------------------------
    function void stop_sequencer();
        stop_flag = 1;
    endfunction

    //-------------------------------------------------------------------------
    // Function: print_status
    // Prints the current statistics of the sequencer.
    //-------------------------------------------------------------------------
    function void print_status();
        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO,
                $sformatf("Sequencer Status: %0d items sent, %0d items in mailbox",
                items_sent, seq_mailbox.num()));
        end
    endfunction
    
endclass
