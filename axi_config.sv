package axi_config_pkg;

  // Verbosity enum at package level
  typedef enum {
      NONE,
      LOW,
      MEDIUM,
      HIGH,
      DEBUG
  } verbosity_e;

  class axi_config;
      int unsigned ADDR_WIDTH = 32;
      int unsigned DATA_WIDTH = 32;
      int unsigned ID_WIDTH   = 4;
      int unsigned USER_WIDTH = 1;
      int unsigned STRB_WIDTH = DATA_WIDTH/8;

      bit enable_protocol_checks = 1;
      bit enable_coverage = 1;
      bit enable_logging = 1;
      bit enable_scoreboard = 1;

      int unsigned reset_duration = 100;
      int unsigned clock_period = 10;

      int unsigned num_transactions = 100;
      int unsigned max_outstanding = 4;
      bit enable_out_of_order = 0;

      bit [31:0] mem_start_addr = 32'h0000_0000;
      bit [31:0] mem_end_addr   = 32'h0FFF_FFFF;

      verbosity_e verbosity = MEDIUM;

      function new();
          STRB_WIDTH = DATA_WIDTH/8;
      endfunction

      function void print_config();
          $display("=== AXI Configuration ===");
          $display("ADDR_WIDTH: %0d", ADDR_WIDTH);
          $display("DATA_WIDTH: %0d", DATA_WIDTH);
          $display("ID_WIDTH: %0d", ID_WIDTH);
          $display("Protocol Checks: %0s", enable_protocol_checks ? "ON" : "OFF");
          $display("Coverage: %0s", enable_coverage ? "ON" : "OFF");
          $display("Logging: %0s", enable_logging ? "ON" : "OFF");
          $display("Transactions: %0d", num_transactions);
          $display("========================");
      endfunction
  endclass

endpackage
package axi_config_pkg;

  // Verbosity enum at package level
  typedef enum {
      NONE,
      LOW,
      MEDIUM,
      HIGH,
      DEBUG
  } verbosity_e;

  class axi_config;
      int unsigned ADDR_WIDTH = 32;
      int unsigned DATA_WIDTH = 32;
      int unsigned ID_WIDTH   = 4;
      int unsigned USER_WIDTH = 1;
      int unsigned STRB_WIDTH = DATA_WIDTH/8;

      bit enable_protocol_checks = 1;
      bit enable_coverage = 1;
      bit enable_logging = 1;
      bit enable_scoreboard = 1;

      int unsigned reset_duration = 100;
      int unsigned clock_period = 10;

      int unsigned num_transactions = 100;
      int unsigned max_outstanding = 4;
      bit enable_out_of_order = 0;

      bit [31:0] mem_start_addr = 32'h0000_0000;
      bit [31:0] mem_end_addr   = 32'h0FFF_FFFF;

      verbosity_e verbosity = MEDIUM;

      function new();
          STRB_WIDTH = DATA_WIDTH/8;
      endfunction

      function void print_config();
          $display("=== AXI Configuration ===");
          $display("ADDR_WIDTH: %0d", ADDR_WIDTH);
          $display("DATA_WIDTH: %0d", DATA_WIDTH);
          $display("ID_WIDTH: %0d", ID_WIDTH);
          $display("Protocol Checks: %0s", enable_protocol_checks ? "ON" : "OFF");
          $display("Coverage: %0s", enable_coverage ? "ON" : "OFF");
          $display("Logging: %0s", enable_logging ? "ON" : "OFF");
          $display("Transactions: %0d", num_transactions);
          $display("========================");
      endfunction
  endclass

endpackage

