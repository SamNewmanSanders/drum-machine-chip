// ip_kick -- a kick drum voice: a sine oscillator whose pitch drops quickly from about 125 Hz to
// 80 Hz, with a fast attack and an exponential decay. Fires on a rising edge of trigger and
// produces one signed sample per tick.
`default_nettype none

module ip_kick #(
    parameter integer ENV_SHIFT = 13
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              tick,
    input  wire              trigger,
    output wire signed [9:0] sample
);

    // --------------------------------------------------
    // Rising-edge detection
    // --------------------------------------------------
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

    // --------------------------------------------------
    // Sine oscillator
    //
    // Sample rate = 25 MHz / 128 = 195312.5 Hz
    //
    // Frequency = phase_step * sample_rate / 65536
    //
    // Initial phase step = 42 -> ~125 Hz
    // Final phase step   = 27 -> ~80 Hz
    //
    // Pitch falls over approximately 20 ms.
    // --------------------------------------------------
    reg [15:0] phase;
    reg [15:0] pitch;
    reg [7:0]  pitch_count;

    wire [7:0] sine;

    // 64-entry sine ROM (top 6 bits of phase)
    ip_rom_sine64 rom (
        .addr(phase[15:10]),
        .data(sine)
    );

    // pitch_count counts sample ticks; each time it reaches 255 the pitch is
    // decremented by one, sweeping it down from its initial value of 42 until it
    // reaches the final value of 27 (about 80 Hz).
    always @(posedge clk) begin
        if (!rst_n) begin
            phase       <= 16'd0;
            pitch       <= 16'd27;
            pitch_count <= 8'd0;
        end else if (fire) begin
            phase       <= 16'd0;
            pitch       <= 16'd42;
            pitch_count <= 8'd0;
        end else if (tick) begin
            phase <= phase + pitch;

            if (pitch_count == 8'd255) begin
                pitch_count <= 8'd0;

                if (pitch > 16'd27)
                    pitch <= pitch - 16'd1;
            end else begin
                pitch_count <= pitch_count + 8'd1;
            end
        end
    end

    // --------------------------------------------------
    // Amplitude envelope
    //
    // Fast attack followed by exponential decay.
    //
    // ENV_SHIFT = 13 gives approximately 42 ms
    // exponential time constant at 195312.5 Hz.
    // --------------------------------------------------
    reg [15:0] env;
    reg        attacking;

    always @(posedge clk) begin
        if (!rst_n) begin
            env       <= 16'd0;
            attacking <= 1'b0;
        end else if (fire) begin
            env       <= 16'd0;
            attacking <= 1'b1;
        end else if (tick) begin
            if (attacking) begin
                // Approximately 0.5 ms attack
                if (env >= 16'hBF00) begin
                    env       <= 16'hC000;
                    attacking <= 1'b0;
                end else begin
                    env <= env + 16'd512;
                end
            end else begin
                // Exponential decay with minimum step
                // to prevent the envelope freezing.
                if (env == 16'd0) begin
                    env <= 16'd0;
                end else if ((env >> ENV_SHIFT) == 0) begin
                    env <= env - 16'd1;
                end else begin
                    env <= env - (env >> ENV_SHIFT);
                end
            end
        end
    end

    // --------------------------------------------------
    // Convert unsigned sine to signed
    // --------------------------------------------------
    wire signed [8:0] sine_s =
        $signed({1'b0, sine}) - 9'sd128;

    // --------------------------------------------------
    // Apply amplitude envelope
    // --------------------------------------------------
    wire signed [17:0] product =
        sine_s * $signed({1'b0, env[15:10]});

    assign sample = product >>> 6;

endmodule

`default_nettype wire
