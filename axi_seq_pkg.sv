// =============================================================
// AXI Sequence Package
// =============================================================
package axi_seq_pkg;

  // Import required base packages
  import axi_pkg::*;
  import axi_config_pkg::*;
  import axi_logger_pkg::*;
  import axi_agent_pkg::*;

  // Include sequence class files (classes only, no package keyword inside them)
  `include "axi_seq_smoke.sv"
  `include "axi_seq_rand.sv"
  `include "axi_seq_burst.sv"

endpackage : axi_seq_pkg

