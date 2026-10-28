// First order sigma delta: the same average as PWM, but the ones are spread out evenly.
// An accumulator adds the input every clock, and the carry out of it is the output.
`default_nettype none

module ip_sigma_delta (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] in,
    output reg        out
);
    reg  [7:0] acc;
    wire [8:0] sum = {1'b0, acc} + {1'b0, in};

    always @(posedge clk) begin
        if (!rst_n) begin
            acc <= 8'd0;
            out <= 1'b0;
        end else begin
            acc <= sum[7:0];
            out <= sum[8];
        end
    end
endmodule
