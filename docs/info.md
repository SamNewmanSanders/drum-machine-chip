## How it works

One audio sample is made every 128 clocks, which is 195 kHz. Each voice advances a 16 bit phase accumulator and an envelope once per sample. A kick is a sine whose pitch falls from about 125 Hz to 80 Hz; a snare is two detuned sine tones plus white noise; a hi-hat is three inharmonic square waves mixed with dominant white noise. The voices are summed, centred on mid-scale and clipped to an 8 bit level, which drives a PWM output and a first order sigma-delta output.

## How to test

Pulse ui[0], ui[1] or ui[2] high to fire the kick, snare or hi-hat, and listen to uio[0], the PWM output, through an RC low-pass filter. uio[1] carries the same audio as a sigma-delta bitstream. The chip is audio only: there is no VGA and no screen.

## External hardware

An RC low-pass filter on uio[0] (a resistor and capacitor), and something to pulse a trigger pin, for example a push button or a microcontroller GPIO.
