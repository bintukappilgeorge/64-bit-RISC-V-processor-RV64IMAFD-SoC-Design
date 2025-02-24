`timescale 1ns/1ps

module riscv_tb;
    reg clk, reset;
    reg [63:0] fop1, fop2;
    reg [2:0] funct3;
    wire [63:0] fresult;
    wire [4:0] fflags;

    reg [63:0] instr_in;
    reg [63:0] data_in;
    wire [63:0] pc_out;
    wire [63:0] alu_result;
    wire [63:0] data_out;
    wire mem_write;

    // Instantiate FPU Core
    fpu_core fpu (
        .clk(clk),
        .reset(reset),
        .fop1(fop1),
        .fop2(fop2),
        .funct3(funct3),
        .fresult(fresult),
        .fflags(fflags)
    );

    // Instantiate RISC-V SoC
    riscv64_soc dut (
        .clk(clk),
        .reset(reset),
        .instr_in(instr_in),
        .data_in(data_in),
        .pc_out(pc_out),
        .alu_result(alu_result),
        .data_out(data_out),
        .mem_write(mem_write)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, riscv_tb);

        clk = 0;
        reset = 1;
        instr_in = 0;
        data_in = 0;
        fop1 = 0;
        fop2 = 0;
        funct3 = 3'b000;

        #10 reset = 0; // Release reset

        // ------------------------
        // Floating Point Tests
        // ------------------------
        funct3 = 3'b000;
        fop1 = 64'h3FF8000000000000; // 1.5
        fop2 = 64'h4004000000000000; // 2.5
        #20;
        $display("FPU ADD: fresult = %h, fflags = %b", fresult, fflags);

        funct3 = 3'b011;
        fop1 = 64'h4024000000000000; // 10.0
        fop2 = 64'h4000000000000000; // 2.0
        #20;
        $display("FPU DIV: fresult = %h, fflags = %b", fresult, fflags);

        // ------------------------
        // RISC-V SoC Tests
        // ------------------------
        // ------------------------
        // Preload Register Values
        // ------------------------
         
        dut.registers[11] = 64'd20; // x11 = 20
        dut.registers[12] = 64'd15; // x12 = 15
        dut.registers[13] = 64'd30; // x13 = 30
        dut.registers[14] = 64'd50; // x14 = 50

        // ------------------------
        // Execute Instructions
        // ------------------------

        #10 instr_in = 64'h00c58533; // ADD x10, x11, x12 (x10 = 20 + 15)
        #10 instr_in = 64'h40C58533; // SUB x10, x11, x12 (x10 = 20 - 15)
        #10 instr_in = 64'h00000013; // NOP (ADDI x0, x0, 0)
        #10 instr_in = 64'h00B545B3; // XOR x11, x10, x11 (x11 = x10 XOR 20)
        #10 instr_in = 64'h00000013; // NOP (ADDI x0, x0, 0)
        #10 instr_in = 64'h00C5E633; // OR x12, x11, x12 (x12 = x11 OR 15)
        #10 instr_in = 64'h00D5F6B3; // AND x13, x11, x13 (x13 = x11 AND 30)
 
         // ------------------------
        // Multiply & Divide (M extension)
        // ------------------------
        #10 instr_in = 64'h02B50533; // MUL x10, x10, x11 (x10 = x10 * x11)
        #10 instr_in = 64'h02B51533; // MULH x10, x10, x11 (High part of signed multiplication)
        #10 instr_in = 64'h02B52533; // MULHSU x10, x10, x11 (Mixed signed/unsigned multiplication)
        #10 instr_in = 64'h02B53533; // MULHU x10, x10, x11 (High part of unsigned multiplication)
        #10 instr_in = 64'h02B54533; // DIV x10, x10, x11 (x10 = x10 / x11)
        #10 instr_in = 64'h02B55533; // DIVU x10, x10, x11 (Unsigned division)
        #10 instr_in = 64'h02B56533; // REM x10, x10, x11 (Remainder of division)
        #10 instr_in = 64'h02B57533; // REMU x10, x10, x11 (Unsigned remainder)
        
        #10 instr_in = 64'h1005202f; // LR.D x4, (x10)
        #10 instr_in = 64'h1805222f; // SC.D x4, x12, (x10)
        #10 instr_in = 64'h00c521af; // AMOSWAP.D x4, x12, (x10)
        #10 instr_in = 64'h00b522af; // AMOADD.D x4, x11, (x10)
        #10 instr_in = 64'h00c523af; // AMOAND.D x4, x12, (x10)
        #10 instr_in = 64'h00b524af; // AMOOR.D x4, x11, (x10)
        #10 instr_in = 64'h00b525af; // AMOMIN.D x4, x11, (x10)
        #10 instr_in = 64'h00b526af; // AMOMAX.D x4, x11, (x10)

        #100;
        $finish;
    end
endmodule
