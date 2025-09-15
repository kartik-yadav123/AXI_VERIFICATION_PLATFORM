//==============================================================================
// Module: axi_dummy_mem_slave
// Description: A simple, dummy AXI4 memory slave model for simulation.
// It accepts AXI write and read transactions and stores/retrieves data
// from a simple memory array. It is not intended for synthesis.
//==============================================================================
module axi_dummy_mem_slave #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH = 4,
    parameter int MEM_SIZE = 1024*1024 // 1MB
)(
    input  logic aclk,
    input  logic aresetn,
    
    // AW Channel
    input  logic [ID_WIDTH-1:0]    awid,
    input  logic [ADDR_WIDTH-1:0]  awaddr,
    input  logic [7:0]             awlen,
    input  logic [2:0]             awsize,
    input  logic [1:0]             awburst,
    input  logic                   awlock,
    input  logic [3:0]             awcache,
    input  logic [2:0]             awprot,
    input  logic [3:0]             awqos,
    input  logic [3:0]             awregion,
    input  logic                   awvalid,
    output logic                   awready,
    
    // W Channel
    input  logic [DATA_WIDTH-1:0]    wdata,
    input  logic [(DATA_WIDTH/8)-1:0] wstrb,
    input  logic                     wlast,
    input  logic                     wvalid,
    output logic                     wready,
    
    // B Channel
    output logic [ID_WIDTH-1:0] bid,
    output logic [1:0]          bresp,
    output logic                bvalid,
    input  logic                bready,
    
    // AR Channel
    input  logic [ID_WIDTH-1:0]    arid,
    input  logic [ADDR_WIDTH-1:0]  araddr,
    input  logic [7:0]             arlen,
    input  logic [2:0]             arsize,
    input  logic [1:0]             arburst,
    input  logic                   arlock,
    input  logic [3:0]             arcache,
    input  logic [2:0]             arprot,
    input  logic [3:0]             arqos,
    input  logic [3:0]             arregion,
    input  logic                   arvalid,
    output logic                   arready,
    
    // R Channel
    output logic [ID_WIDTH-1:0]   rid,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic [1:0]            rresp,
    output logic                  rlast,
    output logic                  rvalid,
    input  logic                  rready
);

    // Memory array. Using `reg` to avoid multi-driver error with the initial block.
    reg [7:0] memory [0:MEM_SIZE-1];
    
    // Write transaction storage
    typedef struct packed {
        logic [ID_WIDTH-1:0] id;
        logic [ADDR_WIDTH-1:0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        int beat_count;
    } write_trans_t;
    
    // Read transaction storage
    typedef struct packed {
        logic [ID_WIDTH-1:0] id;
        logic [ADDR_WIDTH-1:0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        int beat_count;
    } read_trans_t;
    
    write_trans_t write_trans_queue[$];
    read_trans_t read_trans_queue[$];
    
    // AW Channel - Accept write address
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awready <= 0;
            write_trans_queue.delete();
            // Initialize memory on reset to avoid multi-driver issue
            for (int i = 0; i < MEM_SIZE; i++) begin
                memory[i] <= 8'h00; // or use a random value if preferred for simulation
            end
        end else begin
            awready <= 1; // Always ready for simplicity
            
            if (awvalid && awready) begin
                automatic write_trans_t wt; // make it automatic
                wt.id = awid;
                wt.addr = awaddr;
                wt.len = awlen;
                wt.size = awsize;
                wt.burst = awburst;
                wt.beat_count = 0;
                write_trans_queue.push_back(wt);
                $display("[AXI_DUMMY_MEM] Write address accepted: ID=%0d, Addr=%0h, Len=%0d", awid, awaddr, awlen);
            end
        end
    end
    
    // W Channel - Accept write data and write to memory
    logic [ID_WIDTH-1:0] write_id;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wready <= 0;
            write_id <= 0;
        end else begin
            wready <= (write_trans_queue.size() > 0);
            
            if (wvalid && wready && write_trans_queue.size() > 0) begin
                automatic write_trans_t wt;
                automatic logic [ADDR_WIDTH-1:0] addr;
                
                wt = write_trans_queue[0];
                addr = wt.addr + (wt.beat_count * (2**wt.size));
                
                // Write data to memory
                for (int i = 0; i < (DATA_WIDTH/8); i++) begin
                    if (wstrb[i] && (addr + i) < MEM_SIZE) begin
                        memory[addr + i] <= wdata[i*8 +: 8];
                    end
                end
                
                write_trans_queue[0].beat_count++;
                write_id <= wt.id;
                
                $display("[AXI_DUMMY_MEM] Write data beat %0d: Addr=%0h, Data=%0h, Strb=%0b", 
                         wt.beat_count, addr, wdata, wstrb);
                
                if (wlast) begin
                    void'(write_trans_queue.pop_front()); // Cast to void to prevent unused return value warnings/errors
                    $display("[AXI_DUMMY_MEM] Write transaction completed: ID=%0d", write_id);
                end
            end
        end
    end
    
    // B Channel - Write response
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            bvalid <= 0;
            bid <= 0;
            bresp <= 0;
        end else begin
            if (wvalid && wready && wlast && !bvalid) begin
                bvalid <= 1;
                bid <= write_id;
                bresp <= 2'b00; // OKAY
                $display("[AXI_DUMMY_MEM] Write response sent: ID=%0d, Resp=OKAY", write_id);
            end else if (bvalid && bready) begin
                bvalid <= 0;
            end
        end
    end
    
    // AR Channel - Accept read address
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            arready <= 0;
            read_trans_queue.delete();
        end else begin
            arready <= 1; // Always ready for simplicity
            
            if (arvalid && arready) begin
                automatic read_trans_t rt; // make it automatic
                rt.id = arid;
                rt.addr = araddr;
                rt.len = arlen;
                rt.size = arsize;
                rt.burst = arburst;
                rt.beat_count = 0;
                read_trans_queue.push_back(rt);
                $display("[AXI_DUMMY_MEM] Read address accepted: ID=%0d, Addr=%0h, Len=%0d", arid, araddr, arlen);
            end
        end
    end
    
    // R Channel - Read data response
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rvalid <= 0;
            rid <= 0;
            rdata <= 0;
            rresp <= 0;
            rlast <= 0;
        end else begin
            if (read_trans_queue.size() > 0 && !rvalid) begin
                automatic read_trans_t rt;
                automatic logic [ADDR_WIDTH-1:0] addr;
                
                rt = read_trans_queue[0];
                addr = rt.addr + (rt.beat_count * (2**rt.size));
                
                rvalid <= 1;
                rid <= rt.id;
                rresp <= 2'b00; // OKAY
                rlast <= (rt.beat_count == rt.len);
                
                // Read data from memory
                for (int i = 0; i < (DATA_WIDTH/8); i++) begin
                    if ((addr + i) < MEM_SIZE) begin
                        rdata[i*8 +: 8] <= memory[addr + i];
                    end else begin
                        rdata[i*8 +: 8] <= 8'h00;
                    end
                end
                
                $display("[AXI_DUMMY_MEM] Read data beat %0d: Addr=%0h, Data=%0h", 
                         rt.beat_count, addr, rdata);
                
            end else if (rvalid && rready) begin
                if (read_trans_queue.size() > 0) begin
                    read_trans_queue[0].beat_count++;
                    
                    if (rlast) begin
                        $display("[AXI_DUMMY_MEM] Read transaction completed: ID=%0d", rid);
                        void'(read_trans_queue.pop_front()); // Cast to void
                        rvalid <= 0;
                    end
                end else begin
                    rvalid <= 0;
                end
            end
        end
    end
    
    // Memory content dump for debugging
    function void dump_memory(int start_addr = 0, int num_bytes = 16);
        $display("[AXI_DUMMY_MEM] Memory dump from address %0h:", start_addr);
        for (int i = 0; i < num_bytes; i++) begin
            if ((start_addr + i) < MEM_SIZE) begin
                $display("  Addr %0h: %02h", start_addr + i, memory[start_addr + i]);
            end
        end
    endfunction
    
endmodule

