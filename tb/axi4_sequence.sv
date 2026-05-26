`ifndef AXI4_SEQUENCE_SV
`define AXI4_SEQUENCE_SV
class axi4_seq extends uvm_sequence #(axi4_seq_item);
  `uvm_object_utils(axi4_seq)
  int unsigned num_pairs = 200;

  function new(string name="axi4_seq");
    super.new(name);
  endfunction

  task body();
    axi4_seq_item wr, rd;
    `uvm_info("SEQ",$sformatf("Starting %0d write-read pairs",num_pairs),UVM_NONE)
    repeat(num_pairs) begin
      // WRITE
      wr = axi4_seq_item::type_id::create("wr");
      start_item(wr);
      if (!wr.randomize() with { kind==axi4_seq_item::WRITE; })
        `uvm_fatal("SEQ","randomize failed")
      finish_item(wr);

      // READ same address and length
      rd = axi4_seq_item::type_id::create("rd");
      start_item(rd);
      if (!rd.randomize() with {
        kind       == axi4_seq_item::READ;
        addr_word  == wr.addr_word;
        burst_len  == wr.burst_len;
      }) `uvm_fatal("SEQ","randomize failed")
      finish_item(rd);
    end
    `uvm_info("SEQ","All pairs complete",UVM_NONE)
  endtask
endclass
`endif
