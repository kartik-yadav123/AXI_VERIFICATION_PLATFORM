interface axi_if #(parameter ADDR_WIDTH = 32,
                   parameter DATA_WIDTH = 32,
                   parameter ID_WIDTH   = 4,
                   parameter STRB_WIDTH = (DATA_WIDTH/8))
                  (input logic aclk,
                   input logic aresetn);

    // ==============================================
    // AXI4 WRITE ADDRESS CHANNEL
    // ==============================================
    logic [ID_WIDTH-1:0]     awid;
    logic [ADDR_WIDTH-1:0]   awaddr;
    logic [7:0]               awlen;     // Burst length
    logic [2:0]               awsize;    // Burst size
    logic [1:0]               awburst;   // Burst type
    logic                     awlock;
    logic [3:0]               awcache;
    logic [2:0]               awprot;
    logic [3:0]               awqos;
    logic [3:0]               awregion;
    logic                     awvalid;
    logic                     awready;

    // ==============================================
    // AXI4 WRITE DATA CHANNEL
    // ==============================================
    logic [DATA_WIDTH-1:0]    wdata;
    logic [STRB_WIDTH-1:0]    wstrb;
    logic                     wlast;
    logic                     wvalid;
    logic                     wready;

    // ==============================================
    // AXI4 WRITE RESPONSE CHANNEL
    // ==============================================
    logic [ID_WIDTH-1:0]      bid;
    logic [1:0]               bresp;
    logic                     bvalid;
    logic                     bready;

    // ==============================================
    // AXI4 READ ADDRESS CHANNEL
    // ==============================================
    logic [ID_WIDTH-1:0]      arid;
    logic [ADDR_WIDTH-1:0]    araddr;
    logic [7:0]                arlen;
    logic [2:0]                arsize;
    logic [1:0]                arburst;
    logic                      arlock;
    logic [3:0]                arcache;
    logic [2:0]                arprot;
    logic [3:0]                arqos;
    logic [3:0]                arregion;
    logic                      arvalid;
    logic                      arready;

    // ==============================================
    // AXI4 READ DATA CHANNEL
    // ==============================================
    logic [ID_WIDTH-1:0]      rid;
    logic [DATA_WIDTH-1:0]    rdata;
    logic [1:0]               rresp;
    logic                     rlast;
    logic                     rvalid;
    logic                     rready;

    // ==============================================
    // MASTER MODPORT
    // ==============================================
    modport master (
        input  aclk, aresetn,

        // Outputs from Master (Driven by Driver)
        output awid, awaddr, awlen, awsize, awburst, awlock,
               awcache, awprot, awqos, awregion, awvalid,
               wdata, wstrb, wlast, wvalid,
               bready,
               arid, araddr, arlen, arsize, arburst, arlock,
               arcache, arprot, arqos, arregion, arvalid,
               rready,

        // Inputs to Master (Driven by DUT/Slave)
        input  awready,
               wready,
               bid, bresp, bvalid,
               arready,
               rid, rdata, rresp, rlast, rvalid
    );

    // ==============================================
    // MONITOR MODPORT
    // ==============================================
    modport monitor (
        input aclk, aresetn,

        // All signals as inputs (passive observation)
        input awid, awaddr, awlen, awsize, awburst, awlock,
              awcache, awprot, awqos, awregion, awvalid, awready,

              wdata, wstrb, wlast, wvalid, wready,

              bid, bresp, bvalid, bready,

              arid, araddr, arlen, arsize, arburst, arlock,
              arcache, arprot, arqos, arregion, arvalid, arready,

              rid, rdata, rresp, rlast, rvalid, rready
    );

endinterface
