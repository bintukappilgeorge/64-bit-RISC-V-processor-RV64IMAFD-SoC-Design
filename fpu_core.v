module fpu_core (
    input wire clk,
    input wire reset,
    input wire [63:0] fop1, // Floating-point operand 1
    input wire [63:0] fop2, // Floating-point operand 2
    input wire [2:0] funct3, // Function select (000=ADD, 001=SUB, 010=MUL, 011=DIV)
    output reg [63:0] fresult, // Floating-point result
    output reg [4:0] fflags // Floating-point exception flags
);

    wire [10:0] exp1, exp2;
    wire [51:0] mant1, mant2;
    wire sign1, sign2;

    assign sign1 = fop1[63];
    assign sign2 = fop2[63];
    assign exp1 = fop1[62:52];
    assign exp2 = fop2[62:52];
    assign mant1 = (exp1 != 0) ? {1'b1, fop1[51:0]} : {1'b0, fop1[51:0]}; // Normalize
    assign mant2 = (exp2 != 0) ? {1'b1, fop2[51:0]} : {1'b0, fop2[51:0]}; // Normalize

    reg [10:0] exp_res;
    reg [51:0] mant_res;
    reg sign_res;

    always @* begin
        fflags = 5'b00000; // Reset exception flags

        case (funct3)
            3'b000: begin // Floating-Point Addition
                if (exp1 > exp2) begin
                    mant_res = mant1 + (mant2 >> (exp1 - exp2));
                    exp_res = exp1;
                end else begin
                    mant_res = (mant1 >> (exp2 - exp1)) + mant2;
                    exp_res = exp2;
                end
                sign_res = sign1; 
            end

            3'b001: begin // Floating-Point Subtraction
                if (exp1 > exp2) begin
                    mant_res = mant1 - (mant2 >> (exp1 - exp2));
                    exp_res = exp1;
                end else begin
                    mant_res = (mant1 >> (exp2 - exp1)) - mant2;
                    exp_res = exp2;
                end
                sign_res = sign1;
            end

            3'b010: begin // Floating-Point Multiplication
                mant_res = (mant1 * mant2) >> 52;
                exp_res = exp1 + exp2 - 1023;
                sign_res = sign1 ^ sign2;
            end

            3'b011: begin // Floating-Point Division
                if (mant2 != 0) begin
                    mant_res = (mant1 << 52) / mant2;
                    exp_res = exp1 - exp2 + 1023;
                    sign_res = sign1 ^ sign2;
                end else begin
                    exp_res = 11'b11111111111; // Infinity
                    mant_res = 52'b0;
                    sign_res = sign1 ^ sign2;
                    fflags[1] = 1'b1; // Set Division by Zero flag
                end
            end

            default: begin
                mant_res = 52'b0;
                exp_res = 11'b0;
                sign_res = 1'b0;
            end
        endcase
    end

    // Handle NaN, Infinity, and Overflow/Underflow
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            fresult <= 64'b0;
            fflags <= 5'b00000;
        end else begin
            if (exp_res >= 2047) begin
                fresult <= {sign_res, 11'b11111111111, 52'b0}; // Infinity
                fflags[2] = 1'b1; // Overflow Exception
            end else if (exp_res == 0) begin
                fresult <= {sign_res, 11'b0, 52'b0}; // Underflow to zero
                fflags[3] = 1'b1; // Underflow Exception
            end else if ((exp1 == 2047 && mant1 != 0) || (exp2 == 2047 && mant2 != 0)) begin
                fresult <= {1'b0, 11'b11111111111, 52'b1}; // NaN (Quiet NaN)
                fflags[0] = 1'b1; // Invalid Operation
            end else begin
                fresult <= {sign_res, exp_res, mant_res[51:0]};
            end
        end
    end
endmodule
