//=============================================================================
// axi_pkg.sv
//
// This package defines all shared types, enums, and classes for the AXI
// protocol, including the transaction item class.
// FIXED: Removed 'rand' keywords for ModelSim compatibility
//=============================================================================

package axi_pkg;
    
    // AXI4 Parameters
    parameter int AXI_ADDR_WIDTH = 32;
    parameter int AXI_DATA_WIDTH = 32;
    parameter int AXI_ID_WIDTH = 4;
    parameter int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;
    
    // Burst types
  typedef enum logic [1:0] {
    FIXED = 2'b00,
    INCR  = 2'b01,
    WRAP  = 2'b10,
    RSVD  = 2'b11
} axi_burst_t;

    
    // Response types
    typedef enum logic [1:0] {
        OKAY   = 2'b00,
        EXOKAY = 2'b01,
        SLVERR = 2'b10,
        DECERR = 2'b11
    } axi_resp_t;
 // ? COMPLETE SOLUTION: Define all interface typedefs with exact parameters
    // These MUST match your testbench instantiation: axi_if #(32, 64, 4, 8)
    typedef virtual axi_if#(.ADDR_WIDTH(32), .DATA_WIDTH(64), .ID_WIDTH(4), .STRB_WIDTH(8))         axi_vif_t;
    typedef virtual axi_if#(.ADDR_WIDTH(32), .DATA_WIDTH(64), .ID_WIDTH(4), .STRB_WIDTH(8)).master  axi_vif_master_t;
    typedef virtual axi_if#(.ADDR_WIDTH(32), .DATA_WIDTH(64), .ID_WIDTH(4), .STRB_WIDTH(8)).monitor axi_vif_monitor_t;
    
    
    // Size encoding
    typedef enum logic [2:0] {
        SIZE_1B   = 3'b000,
        SIZE_2B   = 3'b001,
        SIZE_4B   = 3'b010,
        SIZE_8B   = 3'b011,
        SIZE_16B  = 3'b100,
        SIZE_32B  = 3'b101,
        SIZE_64B  = 3'b110,
        SIZE_128B = 3'b111
    } axi_size_t;


typedef enum logic [1:0] {
    DEBUG = 2'b00,  // Debug-level messages
    INFO  = 2'b01,  // Informational messages
    WARN  = 2'b10,  // Warnings
    ERROR = 2'b11   // Errors
} verbosity_e;

    
    // Transaction types
    typedef enum {
        AXI_WRITE,
        AXI_READ
    } axi_trans_type_t;
    
    // AXI Transaction Item Class
    // Defines a single AXI transaction
    // FIXED: Removed all 'rand' keywords for basic ModelSim compatibility
    class axi_item;
        axi_trans_type_t trans_type; // Transaction type (read/write) - NO RAND
        logic [AXI_ID_WIDTH-1:0] id; // NO RAND
        logic [AXI_ADDR_WIDTH-1:0] addr; // NO RAND
        logic [3:0] len; // NO RAND
        logic [2:0] size; // NO RAND
        axi_burst_t burst; // NO RAND
        logic lock; // NO RAND
        logic [3:0] cache; // NO RAND
        logic [2:0] prot; // NO RAND
        logic [3:0] qos; // NO RAND
        logic [3:0] region; // NO RAND
        
        logic [AXI_DATA_WIDTH-1:0] data[]; // Dynamic array for write data - NO RAND
        logic [AXI_STRB_WIDTH-1:0] strb[]; // Dynamic array for write strobes - NO RAND
        
        // Read-only fields for received data and response
        logic [AXI_DATA_WIDTH-1:0] read_data[];
        logic [AXI_ID_WIDTH-1:0] rid;
        axi_resp_t resp;
        logic [AXI_ID_WIDTH-1:0] bid;
        
        // Constructor
        function new();
        endfunction
        
        // Manual randomization function to replace .randomize()
        function void randomize_manual();
            // Simple pseudo-random generation using $random
            trans_type = ($random % 2) ? AXI_READ : AXI_WRITE;
            id = $random % (2**AXI_ID_WIDTH);
            addr = $random % (2**AXI_ADDR_WIDTH);
            len = $random % 16; // 0-15 for AXI4
            size = $random % 8; // 0-7 for size encoding
            burst = axi_burst_t'($random % 3); // 0-2 (skip RSVD)
            lock = $random % 2;
            cache = $random % 16;
            prot = $random % 8;
            qos = $random % 16;
            region = $random % 16;
            
            // Allocate and randomize data arrays based on length
            if (trans_type == AXI_WRITE) begin
                data = new[len + 1];
                strb = new[len + 1];
                for (int i = 0; i <= len; i++) begin
                    data[i] = $random;
                    strb[i] = $random % (2**AXI_STRB_WIDTH);
                end
            end
        endfunction
        
        // Standard UVM-like methods (for non-UVM testbench)
        function axi_item clone();
            axi_item copy = new();
            copy.copy(this);
            return copy;
        endfunction
        
        function void copy(axi_item from);
            this.trans_type = from.trans_type;
            this.id = from.id;
            this.addr = from.addr;
            this.len = from.len;
            this.size = from.size;
            this.burst = from.burst;
            this.lock = from.lock;
            this.cache = from.cache;
            this.prot = from.prot;
            this.qos = from.qos;
            this.region = from.region;
            
            // Deep copy of dynamic arrays
            this.data = new[from.data.size()];
            this.strb = new[from.strb.size()];
            this.data = from.data;
            this.strb = from.strb;
        endfunction
        
        function string convert2string();
            string s;
            s = $sformatf("Trans: %s, ID: %0h, Addr: %0h, Len: %0d", 
                trans_type.name(), id, addr, len);
            return s;
        endfunction
        
    endclass
    
endpackage
