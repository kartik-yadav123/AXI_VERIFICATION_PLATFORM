import axi_pkg::*;

class axi_monitor;
    
    // ? FIXED: Add parameters to match interface instantiation
    virtual axi_if#(.ADDR_WIDTH(32), .DATA_WIDTH(64), .ID_WIDTH(4), .STRB_WIDTH(8)).monitor vif;
    mailbox #(axi_item) ap;
    
    function new(string name = "axi_monitor");
        ap = new();
    endfunction
    
    // ? FIXED: Update function parameter to match
    function void set_virtual_interface(virtual axi_if#(.ADDR_WIDTH(32), .DATA_WIDTH(64), .ID_WIDTH(4), .STRB_WIDTH(8)).monitor vif_param);
        this.vif = vif_param;  // Assign the monitor modport view
    endfunction
    
    task run();
        fork
            monitor_write();
            monitor_read();
        join_none
    endtask
    
    task monitor_write();
        forever begin
            axi_item item = new(); // Corrected: removed string argument
            
            // Wait for write address
            @(posedge vif.aclk);
            while (!(vif.awvalid && vif.awready)) @(posedge vif.aclk);
            
            item.trans_type = AXI_WRITE;
            item.id = vif.awid;
            item.addr = vif.awaddr;
            item.len = vif.awlen;
            item.size = axi_size_t'(vif.awsize);
            item.burst = axi_burst_t'(vif.awburst);
            item.lock = vif.awlock;
            item.cache = vif.awcache;
            item.prot = vif.awprot;
            item.qos = vif.awqos;
            item.region = vif.awregion;
            
            // Collect write data
            item.data = new[item.len + 1];
            item.strb = new[item.len + 1];
            
            for (int i = 0; i <= item.len; i++) begin
                while (!(vif.wvalid && vif.wready)) @(posedge vif.aclk);
                item.data[i] = vif.wdata;
                item.strb[i] = vif.wstrb;
                @(posedge vif.aclk);
            end
            
            // Wait for write response
            while (!(vif.bvalid && vif.bready)) @(posedge vif.aclk);
            item.resp = axi_resp_t'(vif.bresp);
            
            ap.put(item);
        end
    endtask
    
    task monitor_read();
        forever begin
            axi_item item = new(); // Corrected: removed string argument
            
            // Wait for read address
            @(posedge vif.aclk);
            while (!(vif.arvalid && vif.arready)) @(posedge vif.aclk);
            
            item.trans_type = AXI_READ;
            item.id = vif.arid;
            item.addr = vif.araddr;
            item.len = vif.arlen;
            item.size = axi_size_t'(vif.arsize);
            item.burst = axi_burst_t'(vif.arburst);
            item.lock = vif.arlock;
            item.cache = vif.arcache;
            item.prot = vif.arprot;
            item.qos = vif.arqos;
            item.region = vif.arregion;
            
            // Collect read data
            item.read_data = new[item.len + 1];
            
            for (int i = 0; i <= item.len; i++) begin
                while (!(vif.rvalid && vif.rready)) @(posedge vif.aclk);
                item.read_data[i] = vif.rdata;
                @(posedge vif.aclk);
            end
            
            item.resp = axi_resp_t'(vif.rresp);
            ap.put(item);
        end
    endtask
    
endclass
