// Testbench for archgen-single (single-cycle RV32I core)
// Provides clock/reset, memory loading, trace capture, and termination detection

`include "config.sv"
`include "constants.sv"

`timescale 1ns/1ps

module tb_top;

    //////////////////////////////////////////
    // Clock and reset
    //////////////////////////////////////////
    reg clock;
    reg reset;

    initial clock = 0;
    always #5 clock = ~clock; // 10ns period, 100MHz

    //////////////////////////////////////////
    // DUT instantiation
    //////////////////////////////////////////
    wire [31:0] bus_read_data;
    wire [31:0] bus_address;
    wire [31:0] bus_write_data;
    wire [3:0]  bus_byte_enable;
    wire        bus_read_enable;
    wire        bus_write_enable;
    wire [31:0] inst;
    wire [31:0] pc;

    toplevel dut (
        .clock          (clock),
        .reset          (reset),
        .bus_read_data  (bus_read_data),
        .bus_address    (bus_address),
        .bus_write_data (bus_write_data),
        .bus_byte_enable(bus_byte_enable),
        .bus_read_enable(bus_read_enable),
        .bus_write_enable(bus_write_enable),
        .inst           (inst),
        .pc             (pc)
    );

    //////////////////////////////////////////
    // Plusargs
    //////////////////////////////////////////
    string text_file;
    string data_file;
    string trace_log;
    string vcd_file;
    int    max_cycles;

    initial begin
        if (!$value$plusargs("text_file=%s", text_file)) begin
            $display("ERROR: +text_file=<path> not provided");
            $finish;
        end
        if (!$value$plusargs("data_file=%s", data_file))
            data_file = "";
        if (!$value$plusargs("trace_log=%s", trace_log))
            trace_log = "trace.log";
        if (!$value$plusargs("max_cycles=%d", max_cycles))
            max_cycles = 500000;
    end

    //////////////////////////////////////////
    // Memory loading via hierarchical access
    // InstMem: safe to load from TB (no always_ff driver)
    // DataMem: loaded via RTL's own initial $readmemh(DATA_HEX, mem)
    //          triggered by VCS +define+DATA_HEX=data_mem_file()
    //          with +data_file=<path> plusarg at runtime
    //////////////////////////////////////////
    initial begin
        // Wait for plusargs to be parsed
        #0;
        $display("[TB] Loading instruction memory from: %s", text_file);
        $readmemh(text_file, dut.instr_mem_inst.mem);
        // DataMem loaded by RTL's own mechanism (see config.sv + VCS +define)
    end

    //////////////////////////////////////////
    // Trace capture
    //////////////////////////////////////////
    integer trace_fd;
    int cycle_count;

    initial begin
        // Wait for plusargs
        #0;
        trace_fd = $fopen(trace_log, "w");
        if (trace_fd == 0) begin
            $display("ERROR: Cannot open trace log: %s", trace_log);
            $finish;
        end
    end

    // Single-cycle: trace on every clock edge where RegWrite is active
    // For single-cycle, the instruction executes in one cycle, so
    // we capture pc, inst, and register write at the same time
    always @(posedge clock) begin
        if (!reset && cycle_count > 0) begin
            // Log every committed instruction (RegWrite or not, for full trace)
            // But only log register writes for comparison with Spike
            if (dut.RegWrite && dut.rd != 5'b0) begin
                $fdisplay(trace_fd, "pc=%08x binary=%08x gpr=x%0d:%08x",
                          pc, inst, dut.rd, dut.Reg_write_data);
            end else begin
                $fdisplay(trace_fd, "pc=%08x binary=%08x",
                          pc, inst);
            end
        end
    end

    //////////////////////////////////////////
    // Cycle counter and termination
    //////////////////////////////////////////
    initial begin
        cycle_count = 0;
        // Reset sequence: 5 cycles
        reset = 1;
        repeat(5) @(posedge clock);
        reset = 0;
        $display("[TB] Reset released at cycle %0d", cycle_count);
    end

    always @(posedge clock) begin
        cycle_count <= cycle_count + 1;

        if (!reset) begin
            // ECALL detection (instruction == 0x00000073)
            if (inst == 32'h00000073) begin
                $display("[TB] ECALL detected at PC=%08x, cycle=%0d", pc, cycle_count);
                #10;
                $fclose(trace_fd);
                $finish;
            end

            // EBREAK detection (instruction == 0x00100073)
            if (inst == 32'h00100073) begin
                $display("[TB] EBREAK detected at PC=%08x, cycle=%0d", pc, cycle_count);
                #10;
                $fclose(trace_fd);
                $finish;
            end

            // Timeout
            if (cycle_count >= max_cycles) begin
                $display("[TB] TIMEOUT at cycle=%0d, PC=%08x", cycle_count, pc);
                $fclose(trace_fd);
                $finish;
            end
        end
    end

    //////////////////////////////////////////
    // VCS waveform dump
    //////////////////////////////////////////
    initial begin
        string fsdb_file;
        if ($value$plusargs("fsdb_file=%s", fsdb_file)) begin
            // FSDB dump if Verdi available
            // $fsdbDumpfile(fsdb_file);
            // $fsdbDumpvars(0, tb_top);
        end
        if ($value$plusargs("vcd_file=%s", vcd_file)) begin
            $dumpfile(vcd_file);
        end else begin
            $dumpfile("dump.vcd");
        end
        $dumpvars(0, tb_top);
    end

endmodule
