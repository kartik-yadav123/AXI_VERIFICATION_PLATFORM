//=============================================================================
// axi_tb_top.sv
//
// Top-level testbench for the AXI environment. This module directly
// instantiates the environment class and runs the test without any UVM framework.
// NO RANDOMIZATION - Uses only basic SystemVerilog features
//=============================================================================

`include "axi_env.sv"

module axi_tb_top;
    import axi_pkg::*;
    // Import AXI base definitions (types, parameters, etc.)

    // -------------------------------------------------------------------------
    // Clock and reset signals
    // -------------------------------------------------------------------------
    logic aclk;
    logic aresetn;

    // -------------------------------------------------------------------------
    // Test control variables
    // -------------------------------------------------------------------------
    int transaction_count = 0;
    logic [31:0] test_addresses[8] = '{32'h1000, 32'h1008, 32'h1010, 32'h1018,
                                       32'h1020, 32'h1028, 32'h1030, 32'h1038};
    logic [63:0] test_data[8] = '{64'hDEADBEEF12345678, 64'hCAFEBABE87654321,
                                  64'h0123456789ABCDEF, 64'hFEDCBA9876543210,
                                  64'hAAAABBBBCCCCDDDD, 64'h1111222233334444,
                                  64'h5555666677778888, 64'h9999AAAABBBBCCCC};
    logic [3:0] test_ids[4] = '{4'h1, 4'h2, 4'h3, 4'h4};

    // -------------------------------------------------------------------------
    // Declare environment handle (class pointer)
    // -------------------------------------------------------------------------
    axi_env env;  // Class handle, not module instantiation

    // -------------------------------------------------------------------------
    // Instantiate AXI interface - FIXED PARAMETER ORDER
    // -------------------------------------------------------------------------
    axi_if #(
        .ADDR_WIDTH(32),   // First parameter in interface definition
        .DATA_WIDTH(64),   // Second parameter in interface definition  
        .ID_WIDTH(4),      // Third parameter in interface definition
        .STRB_WIDTH(8)     // Fourth parameter in interface definition
    ) axi_intf (
        .aclk(aclk),
        .aresetn(aresetn)
    );

    // -------------------------------------------------------------------------
    // Instantiate DUT (AXI dummy memory slave) - FIXED PARAMETER ORDER
    // -------------------------------------------------------------------------
    axi_dummy_mem_slave #(
        .ADDR_WIDTH(32),   // Match interface parameter order
        .DATA_WIDTH(64),   // Match interface parameter order
        .ID_WIDTH(4)       // Match interface parameter order
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),

        // AW Channel
        .awid(axi_intf.awid),
        .awaddr(axi_intf.awaddr),
        .awlen(axi_intf.awlen),
        .awsize(axi_intf.awsize),
        .awburst(axi_intf.awburst),
        .awlock(axi_intf.awlock),
        .awcache(axi_intf.awcache),
        .awprot(axi_intf.awprot),
        .awqos(axi_intf.awqos),
        .awregion(axi_intf.awregion),
        .awvalid(axi_intf.awvalid),
        .awready(axi_intf.awready),

        // W Channel
        .wdata(axi_intf.wdata),
        .wstrb(axi_intf.wstrb),
        .wlast(axi_intf.wlast),
        .wvalid(axi_intf.wvalid),
        .wready(axi_intf.wready),

        // B Channel
        .bid(axi_intf.bid),
        .bresp(axi_intf.bresp),
        .bvalid(axi_intf.bvalid),
        .bready(axi_intf.bready),

        // AR Channel
        .arid(axi_intf.arid),
        .araddr(axi_intf.araddr),
        .arlen(axi_intf.arlen),
        .arsize(axi_intf.arsize),
        .arburst(axi_intf.arburst),
        .arlock(axi_intf.arlock),
        .arcache(axi_intf.arcache),
        .arprot(axi_intf.arprot),
        .arqos(axi_intf.arqos),
        .arregion(axi_intf.arregion),
        .arvalid(axi_intf.arvalid),
        .arready(axi_intf.arready),

        // R Channel
        .rid(axi_intf.rid),
        .rdata(axi_intf.rdata),
        .rresp(axi_intf.rresp),
        .rlast(axi_intf.rlast),
        .rvalid(axi_intf.rvalid),
        .rready(axi_intf.rready)
    );

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;  // 100 MHz clock
    end
    
    // -------------------------------------------------------------------------
    // Reset generation
    // -------------------------------------------------------------------------
    initial begin
        aresetn = 0;
        #100;
        aresetn = 1;
        $display("Reset released at time %0t", $time);
    end

    // -------------------------------------------------------------------------
    // Deterministic AXI Transaction Generator 
    // -------------------------------------------------------------------------
    initial begin
        int i;
        
        // Wait for reset to be released
        wait(aresetn === 1'b1);
        repeat(10) @(posedge aclk);
        
        $display("Starting deterministic AXI transactions at time %0t", $time);
        
        // Generate predetermined write transactions
        for (i = 0; i < 4; i++) begin
            generate_write_transaction(test_addresses[i], test_data[i], test_ids[i % 4]);
            repeat(20) @(posedge aclk);  // Fixed delay between transactions
        end
        
        // Wait before starting reads
        repeat(50) @(posedge aclk);
        
        // Generate predetermined read transactions
        for (i = 0; i < 4; i++) begin
            generate_read_transaction(test_addresses[i], test_ids[i % 4]);
            repeat(20) @(posedge aclk);  // Fixed delay between transactions
        end
        
        $display("Deterministic transactions completed at time %0t", $time);
    end

    // -------------------------------------------------------------------------
    // Simple write transaction task (no randomization)
    // -------------------------------------------------------------------------
    task generate_write_transaction(logic [31:0] addr, logic [63:0] data, logic [3:0] id);
        $display("[%0t] Generating WRITE: addr=0x%08x, data=0x%016x, id=%0d", 
                 $time, addr, data, id);
        
        @(posedge aclk);
        
        // Address Write Channel
        axi_intf.awaddr  = addr;
        axi_intf.awid    = id;
        axi_intf.awlen   = 8'h00;  // Single transfer
        axi_intf.awsize  = 3'b011; // 8 bytes (64-bit)
        axi_intf.awburst = 2'b01;  // INCR
        axi_intf.awlock  = 1'b0;
        axi_intf.awcache = 4'b0000;
        axi_intf.awprot  = 3'b000;
        axi_intf.awqos   = 4'b0000;
        axi_intf.awregion = 4'b0000;
        axi_intf.awvalid = 1'b1;
        
        // Write Data Channel
        axi_intf.wdata   = data;
        axi_intf.wstrb   = 8'hFF;  // All bytes valid
        axi_intf.wlast   = 1'b1;   // Single transfer
        axi_intf.wvalid  = 1'b1;
        
        // Write Response Channel
        axi_intf.bready  = 1'b1;
        
        // Wait for address write accept
        while (!axi_intf.awready) @(posedge aclk);
        @(posedge aclk);
        axi_intf.awvalid = 1'b0;
        
        // Wait for data write accept  
        while (!axi_intf.wready) @(posedge aclk);
        @(posedge aclk);
        axi_intf.wvalid = 1'b0;
        axi_intf.wlast  = 1'b0;
        
        // Wait for write response
        while (!axi_intf.bvalid) @(posedge aclk);
        @(posedge aclk);
        axi_intf.bready = 1'b0;
        
        transaction_count++;
        $display("[%0t] WRITE #%0d completed: resp=%0d", $time, transaction_count, axi_intf.bresp);
    endtask

    // -------------------------------------------------------------------------
    // Simple read transaction task (no randomization)
    // -------------------------------------------------------------------------
    task generate_read_transaction(logic [31:0] addr, logic [3:0] id);
        $display("[%0t] Generating READ: addr=0x%08x, id=%0d", $time, addr, id);
        
        @(posedge aclk);
        
        // Address Read Channel
        axi_intf.araddr  = addr;
        axi_intf.arid    = id;
        axi_intf.arlen   = 8'h00;  // Single transfer
        axi_intf.arsize  = 3'b011; // 8 bytes (64-bit)
        axi_intf.arburst = 2'b01;  // INCR
        axi_intf.arlock  = 1'b0;
        axi_intf.arcache = 4'b0000;
        axi_intf.arprot  = 3'b000;
        axi_intf.arqos   = 4'b0000;
        axi_intf.arregion = 4'b0000;
        axi_intf.arvalid = 1'b1;
        
        // Read Data Channel
        axi_intf.rready  = 1'b1;
        
        // Wait for address read accept
        while (!axi_intf.arready) @(posedge aclk);
        @(posedge aclk);
        axi_intf.arvalid = 1'b0;
        
        // Wait for read data
        while (!axi_intf.rvalid) @(posedge aclk);
        @(posedge aclk);
        axi_intf.rready = 1'b0;
        
        transaction_count++;
        $display("[%0t] READ #%0d completed: data=0x%016x, resp=%0d", 
                 $time, transaction_count, axi_intf.rdata, axi_intf.rresp);
    endtask

    // -------------------------------------------------------------------------
    // Initialize AXI interface signals
    // -------------------------------------------------------------------------
    initial begin
        // Initialize all master signals to safe values
        axi_intf.awaddr   = 32'h0;
        axi_intf.awid     = 4'h0;
        axi_intf.awlen    = 8'h0;
        axi_intf.awsize   = 3'h0;
        axi_intf.awburst  = 2'h0;
        axi_intf.awlock   = 1'b0;
        axi_intf.awcache  = 4'h0;
        axi_intf.awprot   = 3'h0;
        axi_intf.awqos    = 4'h0;
        axi_intf.awregion = 4'h0;
        axi_intf.awvalid  = 1'b0;
        
        axi_intf.wdata    = 64'h0;
        axi_intf.wstrb    = 8'h0;
        axi_intf.wlast    = 1'b0;
        axi_intf.wvalid   = 1'b0;
        
        axi_intf.bready   = 1'b0;
        
        axi_intf.araddr   = 32'h0;
        axi_intf.arid     = 4'h0;
        axi_intf.arlen    = 8'h0;
        axi_intf.arsize   = 3'h0;
        axi_intf.arburst  = 2'h0;
        axi_intf.arlock   = 1'b0;
        axi_intf.arcache  = 4'h0;
        axi_intf.arprot   = 3'h0;
        axi_intf.arqos    = 4'h0;
        axi_intf.arregion = 4'h0;
        axi_intf.arvalid  = 1'b0;
        
        axi_intf.rready   = 1'b0;
    end

    // -------------------------------------------------------------------------
    // Run test with environment
    // -------------------------------------------------------------------------
    initial begin
        $display("Starting AXI test without UVM (No License Required)...");

        // Wait for reset to be released
        wait(aresetn === 1'b1);
        repeat(5) @(posedge aclk);  // Additional delay after reset
        
        // Instantiate environment class
        env = new();  

        // Connect virtual interface to environment AFTER creation
        env.set_virtual_interface(axi_intf.master);

        // Build the environment (creates driver, monitor, etc.)
        env.build();

        // Run environment in parallel with timing control
        fork
            env.run();
            begin
                repeat(2000) @(posedge aclk);  // Run for 2000 cycles
                $display("Test timeout reached - stopping test");
            end
        join_any
        
        // Wait a bit more for any pending transactions
        repeat(100) @(posedge aclk);
        
        // Disable any remaining processes
        disable fork;

        // Final report
        env.final_report();

        $display("AXI test completed. Total manual transactions: %0d", transaction_count);
       
    end

    // -------------------------------------------------------------------------
    // Additional simple test patterns
    // -------------------------------------------------------------------------
    initial begin
        wait(aresetn === 1'b1);
        repeat(1500) @(posedge aclk);  // Wait for other tests to complete
        
        $display("Starting additional simple test patterns...");
        
        // Simple burst test - write then read back same location
        generate_write_transaction(32'h2000, 64'h123456789ABCDEF0, 4'h5);
        repeat(30) @(posedge aclk);
        generate_read_transaction(32'h2000, 4'h5);
        
        repeat(30) @(posedge aclk);
        
        // Another pair
        generate_write_transaction(32'h2008, 64'hFEDCBA0987654321, 4'h6);
        repeat(30) @(posedge aclk);
        generate_read_transaction(32'h2008, 4'h6);
        
        $display("Additional test patterns completed");
    end

    // -------------------------------------------------------------------------
    // Waveform dumping for GTKWave or ModelSim
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("axi_tb.vcd");
        $dumpvars(0, axi_tb_top);
        
        // Also dump specific AXI signals for easier debug
        $dumpvars(1, axi_intf.awaddr, axi_intf.awvalid, axi_intf.awready);
        $dumpvars(1, axi_intf.wdata, axi_intf.wvalid, axi_intf.wready);
        $dumpvars(1, axi_intf.bvalid, axi_intf.bready, axi_intf.bresp);
        $dumpvars(1, axi_intf.araddr, axi_intf.arvalid, axi_intf.arready);
        $dumpvars(1, axi_intf.rdata, axi_intf.rvalid, axi_intf.rready);
    end

    // -------------------------------------------------------------------------
    // Debug: Monitor AXI transactions
    // -------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (aresetn) begin
            // Monitor write address channel
            if (axi_intf.awvalid && axi_intf.awready) begin
                $display("[%0t] AW HANDSHAKE: addr=0x%08x, id=%0d", $time, axi_intf.awaddr, axi_intf.awid);
            end
            
            // Monitor write data channel
            if (axi_intf.wvalid && axi_intf.wready) begin
                $display("[%0t] W HANDSHAKE: data=0x%016x, strb=0x%02x, last=%0b", 
                         $time, axi_intf.wdata, axi_intf.wstrb, axi_intf.wlast);
            end
            
            // Monitor write response channel
            if (axi_intf.bvalid && axi_intf.bready) begin
                $display("[%0t] B HANDSHAKE: resp=%0d, id=%0d", $time, axi_intf.bresp, axi_intf.bid);
            end
            
            // Monitor read address channel
            if (axi_intf.arvalid && axi_intf.arready) begin
                $display("[%0t] AR HANDSHAKE: addr=0x%08x, id=%0d", $time, axi_intf.araddr, axi_intf.arid);
            end
            
            // Monitor read data channel
            if (axi_intf.rvalid && axi_intf.rready) begin
                $display("[%0t] R HANDSHAKE: data=0x%016x, resp=%0d, last=%0b, id=%0d", 
                         $time, axi_intf.rdata, axi_intf.rresp, axi_intf.rlast, axi_intf.rid);
            end
        end
    end

    // -------------------------------------------------------------------------
    // Simple protocol checker (basic)
    // -------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (aresetn) begin
            // Check for X/Z on critical signals
            if (^axi_intf.awvalid === 1'bx) $error("AWVALID is X/Z!");
            if (^axi_intf.wvalid === 1'bx) $error("WVALID is X/Z!");
            if (^axi_intf.arvalid === 1'bx) $error("ARVALID is X/Z!");
            if (^axi_intf.bready === 1'bx) $error("BREADY is X/Z!");
            if (^axi_intf.rready === 1'bx) $error("RREADY is X/Z!");
        end
    end

endmodule
