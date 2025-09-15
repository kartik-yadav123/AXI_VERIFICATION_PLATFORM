import axi_pkg::*;

class axi_item;

    string name;

    
    // Transaction fields
    rand axi_trans_type_t trans_type;
    rand logic [AXI_ID_WIDTH-1:0] id;
    rand logic [AXI_ADDR_WIDTH-1:0] addr;
    rand logic [7:0] len;
    rand axi_size_t size;
    rand axi_burst_t burst;
    rand logic lock;
    rand logic [3:0] cache;
    rand logic [2:0] prot;
    rand logic [3:0] qos;
    rand logic [3:0] region;
    
    // Write data
    rand logic [AXI_DATA_WIDTH-1:0] data[];
    rand logic [AXI_STRB_WIDTH-1:0] strb[];
    
    // Response data
    axi_resp_t resp;
    logic [AXI_DATA_WIDTH-1:0] read_data[];
    
    // Constraints
    constraint c_valid_len { len inside {[0:255]}; }
    constraint c_valid_size { size inside {SIZE_1B, SIZE_2B, SIZE_4B, SIZE_8B}; }
    constraint c_valid_burst { burst inside {FIXED, INCR, WRAP}; }
    constraint c_aligned_addr { 
        (size == SIZE_1B) -> (addr % 1 == 0);
        (size == SIZE_2B) -> (addr % 2 == 0);
        (size == SIZE_4B) -> (addr % 4 == 0);
        (size == SIZE_8B) -> (addr % 8 == 0);
    }
    constraint c_data_size {
        data.size() == (len + 1);
        strb.size() == (len + 1);
    }
    constraint c_valid_strb {
        foreach(strb[i]) {
            strb[i] != 0; // At least one byte enable per beat
        }
    }

     

    function new(string name_in = "axi_item");
    name = name_in;   // Save the name in the class
endfunction

    
    // Post randomize to set default values
    function void post_randomize();
        if (data.size() != (len + 1)) begin
            data = new[len + 1];
            strb = new[len + 1];
            foreach(data[i]) begin
                if (!std::randomize(data[i])) $warning("Failed to randomize data");
                strb[i] = '1; // Enable all bytes by default
            end
        end
        if (trans_type == AXI_READ) begin
            read_data = new[len + 1];
        end
    endfunction
    
    function string convert2string();
        return $sformatf("AXI Item: type=%s, id=%0d, addr=%0h, len=%0d, size=%s, burst=%s",
            trans_type.name(), id, addr, len, size.name(), burst.name());
    endfunction
    
endclass