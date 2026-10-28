// ip_hat -- a hi-hat voice: three inharmonic square waves mixed with white noise, shaped by a
// fast decaying envelope. Fires on a rising edge of trigger and produces one signed sample per tick.
`default_nettype none

module ip_hat #(
    parameter integer ENV_SHIFT = 11
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              tick,
    input  wire              trigger,
    output wire signed [12:0] sample
);

    // Rising-edge detection
    reg t1, t2;
    wire fire = t1 & ~t2;

    always @(posedge clk) begin
        if (!rst_n) begin
            t1 <= 1'b0;
            t2 <= 1'b0;
        end else begin
            t1 <= trigger;
            t2 <= t1;
        end
    end

    // Fast decaying amplitude envelope
    reg [15:0] env;

    always @(posedge clk) begin
        if (!rst_n)
            env <= 16'd0;
        else if (fire)
            env <= 16'hFF00;
        else if (tick)
            env <= (env < (1 << ENV_SHIFT))
                 ? 16'd0
                 : env - (env >> ENV_SHIFT);
    end

    // White noise, centred on zero
    wire [7:0] noise;

    ip_noise noise_gen (
        .clk(clk),
        .rst_n(rst_n),
        .en(tick),
        .out(noise)
    );

    wire signed [8:0] noise_s =
        $signed({1'b0, noise}) - 9'sd128;

    // Three inharmonic square waves
    reg [15:0] phase1, phase2, phase3;

    always @(posedge clk) begin
        if (!rst_n) begin
            phase1 <= 16'd0;
            phase2 <= 16'd0;
            phase3 <= 16'd0;
        end else if (tick) begin
            phase1 <= phase1 + 16'd884;
            phase2 <= phase2 + 16'd1470;
            phase3 <= phase3 + 16'd2388;
        end
    end

    wire signed [9:0] m1 =
        phase1[15] ? 10'sd64 : -10'sd64;

    wire signed [9:0] m2 =
        phase2[15] ? 10'sd64 : -10'sd64;

    wire signed [9:0] m3 =
        phase3[15] ? 10'sd64 : -10'sd64;

    wire signed [10:0] metallic = m1 + m2 + m3;

    // 87.5% noise, 12.5% metallic
    wire signed [11:0] mixed =
        (noise_s * 7 + metallic) >>> 3;

    wire signed [12:0] bright = mixed;

    // Apply hi-hat envelope
    wire signed [24:0] product =
        bright * $signed({1'b0, env[15:10]});

    assign sample = product >>> 6;

endmodule

// -------------------------------------------------------------------------------------------------
// NOTES ON THE NOISE / METALLIC BALANCE (the levels are asymmetric on purpose)
// -------------------------------------------------------------------------------------------------
// The two halves of this voice do not start at the same amplitude, and that is deliberate:
//
//     noise_s   = noise - 128   ->  spans -128 .. +127, i.e. +-128   (a full 8 bit byte)
//     m1, m2, m3 = phase[15] ? +64 : -64  ->  +-64 each, HALF the noise
//     metallic  = m1 + m2 + m3  ->  +-192 at a simultaneous peak
//
// They are then mixed as (noise_s * 7 + metallic) >>> 3, which gives:
//
//     noise     128 * 7 = 896  ->  +-112 after the >>3
//     metallic  192 * 1 = 192  ->  +-24  after the >>3
//     total                     +-136
//
// So the split is about 112 : 24, roughly 82% / 18% by amplitude (about 96% / 4% by power). Each
// individual square wave survives the shift as only +-8, i.e. about 1/14 of the noise peak.
//
// Why so noise heavy? Because that is what a hi-hat actually is: filtered noise with a faint
// metallic ring on top. Three equal square waves would sum into a buzzy ring-mod tone that sounds
// like a robot, not a cymbal. The +-64 choice also keeps metallic (192) comfortably under the noise
// term (896), so the square waves can never dominate or push `mixed` outside the 12 bit bus.
//
// One correction to the inline comment above: "87.5% noise, 12.5% metallic" refers to the 7:1
// WEIGHTS, not to the resulting amplitude. Read as amplitude the real split is 82% / 18%, because
// the metallic term starts out 1.5x larger (192 vs 128) before it is weighted.
//
// Also note the three squares share unrelated phase increments (884 / 1470 / 2388), so in RMS terms
// they add as sqrt(3) rather than 3x. In practice the metallic contribution is nearer +-11 than
// +-24 -- the tone is even more of a hint than the peak figures suggest, which is the intent.
// -------------------------------------------------------------------------------------------------

`default_nettype wire
