module riscv64_soc (
    input wire         clk,
    input wire         reset,
    input wire [63:0]  instr_in,    // Instruction input
    input wire [63:0]  data_in,     // Data input from memory
    output wire [63:0] pc_out,      // Program counter output
    output wire [63:0] alu_result,  // ALU result output
    output wire [63:0] data_out,    // Data output to memory
    output wire        mem_write    // Memory write enable
);

    // -------------------------------------
    // Program Counter (PC) & Branch Prediction
    // -------------------------------------
    reg [63:0] pc;
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 64'h0000_0000_0000_0000;
        else
            pc <= pc + 4; // Basic Branch Prediction (Assume Not Taken)
    end
    assign pc_out = pc;

    // IF/ID Pipeline Registers
    reg [63:0] if_id_instr, if_id_pc;
    always @(posedge clk) begin
        if_id_instr <= instr_in;
        if_id_pc <= pc;
    end

    // -------------------------------------
    // Instruction Decode (ID) Stage
    // -------------------------------------
///////////////////////////////////////////////////////////////////////////    
    
    // Floating-Point Control and Status Register (FCSR)
    reg [7:0] fcsr; // [7:5] = frm (rounding mode), [4:0] = fflags (exception flags)
    wire [2:0] frm = fcsr[7:5];
    wire [4:0] fflags = fcsr[4:0]; // Exception flags
    
    // Floating-Point Register File Instance
    wire [63:0] fdata_out1, fdata_out2;
    reg [63:0] fdata_in;
    reg fwrite_en;
    
    floating_point_register_file fprf (
        .clk(clk),
        .reset(reset),
        .fwrite_en(fwrite_en),
        .frs1(rs1), 
        .frs2(rs2),
        .frd(rd),
        .fdata_in(fdata_in),
        .fdata_out1(fdata_out1),
        .fdata_out2(fdata_out2)
    );

    // Detect Floating-Point Instructions (opcode = 1010011 for RV64F/D)
    wire is_fp_instr = (opcode == 7'b1010011);
    wire is_csr_instr = (opcode == 7'b1110011);
///////////////////////////////////////////////////////////////////////////
    wire [6:0] opcode;
    wire [4:0] rs1, rs2, rd;
    wire [2:0] funct3;
    wire [6:0] funct7;
    
    assign opcode = if_id_instr[6:0];
    assign rd     = if_id_instr[11:7];
    assign funct3 = if_id_instr[14:12];
    assign rs1    = if_id_instr[19:15];
    assign rs2    = if_id_instr[24:20];
    assign funct7 = if_id_instr[31:25];
    
    // Handle CSR Instructions
    always @(posedge clk) begin
        if (is_csr_instr) begin
            case (funct3)
                3'b001: fcsr <= registers[rs1][7:0];  // FSCSR - Set full FCSR
                3'b010: registers[rd] <= {56'b0, fcsr}; // FRCSR - Read FCSR
                3'b011: fcsr[7:5] <= registers[rs1][2:0]; // FSCVTX - Set rounding mode (frm)
                3'b100: fcsr[4:0] <= fcsr[4:0] & ~registers[rs1][4:0]; // Clear specific exception flags
            endcase
        end
    end

    // Register File (32 registers, 64-bit)
    reg [63:0] registers [0:31];
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 64'b0;
    end

    wire [63:0] reg_data1, reg_data2;
    assign reg_data1 = registers[rs1];
    assign reg_data2 = registers[rs2];

    // ID/EX Pipeline Registers
    reg [63:0] id_ex_pc, id_ex_reg_data1, id_ex_reg_data2;
    reg [6:0]  id_ex_opcode;
    reg [4:0]  id_ex_rd;
    reg [2:0]  id_ex_funct3;
    reg [6:0]  id_ex_funct7;
    
    always @(posedge clk) begin
        id_ex_pc <= if_id_pc;
        id_ex_reg_data1 <= reg_data1;
        id_ex_reg_data2 <= reg_data2;
        id_ex_opcode <= opcode;
        id_ex_rd <= rd;
        id_ex_funct3 <= funct3;
        id_ex_funct7 <= funct7;
    end

    // -------------------------------------
    // Execute (EX) Stage - ALU with Forwarding
    // -------------------------------------
    reg [63:0] alu_out;
    wire [63:0] fpu_out;
    wire [4:0] fpu_fflags;
    wire is_fp_op = (id_ex_opcode == 7'b1010011); // RV64F/D Instructions
//////////////////////////////////////////////////////////////////////////////////////////    
    always @(posedge clk) begin
        if (is_fp_instr) begin
            id_ex_reg_data1 <= fdata_out1; // Forward FP operand 1
            id_ex_reg_data2 <= fdata_out2; // Forward FP operand 2
        end else begin
            id_ex_reg_data1 <= reg_data1;
            id_ex_reg_data2 <= reg_data2;
        end
    end
///////////////////////////////////////////////////////////////////////////////////////////
    // Instantiate the FPU Core
    fpu_core fpu_unit (
        .clk(clk),
        .reset(reset),
        .fop1(id_ex_reg_data1),
        .fop2(id_ex_reg_data2),
        .funct3(id_ex_funct3),
        .fresult(fpu_out),
        .fflags(fpu_fflags) 
    );

    always @(posedge clk) begin
        if (reset) begin
            fcsr <= 8'b0;  // Reset the FCSR register on reset
        end 
        else if (is_fp_op) begin
            fcsr[4:0] <= fcsr[4:0] | fpu_fflags; // Preserve previous exceptions (bitwise OR)
        end
    end
    always @* begin
        if (is_fp_op) begin
            alu_out = fpu_out; // Use FPU result for floating-point operations
        end else begin
            case ({id_ex_funct7, id_ex_funct3})
                10'b0000000000: alu_out = id_ex_reg_data1 + id_ex_reg_data2; // ADD
                10'b0100000000: alu_out = id_ex_reg_data1 - id_ex_reg_data2; // SUB
                10'b0000000111: alu_out = id_ex_reg_data1 & id_ex_reg_data2; // AND
                10'b0000000110: alu_out = id_ex_reg_data1 | id_ex_reg_data2; // OR
                10'b0000000100: alu_out = id_ex_reg_data1 ^ id_ex_reg_data2; // XOR
                10'b0000000001: alu_out = id_ex_reg_data1 << id_ex_reg_data2[5:0]; // SLL
                10'b0000000101: alu_out = id_ex_reg_data1 >> id_ex_reg_data2[5:0]; // SRL
            
                // RV64M (Multiplication & Division)
                10'b0000001000: alu_out = id_ex_reg_data1 * id_ex_reg_data2; // MUL
                10'b0000001001: alu_out = (id_ex_reg_data1 * id_ex_reg_data2) >> 64; // MULH
                10'b0000001100: alu_out = (id_ex_reg_data2 != 0) ? id_ex_reg_data1 / id_ex_reg_data2 : 0; // DIV
                10'b0000001101: alu_out = (id_ex_reg_data2 != 0) ? id_ex_reg_data1 % id_ex_reg_data2 : 0; // REM
            
                // RV64A (Atomic Instructions)
                10'b0000101011: alu_out = id_ex_reg_data1; // LR (Load Reserved)
                10'b0001101011: alu_out = (id_ex_reg_data1 == data_in) ? id_ex_reg_data2 : id_ex_reg_data1; // SC (Store Conditional)
                10'b0000100011: alu_out = id_ex_reg_data1 + data_in; // AMOADD
                10'b0110100011: alu_out = id_ex_reg_data1 ^ data_in; // AMOXOR
                10'b1110100011: alu_out = id_ex_reg_data1 & data_in; // AMOAND
            
                default: alu_out = 64'b0;
            endcase
        end
    end
    // EX/MEM Pipeline Registers
    reg [63:0] ex_mem_alu_out;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_is_fp;
    always @(posedge clk) begin
        ex_mem_alu_out <= alu_out;
        ex_mem_rd <= id_ex_rd;
        ex_mem_is_fp <= is_fp_op;
    end
    assign alu_result = ex_mem_alu_out;

    // -------------------------------------
    // Cache & Memory Subsystem
    // -------------------------------------
    reg [63:0] memory [0:65535];  // Main Memory
    wire [15:0] mem_address = ex_mem_alu_out[15:0];

    assign data_out = memory[mem_address];
    assign mem_write = (id_ex_opcode == 7'b0100011) ? 1 : 0; // Store instruction

    // MEM/WB Pipeline Registers
    reg [63:0] mem_wb_alu_out;
    reg [4:0]  mem_wb_rd;
    always @(posedge clk) begin
        mem_wb_alu_out <= ex_mem_alu_out;
        mem_wb_rd <= ex_mem_rd;
    end

    // -------------------------------------
    // Write Back (WB) Stage
    // -------------------------------------
    always @(posedge clk) begin
        if (mem_wb_rd != 5'b00000) // Avoid writing to x0 register
            registers[mem_wb_rd] <= mem_wb_alu_out;
    end
    
    always @(posedge clk) begin
        if (is_fp_instr && mem_wb_rd != 5'b00000) begin
            fwrite_en <= 1;
            fdata_in <= mem_wb_alu_out;
        end else begin
            fwrite_en <= 0;
        end
    end


endmodule
