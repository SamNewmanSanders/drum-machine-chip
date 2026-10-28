// snare -- a snare drum voice: a short, bright burst of noise (the rattle) mixed with two tonal
// sine oscillators (the drum head), both shaped by a fast attack and exponential decay envelope.
// Fires on a rising edge of trigger and produces one signed sample per tick.
`default_nettype none

module ip_snare #(
    parameter integer ENV_SHIFT = 12
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              tick,
    input  wire              trigger,
    output wire signed [9:0] sample
);

    // Rising-edge detection
    reg t1, t2;
    wire fire = t1 & ~t2;

    always @(posedge clk) begin
        if (!rst_n) begin
            t1 <= 0;
            t2 <= 0;
        end else begin
            t1 <= trigger;
            t2 <= t1;
        end
    end

    // Two detuned sine tones (~152 Hz and ~277 Hz) form the body of the drum
    reg [15:0] phase_a;
    reg [15:0] phase_b;

    wire [7:0] sine_a;
    wire [7:0] sine_b;

    // 16-entry sine ROMs (top 4 bits of phase)
    ip_rom_sine16 rom_a (.addr(phase_a[15:12]), .data(sine_a));
    ip_rom_sine16 rom_b (.addr(phase_b[15:12]), .data(sine_b));

    always @(posedge clk) begin
        if (!rst_n) begin
            phase_a <= 0;
            phase_b <= 0;
        end else if (fire) begin
            phase_a <= 0;
            phase_b <= 0;
        end else if (tick) begin
            phase_a <= phase_a + 16'd51;
            phase_b <= phase_b + 16'd93;
        end
    end

    wire signed [9:0] tone_a =
        $signed({1'b0, sine_a}) - 10'sd128;

    wire signed [9:0] tone_b =
        $signed({1'b0, sine_b}) - 10'sd128;

    wire signed [10:0] tone = tone_a + tone_b;

    // The rattle: white noise, centred on zero
    wire [7:0] noise;

    ip_noise noise_gen (
        .clk(clk),
        .rst_n(rst_n),
        .en(tick),
        .out(noise)
    );

    wire signed [8:0] noise_s =
        $signed({1'b0, noise}) - 9'sd128;

    // Body plus a stronger rattle
    wire signed [11:0] mix = noise_s * 2 + tone;

    // Amplitude envelope with a short attack, then exponential decay
    reg [15:0] env;
    reg        attacking;

    always @(posedge clk) begin
        if (!rst_n) begin
            env       <= 0;
            attacking <= 0;
        end else if (fire) begin
            env       <= 0;
            attacking <= 1;
        end else if (tick) begin
            if (attacking) begin
                if (env >= 16'hBF00) begin
                    env       <= 16'hC000;
                    attacking <= 0;
                end else begin
                    env <= env + 16'd250;
                end
            end else begin
                env <= (env < (1 << ENV_SHIFT))
                     ? 0
                     : env - (env >> ENV_SHIFT);
            end
        end
    end

    // Apply the envelope
    wire signed [19:0] product =
        mix * $signed({1'b0, env[15:10]});

    // The shift here is 8, not the 6 used by ip_kick, and that extra 2 bits is not arbitrary: it
    // exists purely to undo the extra gain in `mix`. `mix` = noise_s * 2 + tone, i.e. the noise is
    // doubled AND two tones are added together, so it peaks at +-512 where the kick's plain sine
    // peaks at +-128. That is 4x bigger, and 4x is exactly 2 bits, hence 6 + 2 = 8.
    //
    // Check both voices land in the same place (both cap the envelope at env[15:10] = 48):
    //     kick : 128 * 48 / 2^6 = 96
    //     snare: 512 * 48 / 2^8 = 96
    // With a shift of 6 the snare would instead come out at 512 * 48 / 64 = 384, four times louder
    // than the kick, and a single snare hit would sit permanently clipped against the output.
    assign sample = product >>> 8;

endmodule

`default_nettype wire
