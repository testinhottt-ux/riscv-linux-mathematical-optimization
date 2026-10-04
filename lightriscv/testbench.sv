module testbench();
  logic clk, reset, memwrite;
  logic [31:0] writedata, addr, readdata, pc, instr;

  // Von Neumann architecture
  `ifdef COMPACT
    initial $display("### Compiling for Compact Monolithic Multicycle (Menotti 37:29) ###");
    riscvmulti_compact cpu(clk, reset, addr, writedata, memwrite, readdata);
    mem #("von_neumann.hex") mem(clk, memwrite, addr, writedata, readdata);
  `elsif MULTI
    initial $display("### Compiling for Von Neumann architecture ###");
    riscvmulti cpu(clk, reset, addr, writedata, memwrite, readdata);
    mem #("von_neumann.hex") mem(clk, memwrite, addr, writedata, readdata);
  `else
  // Harvard architecture
    initial $display("### Compiling for Harvard architecture ###");
    riscvmono cpu(clk, reset, pc, instr, addr, writedata, memwrite, readdata);
    mem #("harvard_text.hex") instr_rom(.a(pc), .rd(instr));
    mem #("harvard_data.hex") data_ram(clk, memwrite, addr, writedata, readdata);
  `endif

  // initialize test
  initial
    begin
      $dumpfile("dump.vcd"); $dumpvars(0);
      reset <= 1; #20 reset <= 0;
      `ifdef COMPACT
        $monitor("time=%5t, pc=%h, instr=%h, state=%4b, SrcA=%h, SrcB=%h, ALUResult=%h", $time, cpu.PC, cpu.Instr, cpu.state, cpu.SrcA, cpu.SrcB, cpu.ALUResult);
        $writememh("registers.out", cpu.RegisterFile);
        $writememh("von_neumann.out", mem.RAM);
        #12000;
      `elsif MULTI
        $monitor("time=%5t, pc=%h, instr=%h, state=%4b, SrcA=%h, SrcB=%h, ALUResult=%h", $time, cpu.dp.pc, cpu.dp.instrreg.q, cpu.c.md.state, cpu.dp.alu.a, cpu.dp.alu.b, cpu.dp.alu.result); // multicycle
        $writememh("registers.out", cpu.dp.rf.rf);
        $writememh("von_neumann.out", mem.RAM);
        #12000;
      `else
        $monitor("time=%4t, pc=%h, instr=%h, SrcA=%h, SrcB=%h, ALUResult=%h", $time, pc, instr, cpu.SrcA, cpu.SrcB, cpu.ALUResult); // singlecycle
        $writememh("registers.out", cpu.RegisterFile);
        $writememh("harvard_data.out", data_ram.RAM);
        #3000;
      `endif
      $finish;
    end

  // generate clock to sequence tests
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
    end

  // check results
  always @(negedge clk)
    if (memwrite) begin
      `ifdef COMPACT
        if (addr>>2 === 32'h0000006e && writedata === 32'h6d73e55f) begin
          #10 $display("Compact Multi-cycle simulation succeeded!");
          $writememh("registers.out", cpu.RegisterFile);
          $writememh("harvard_data.out", mem.RAM);
          $finish;
        end
      `elsif MULTI
        if (addr>>2 === 32'h0000006f && writedata === 32'h6d73e55f) begin
          #10 $display("Multi-cycle simulation succeeded!");
          $writememh("registers.out", cpu.dp.rf.rf);
          $writememh("harvard_data.out", mem.RAM);
          $finish;
        end
      `else
        if (addr>>2 === 32'h0000002e && writedata === 32'h6d73e55f) begin
          #10 $display("Single-cycle simulation succeeded!");
          $writememh("registers.out", cpu.RegisterFile);
          $writememh("harvard_data.out", data_ram.RAM);
          $finish;
        end
      `endif
    end
endmodule