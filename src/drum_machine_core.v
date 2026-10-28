// The drum machine core: one voice per trigger. kick, snare and hat are all wired up. One audio
// sample is made every TICKDIV clocks and leaves as a PWM bitstream on pwm and as a sigma delta
// bitstream on sd.
`default_nettype none

module drum_machine_core #(
    // Clocks per audio sample. This sets the sample rate AND the rate at which the voices advance
    // their phase and envelope, so the pitch and the envelope times are tuned around it:
    //   25 MHz / 128 = 195 kHz, which is what the voice constants were written for (kick ~150 Hz,
    //   snare tones ~180/330 Hz, ~5 ms attack). A larger value slows everything down together.
    parameter TICKDIV = 128
) (
    input  wire       clk,
    input  wire       rst_n,

    // Drum triggers
    input  wire       kick,      // key 0
    input  wire       snare,     // key 1
    input  wire       hat,       // key 2

    // Audio outputs
    output wire       pwm,
    output wire       sd
);

    // One audio sample every TICKDIV clocks
    wire tick;
    ip_tick #(.DIV(TICKDIV)) sample_tick (.clk(clk), .rst_n(rst_n), .en(1'b1), .tick(tick));

    // The voices. Each fires on the rising edge of its trigger and gives one signed sample per tick.
    // When it is not sounding the sample is 0.
    wire signed [9:0] kick_sample;
    ip_kick kick_voice (
        .clk(clk), .rst_n(rst_n), .tick(tick), .trigger(kick), .sample(kick_sample)
    );

    wire signed [9:0] snare_sample;
    ip_snare snare_voice (
        .clk(clk), .rst_n(rst_n), .tick(tick), .trigger(snare), .sample(snare_sample)
    );

    wire signed [12:0] hat_sample;
    ip_hat hat_voice (
        .clk(clk), .rst_n(rst_n), .tick(tick), .trigger(hat), .sample(hat_sample)
    );

    // ---------------------------------------------------------------------------------------------
    // MIX LEVELS -- why the hat is scaled down before the sum (read this before changing anything)
    // ---------------------------------------------------------------------------------------------
    // Every voice does the same arithmetic, it just does it with different constants:
    //
    //     sample = (waveform x env[15:10]) >>> SHIFT
    //
    // where env[15:10] is the top 6 bits of the 16 bit envelope and SHIFT is the right shift baked
    // into that voice. So the biggest sample a voice can ever output is
    //
    //     peak = (waveform peak) x (env[15:10] max) / 2^SHIFT
    //
    // The catch is that env[15:10] max is NOT 63 for all of them, because each voice's envelope is
    // allowed to climb to a different ceiling. THAT is what actually sets the volume of a voice:
    //
    //   Kick  : the attack stops the envelope at 16'hC000, and 16'hC000 >> 10 = 48, not 63. So its
    //           scale factor is 48/64 = 0.75. Waveform peak is +-128, SHIFT is 6:
    //               128 x 48 / 64 = +-96
    //   Snare : same 0xC000 ceiling -> 48, but it shifts by 8 instead of 6, and its pre-envelope
    //           mix peaks at +-512 (noise x2 plus the two tones). So:
    //               512 x 48 / 256 = +-96      -- engineered to match the kick exactly.
    //   Hat   : no attack ramp at all, it jumps straight to 16'hFF00, so env[15:10] = 63 = true
    //           full scale. Its pre-envelope "bright" signal peaks at about +-136 (noise x7 plus
    //           the three square waves, all >>3), and SHIFT is 6:
    //               136 x 63 / 64 = about +-134
    //
    // So the voices deliberately do NOT come out at the same level: the drums are envelope-limited
    // to 0.75 of full scale, the hat is not limited at all, and the mixer has to correct for that.
    //
    // So why shift the hat down at all? Mainly because it sounds better. The hat is bright and
    // noise-dense, so it cuts through the mix far more than its raw peak suggests -- left at full
    // level it dominates and sounds harsh.
    //
    // The headroom part: all three voices share one output, and the sum can only overflow if a kick,
    // a snare and a hat all hit their positive peak in the same sample. They are triggered at
    // different times and decay at different rates, so that constructive worst case is RARE. Rather
    // than build the whole mix around it and make everything quiet, we trim the hat and let the
    // saturator in the duty calculation clamp the occasional coincident hit. The signal stays loud,
    // and on the rare peak it clips briefly instead of wrapping round.
    //
    // >>> 2 is an arithmetic shift, so it sign-extends and keeps the 13 bit signed width: it is a
    // pure volume trim on one voice, not a rescaling of the bus.
    //
    //
    // THIS IS VERY MESSY - three voices each tuned by hand against a different
    // envelope ceiling, a different waveform gain and a different shift.
    // But it sounds ok and fits on die so I will keep.
    // ---------------------------------------------------------------------------------------------
    
    wire signed [12:0] hat_mix = hat_sample >>> 2;

    // Sum the voices with headroom. The three voices fit a 13 bit signed bus with room to spare.
    wire signed [12:0] mix = kick_sample + snare_sample + hat_mix;

    // The voices are signed and centred on zero, but the DACs want an unsigned 8 bit level. Add 128
    // to centre it, then clip so a loud hit saturates instead of wrapping round.
    wire signed [12:0] centred = mix + 13'sd128;
    wire        [7:0]  duty    = (centred > 13'sd255) ? 8'd255 :
                                 (centred < 13'sd0)   ? 8'd0   :
                                                        centred[7:0];

    ip_pwm         pwm_out (.clk(clk), .rst_n(rst_n), .duty(duty), .out(pwm));
    ip_sigma_delta sd_out  (.clk(clk), .rst_n(rst_n), .in(duty),   .out(sd));
endmodule
