// ========================================================================
// SMOKE SEQUENCE - Basic functionality test - Final Fixed Version
// ========================================================================

import axi_pkg::*;
import axi_config_pkg::*;
import axi_logger_pkg::*;
import axi_agent_pkg::*; // Contains axi_sequencer and axi_item


class axi_seq_smoke;

    // --------------------------------------------------------------------
    // Class Members
    // --------------------------------------------------------------------
    axi_sequencer sequencer;
    axi_config    cfg;
    axi_logger    logger;

    // --------------------------------------------------------------------
    // Constructor
    // --------------------------------------------------------------------
    function new(string name = "axi_seq_smoke");
        // Constructor can be extended if needed
    endfunction

    // --------------------------------------------------------------------
    // Configuration and Logger Setters
    // --------------------------------------------------------------------
    function void set_config(axi_config cfg_param);
        cfg = cfg_param;
    endfunction

    function void set_logger(axi_logger log);
        logger = log;
    endfunction

    // --------------------------------------------------------------------
    // Main Start Task
    // --------------------------------------------------------------------
    task start(axi_sequencer seqr);
        sequencer = seqr;

        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO,"Starting smoke sequence");
        end

        // Test basic single transactions
        generate_single_write();
        #100;
        generate_single_read();
        #100;

        // Test simple bursts
        generate_burst_write(4);
        #100;
        generate_burst_read(4);
        #100;

        // Test different sizes
        generate_size_tests();

        if (logger != null) begin
            logger.log_transaction(axi_logger::INFO,
                                   "Smoke sequence completed");
        end
    endtask

    // --------------------------------------------------------------------
    // Generate Single Write
    // --------------------------------------------------------------------
    task generate_single_write();
        axi_item item;
        item = new();

        item.trans_type = AXI_WRITE;
        item.addr       = 32'h1000;
        item.len        = 0;          // Single beat
        item.size       = SIZE_4B;
        item.burst      = INCR;
        item.id         = 1;

        // Set data
        item.data = new[1];
        item.strb = new[1];
        item.data[0] = 32'hDEADBEEF;
        item.strb[0] = 4'hF;          // All bytes valid

        // Send item to sequencer
        sequencer.seq_mailbox.put(item);
    endtask

    // --------------------------------------------------------------------
    // Generate Single Read
    // --------------------------------------------------------------------
    task generate_single_read();
        axi_item item;
        item = new();

        item.trans_type = AXI_READ;
        item.addr       = 32'h1000;
        item.len        = 0;           // Single beat
        item.size       = SIZE_4B;
        item.burst      = INCR;
        item.id         = 2;

        sequencer.seq_mailbox.put(item);
    endtask

    // --------------------------------------------------------------------
    // Generate Burst Write
    // --------------------------------------------------------------------
    task generate_burst_write(int burst_len);
        axi_item item;
        string item_name;

        item_name = $sformatf("smoke_burst_write_%0d", burst_len);
        item = new();

        item.trans_type = AXI_WRITE;
        item.addr       = 32'h2000;
        item.len        = burst_len - 1; // AXI len is beats-1
        item.size       = SIZE_4B;
        item.burst      = INCR;
        item.id         = 3;

        // Set data for all beats
        item.data = new[burst_len];
        item.strb = new[burst_len];
        for (int i = 0; i < burst_len; i++) begin
            item.data[i] = 32'hCAFE0000 + i;
            item.strb[i] = 4'hF;
        end

        sequencer.seq_mailbox.put(item);
    endtask

    // --------------------------------------------------------------------
    // Generate Burst Read
    // --------------------------------------------------------------------
    task generate_burst_read(int burst_len);
        axi_item item;
        string item_name;

        item_name = $sformatf("smoke_burst_read_%0d", burst_len);
        item = new();

        item.trans_type = AXI_READ;
        item.addr       = 32'h2000;
        item.len        = burst_len - 1; // AXI len is beats-1
        item.size       = SIZE_4B;
        item.burst      = INCR;
        item.id         = 4;

        sequencer.seq_mailbox.put(item);
    endtask

    // --------------------------------------------------------------------
    // Generate Size Tests
    // --------------------------------------------------------------------
    task generate_size_tests();
        axi_size_t test_sizes[4];
        axi_item write_item;
        string write_name;
        axi_item read_item;
        string read_name;

        test_sizes[0] = SIZE_1B;
        test_sizes[1] = SIZE_2B;
        test_sizes[2] = SIZE_4B;
        test_sizes[3] = SIZE_8B;

        for (int i = 0; i < 4; i++) begin
            // -----------------
            // Write test
            // -----------------
            write_name = $sformatf("smoke_size_write_%0d", i);
            write_item = new();

            write_item.trans_type = AXI_WRITE;
            write_item.addr       = 32'h3000 + (i * 32); // Spaced addresses
            write_item.len        = 0;
            write_item.size       = test_sizes[i];
            write_item.burst      = INCR;
            write_item.id         = 10 + i;

            write_item.data = new[1];
            write_item.strb = new[1];
            write_item.data[0] = 32'hA5A50000 + i;

            // Set strobe based on size
            case (test_sizes[i])
                SIZE_1B: write_item.strb[0] = 4'h1;
                SIZE_2B: write_item.strb[0] = 4'h3;
                SIZE_4B: write_item.strb[0] = 4'hF;
                SIZE_8B: write_item.strb[0] = 4'hF; // Lower 32-bits for this example
                default: write_item.strb[0] = 4'hF;
            endcase

            sequencer.seq_mailbox.put(write_item);
            #50;

            // -----------------
            // Read test
            // -----------------
            read_name = $sformatf("smoke_size_read_%0d", i);
            read_item = new();

            read_item.trans_type = AXI_READ;
            read_item.addr       = write_item.addr;
            read_item.len        = 0;
            read_item.size       = test_sizes[i];
            read_item.burst      = INCR;
            read_item.id         = 20 + i;

            sequencer.seq_mailbox.put(read_item);
            #50;
        end
    endtask

endclass
