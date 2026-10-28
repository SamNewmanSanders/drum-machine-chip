// White noise from a maximal length 16 bit LFSR (x^16 + x^14 + x^13 + x^11 + 1). Each sample it
// shifts one place and feeds the exclusive-or of four taps back in, so the top byte looks like a
// fresh random number every time. With a non-zero seed it never falls into a short cycle.
`default_nettype none

module ip_noise (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,       // sample tick: one new noise byte per tick
    output wire [7:0] out       // noise, 0 to 255
);
    reg [15:0] lfsr;

    // the feedback taps for a 16 bit maximal length sequence
    wire       fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    always @(posedge clk) begin
        if (!rst_n) lfsr <= 16'hACE1;            // any non-zero seed will do
        else if (en) lfsr <= {lfsr[14:0], fb};
    end

    assign out = lfsr[15:8];
endmodule
