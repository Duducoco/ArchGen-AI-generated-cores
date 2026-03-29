// Testbench for archgen-5pipe-stall (5-stage pipeline RV32I core)
// Provides clock/reset, memory loading, WB-stage trace capture, and termination detection

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
    // DataMem: loaded via RTL's own always_ff reset mechanism
    //          triggered by VCS +define+DATA_HEX_PATH=data_mem_file()
    //          with +data_file=<path> plusarg at runtime
    //////////////////////////////////////////
    initial begin
        #0;
        $display("[TB] Loading instruction memory from: %s", text_file);
        $readmemh(text_file, dut.inst_mem.mem);
        // DataMem loaded by RTL's own reset mechanism (see config.sv + VCS +define)
    end

    //////////////////////////////////////////
    // Trace capture from WB stage
    //////////////////////////////////////////
    // Pipeline core: capture trace at WB stage where we have
    // pc_WB, inst_WB, RegWrite_WB, rd_WB, wb_data_WB
    // These signals were added to Mem_WB_Reg for trace purposes

    integer trace_fd;
    int cycle_count;

    initial begin
        #0;
        trace_fd = $fopen(trace_log, "w");
        if (trace_fd == 0) begin
            $display("ERROR: Cannot open trace log: %s", trace_log);
            $finish;
        end
    end

    // WB stage signals (from modified Mem_WB_Reg)
    wire        wb_RegWrite = dut.RegWrite_WB;
    wire [4:0]  wb_rd       = dut.rd_WB;
    wire [31:0] wb_data     = dut.wb_data_WB;
    wire [31:0] wb_pc       = dut.mem_wb_reg.pc_WB;
    wire [31:0] wb_inst     = dut.mem_wb_reg.inst_WB;

    // Trace buffer: hold current WB instruction until PC changes.
    // When PC changes, flush the buffered entry (with gpr if captured).
    // This handles stall bubbles: a bubble has RegWrite=0, followed by the
    // real instruction with RegWrite=1 at the same PC.
    reg [31:0] buf_pc;
    reg [31:0] buf_inst;
    reg [4:0]  buf_rd;
    reg [31:0] buf_data;
    reg        buf_has_gpr;
    reg        buf_valid;

    initial begin
        buf_valid = 1'b0;
        buf_has_gpr = 1'b0;
    end

    task flush_trace_buf;
        if (buf_valid) begin
            if (buf_has_gpr)
                $fdisplay(trace_fd, "pc=%08x binary=%08x gpr=x%0d:%08x",
                          buf_pc, buf_inst, buf_rd, buf_data);
            else
                $fdisplay(trace_fd, "pc=%08x binary=%08x",
                          buf_pc, buf_inst);
        end
    endtask

    always @(posedge clock) begin
        if (!reset && cycle_count > 5) begin
            if (wb_pc != 32'b0 && wb_inst != 32'b0) begin
                if (wb_pc != buf_pc || !buf_valid) begin
                    // New instruction: flush old buffer, start new
                    flush_trace_buf();
                    buf_pc      <= wb_pc;
                    buf_inst    <= wb_inst;
                    buf_valid   <= 1'b1;
                    if (wb_RegWrite && wb_rd != 5'b0) begin
                        buf_has_gpr <= 1'b1;
                        buf_rd      <= wb_rd;
                        buf_data    <= wb_data;
                    end else begin
                        buf_has_gpr <= 1'b0;
                    end
                end else begin
                    // Same PC: update gpr if RegWrite just became active
                    if (wb_RegWrite && wb_rd != 5'b0 && !buf_has_gpr) begin
                        buf_has_gpr <= 1'b1;
                        buf_rd      <= wb_rd;
                        buf_data    <= wb_data;
                    end
                end
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
            // ECALL detection at WB stage
            if (wb_inst == 32'h00000073 && wb_pc != 32'b0) begin
                $display("[TB] ECALL detected at WB PC=%08x, cycle=%0d", wb_pc, cycle_count);
                flush_trace_buf();  // Flush last buffered entry
                #10;
                $fclose(trace_fd);
                $finish;
            end

            // EBREAK detection at WB stage
            if (wb_inst == 32'h00100073 && wb_pc != 32'b0) begin
                $display("[TB] EBREAK detected at WB PC=%08x, cycle=%0d", wb_pc, cycle_count);
                flush_trace_buf();
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
    string vcd_file;
    initial begin
        if ($value$plusargs("vcd_file=%s", vcd_file)) begin
            $dumpfile(vcd_file);
        end else begin
            $dumpfile("dump.vcd");
        end
        $dumpvars(0, tb_top);
    end

endmodule
