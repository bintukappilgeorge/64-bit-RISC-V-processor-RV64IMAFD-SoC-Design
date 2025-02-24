module floating_point_register_file (
    input wire         clk,
    input wire         reset,
    input wire         fwrite_en,   // Floating-point write enable
    input wire [4:0]   frs1,        // Source register 1
    input wire [4:0]   frs2,        // Source register 2
    input wire [4:0]   frd,         // Destination register
    input wire [63:0]  fdata_in,    // Data to write
    output wire [63:0] fdata_out1,  // Read data 1
    output wire [63:0] fdata_out2   // Read data 2
);

    // Define 32 floating-point registers
    reg [63:0] fregisters [31:0];

    // Initialize registers to zero on reset
    integer i;
    always @(posedge reset) begin
        for (i = 0; i < 32; i = i + 1)
            fregisters[i] <= 64'b0;
    end

    // Read registers
    assign fdata_out1 = fregisters[frs1];
    assign fdata_out2 = fregisters[frs2];

    // Write to register (except f0)
    always @(posedge clk) begin
        if (fwrite_en && frd != 5'b00000)
            fregisters[frd] <= fdata_in;
    end

endmodule
