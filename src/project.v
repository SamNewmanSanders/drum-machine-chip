// The Tiny Tapeout top module for the drum machine. Audio only: no VGA, no screen.
//
//   ui_in[0]    kick trigger
//   ui_in[1]    snare trigger
//   ui_in[2]    hat trigger
//   uio[0]      the audio output: the sound you listen to (RC low pass filter)
//   uio[1]      the sigma delta output: the same audio, made a different way
//   uo_out      unused
//
// Trigger a voice on its ui_in pin and listen to uio[0].
`default_nettype none

module tt_um_samnewmansanders_drum_machine (
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // bidirectional pins, input path
    output wire [7:0] uio_out,  // bidirectional pins, output path
    output wire [7:0] uio_oe,   // bidirectional pins, 1 = drive
    input  wire       ena,      // high when the design is powered, ignore
    input  wire       clk,      // clock
    input  wire       rst_n     // reset, active low
);
    wire       pwm, sd;

    drum_machine_core core (
        .clk(clk), .rst_n(rst_n),
        .kick(ui_in[0]), .snare(ui_in[1]), .hat(ui_in[2]),
        .pwm(pwm), .sd(sd)
    );

    // Audio only. No VGA sync, no picture: the template's screen is gone.
    assign uo_out  = 8'b0;
    assign uio_out = {6'd0, sd, pwm};
    assign uio_oe  = 8'b0000_0011;

    wire _unused = &{ena, uio_in, ui_in[7:3], 1'b0};
endmodule
