package axi_coverage_pkg;

    // Import AXI shared types, enums, and transaction class
    import axi_pkg::*;

    // ============================================================
    // AXI Coverage Class - FIXED: Removed covergroup constructs
    // ============================================================
    class axi_coverage;
        
        // AXI transaction under observation
        axi_item observed_item;
        
        // Manual coverage counters to replace covergroup functionality
        int trans_write_count;
        int trans_read_count;
        int burst_fixed_count;
        int burst_incr_count;
        int burst_wrap_count;
        int single_burst_count;
        int short_burst_count;
        int med_burst_count;
        int long_burst_count;
        int byte_size_count;
        int halfword_count;
        int word_count;
        int resp_okay_count;
        int resp_exokay_count;
        int resp_slverr_count;
        int resp_decerr_count;
        int addr_aligned_count;
        int addr_unaligned_count;
        int low_addr_count;
        int mid_addr_count;
        int high_addr_count;
        int total_transactions;

        // ------------------------------------------------------------
        // Mailbox for collecting transactions
        // ------------------------------------------------------------
        mailbox #(axi_item) analysis_export;

        // ------------------------------------------------------------
        // Constructor
        // ------------------------------------------------------------
        function new(string name = "axi_coverage");
            analysis_export = new();
            // Initialize all counters
            trans_write_count = 0;
            trans_read_count = 0;
            burst_fixed_count = 0;
            burst_incr_count = 0;
            burst_wrap_count = 0;
            single_burst_count = 0;
            short_burst_count = 0;
            med_burst_count = 0;
            long_burst_count = 0;
            byte_size_count = 0;
            halfword_count = 0;
            word_count = 0;
            resp_okay_count = 0;
            resp_exokay_count = 0;
            resp_slverr_count = 0;
            resp_decerr_count = 0;
            addr_aligned_count = 0;
            addr_unaligned_count = 0;
            low_addr_count = 0;
            mid_addr_count = 0;
            high_addr_count = 0;
            total_transactions = 0;
        endfunction

        // ------------------------------------------------------------
        // Run Task - Collect transactions and sample coverage
        // ------------------------------------------------------------
        task run();
            forever begin
                axi_item t;
                analysis_export.get(t);
                write(t);
            end
        endtask

        // ------------------------------------------------------------
        // Write Function - Manual coverage sampling (replaces covergroup.sample())
        // ------------------------------------------------------------
        function void write(axi_item t);
            observed_item = t;
            total_transactions++;
            
            // Manual coverage collection - Transaction Type
            case (observed_item.trans_type)
                AXI_WRITE: trans_write_count++;
                AXI_READ:  trans_read_count++;
            endcase
            
            // Manual coverage collection - Burst Type
            case (observed_item.burst)
                FIXED: burst_fixed_count++;
                INCR:  burst_incr_count++;
                WRAP:  burst_wrap_count++;
                default: ; // RSVD case
            endcase
            
            // Manual coverage collection - Burst Length
            case (observed_item.len)
                0:        single_burst_count++;
                1,2,3,4:  short_burst_count++;
                5,6,7,8:  med_burst_count++;
                default:  long_burst_count++; // 9-15
            endcase
            
            // Manual coverage collection - Burst Size
            case (observed_item.size)
                SIZE_1B: byte_size_count++;
                SIZE_2B: halfword_count++;
                SIZE_4B: word_count++;
                default: ; // Other sizes
            endcase
            
            // Manual coverage collection - Response Type
            case (observed_item.resp)
                OKAY:   resp_okay_count++;
                EXOKAY: resp_exokay_count++;
                SLVERR: resp_slverr_count++;
                DECERR: resp_decerr_count++;
            endcase
            
            // Manual coverage collection - Address Alignment
            if ((observed_item.addr % 4) == 0)
                addr_aligned_count++;
            else
                addr_unaligned_count++;
                
            // Manual coverage collection - Address Range
            if (observed_item.addr <= 32'h0000_FFFF)
                low_addr_count++;
            else if (observed_item.addr <= 32'h7FFF_FFFF)
                mid_addr_count++;
            else
                high_addr_count++;
        endfunction

        // ------------------------------------------------------------
        // Report Function - Displays coverage results
        // ------------------------------------------------------------
        function void report();
            real write_coverage, read_coverage;
            real fixed_coverage, incr_coverage, wrap_coverage;
            real aligned_coverage, low_addr_coverage;
            
            if (total_transactions == 0) begin
                $display("=== AXI Coverage Report ===");
                $display("No transactions observed");
                $display("===========================");
                return;
            end
            
            // Calculate coverage percentages
            write_coverage = (trans_write_count > 0) ? 100.0 : 0.0;
            read_coverage = (trans_read_count > 0) ? 100.0 : 0.0;
            fixed_coverage = (burst_fixed_count > 0) ? 100.0 : 0.0;
            incr_coverage = (burst_incr_count > 0) ? 100.0 : 0.0;
            wrap_coverage = (burst_wrap_count > 0) ? 100.0 : 0.0;
            aligned_coverage = real'(addr_aligned_count) / real'(total_transactions) * 100.0;
            low_addr_coverage = real'(low_addr_count) / real'(total_transactions) * 100.0;
            
            $display("=== AXI Coverage Report ===");
            $display("Total Transactions: %0d", total_transactions);
            $display("");
            $display("Transaction Types:");
            $display("  Write: %0d (%.1f%%)", trans_write_count, write_coverage);
            $display("  Read:  %0d (%.1f%%)", trans_read_count, read_coverage);
            $display("");
            $display("Burst Types:");
            $display("  FIXED: %0d (%.1f%%)", burst_fixed_count, fixed_coverage);
            $display("  INCR:  %0d (%.1f%%)", burst_incr_count, incr_coverage);
            $display("  WRAP:  %0d (%.1f%%)", burst_wrap_count, wrap_coverage);
            $display("");
            $display("Burst Lengths:");
            $display("  Single:      %0d", single_burst_count);
            $display("  Short (1-4): %0d", short_burst_count);
            $display("  Med (5-8):   %0d", med_burst_count);
            $display("  Long (9-15): %0d", long_burst_count);
            $display("");
            $display("Burst Sizes:");
            $display("  1 Byte:  %0d", byte_size_count);
            $display("  2 Bytes: %0d", halfword_count);
            $display("  4 Bytes: %0d", word_count);
            $display("");
            $display("Responses:");
            $display("  OKAY:   %0d", resp_okay_count);
            $display("  EXOKAY: %0d", resp_exokay_count);
            $display("  SLVERR: %0d", resp_slverr_count);
            $display("  DECERR: %0d", resp_decerr_count);
            $display("");
            $display("Address Alignment:");
            $display("  Aligned:   %0d (%.1f%%)", addr_aligned_count, aligned_coverage);
            $display("  Unaligned: %0d (%.1f%%)", addr_unaligned_count, 100.0 - aligned_coverage);
            $display("");
            $display("Address Ranges:");
            $display("  Low:  %0d (%.1f%%)", low_addr_count, low_addr_coverage);
            $display("  Mid:  %0d", mid_addr_count);
            $display("  High: %0d", high_addr_count);
            $display("========================");
        endfunction
        
        // Helper function to get overall coverage percentage
        function real get_coverage();
            int covered_bins = 0;
            int total_bins = 12; // Approximate number of coverage bins
            
            if (trans_write_count > 0) covered_bins++;
            if (trans_read_count > 0) covered_bins++;
            if (burst_fixed_count > 0) covered_bins++;
            if (burst_incr_count > 0) covered_bins++;
            if (burst_wrap_count > 0) covered_bins++;
            if (single_burst_count > 0) covered_bins++;
            if (short_burst_count > 0) covered_bins++;
            if (byte_size_count > 0) covered_bins++;
            if (resp_okay_count > 0) covered_bins++;
            if (addr_aligned_count > 0) covered_bins++;
            if (low_addr_count > 0) covered_bins++;
            if (mid_addr_count > 0) covered_bins++;
            
            return (real'(covered_bins) / real'(total_bins)) * 100.0;
        endfunction

    endclass : axi_coverage

endpackage : axi_coverage_pkg
