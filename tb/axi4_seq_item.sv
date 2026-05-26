`ifndef AXI4_SEQ_ITEM_SV
`define AXI4_SEQ_ITEM_SV
class axi4_seq_item extends uvm_sequence_item;
  `uvm_object_utils(axi4_seq_item)

  typedef enum logic { WRITE=1'b0, READ=1'b1 } kind_e;

  rand kind_e      kind;
  rand logic [3:0] id;
  rand logic [5:0] addr_word;   // word index 0-15, 6 bits for safety
  rand logic [1:0] burst_len;   // 0=1beat 1=2beats 2=4beats (keep small)
       logic [31:0] wdata [4];  // max 4 beats
       logic [31:0] rdata [4];
       logic [1:0]  bresp;

  // addr in bytes, always 4-byte aligned, stays in 64-byte window
  logic [31:0] addr;

  constraint c_addr_word { addr_word inside {[0:12]}; } // leave room for bursts
  constraint c_burst     { burst_len inside {2'b00, 2'b01, 2'b10}; }

  // Derived — call after randomize
  function void post_randomize();
    addr = {26'h0, addr_word, 2'b00};
    // make sure burst doesn't overflow 16 regs
    while ((addr_word + beats()) > 16) addr_word--;
    addr = {26'h0, addr_word, 2'b00};
    for (int i=0;i<4;i++) wdata[i] = $urandom();
  endfunction

  function int beats();
    case (burst_len)
      2'b00: return 1;
      2'b01: return 2;
      2'b10: return 4;
      default: return 1;
    endcase
  endfunction

  function logic [7:0] awlen_val();
    return beats() - 1;
  endfunction

  function new(string name="axi4_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s id=%0x addr=0x%08x beats=%0d",
      (kind==WRITE)?"WR":"RD", id, addr, beats());
  endfunction
endclass
`endif
