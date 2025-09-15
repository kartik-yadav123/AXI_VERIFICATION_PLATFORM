package axi_logger_pkg;

    // Import other packages required by the logger
    import axi_config_pkg::*;
    import axi_pkg::*;

    // ============================================================
    // AXI Logger Class
    // ============================================================
    class axi_logger;

        // -------------------------
        // Members
        // -------------------------
        string log_file;
        int log_fd;
        axi_config_pkg::axi_config cfg;

        // -------------------------
        // Logging levels
        // -------------------------
        typedef enum {
            INFO,
            WARNING,
            ERROR,
            DEBUG,
            PROTOCOL
        } log_level_e;

        // -------------------------
        // Constructor
        // -------------------------
        function new(string filename, axi_config_pkg::axi_config cfg_param);
            log_file = filename;
            cfg = cfg_param;
            log_fd = $fopen(log_file, "w");
            if (log_fd == 0) begin
                $error("Failed to open log file: %s", log_file);
            end
            log_transaction(INFO, "AXI Logger initialized");
        endfunction

        // -------------------------
        // General logging function
        // -------------------------
        function void log_transaction(log_level_e level, string msg);
            string level_str;
            string timestamp;

            case(level)
                INFO:     level_str = "INFO";
                WARNING:  level_str = "WARN";
                ERROR:    level_str = "ERROR";
                DEBUG:    level_str = "DEBUG";
                PROTOCOL: level_str = "PROTOCOL";
                default:  level_str = "UNKNOWN";
            endcase

            timestamp = $sformatf("%0t", $time);

            if (cfg == null || should_log(level)) begin
                $display("[%s] %s: %s", timestamp, level_str, msg);
                if (log_fd != 0) begin
                    $fwrite(log_fd, "[%s] %s: %s\n", timestamp, level_str, msg);
                    $fflush(log_fd);
                end
            end
        endfunction

        // -------------------------
        // Determine if log should be printed
        // -------------------------
        function bit should_log(log_level_e level);
            if (cfg == null) return 1;

            case(cfg.verbosity)
                NONE:    return (level == ERROR);
                LOW:     return (level == ERROR || level == WARNING);
                MEDIUM:  return (level != DEBUG);
                HIGH:    return 1;
                DEBUG:   return 1;
                default: return 1;
            endcase
        endfunction

        // -------------------------
        // Write Transaction Logging
        // -------------------------
        function void log_write_transaction(bit [31:0] addr, bit [31:0] data, bit [3:0] id);
            string msg = $sformatf("WRITE: ADDR=0x%08x, DATA=0x%08x, ID=%0d", addr, data, id);
            log_transaction(INFO, msg);
        endfunction

        // -------------------------
        // Read Transaction Logging
        // -------------------------
        function void log_read_transaction(bit [31:0] addr, bit [31:0] data, bit [3:0] id);
            string msg = $sformatf("READ: ADDR=0x%08x, DATA=0x%08x, ID=%0d", addr, data, id);
            log_transaction(INFO, msg);
        endfunction

        // -------------------------
        // Close the log file
        // -------------------------
        function void close_log();
            if (log_fd != 0) begin
                log_transaction(INFO, "Closing AXI Logger");
                $fclose(log_fd);
            end
        endfunction

    endclass

endpackage : axi_logger_pkg

