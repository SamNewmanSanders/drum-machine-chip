# Drum Machine

A three-voice analogue-style drum machine synthesised entirely in digital RTL, packaged for
[Tiny Tapeout](https://tinytapeout.com/). It makes a kick, a snare and a hi-hat from oscillators,
noise and envelopes — no sample memory, no DAC, just logic and two 1-bit pulse outputs that you
low-pass filter back into audio.

## What it does

- **Kick** (`ip_kick`) — a sine oscillator whose pitch falls quickly from about 125 Hz to 80 Hz,
  with a fast attack and an exponential decay. The thump.
- **Snare** (`ip_snare`) — two detuned sine tones (about 152 Hz and 277 Hz, the drum head) mixed
  with white noise (the wires), shaped by a fast attack and exponential decay.
- **Hi-hat** (`ip_hat`) — three inharmonic square waves plus noise, with a very fast decay.

The three voices are summed, centred on mid-scale, clipped, and sent to a PWM output and a
first-order sigma-delta output simultaneously.

## Hardware interface

The top module is `tt_um_drum_machine_wrapper` (`src/project.v`). It is audio only — there is no
VGA and no screen.

| Pin | Direction | Function |
|---|---|---|
| `ui_in[0]` | in | Kick trigger (level: a rising edge fires the voice) |
| `ui_in[1]` | in | Snare trigger |
| `ui_in[2]` | in | Hi-hat trigger |
| `ui_in[7:3]` | in | Unused |
| `uio[0]` | out | PWM audio output — listen here through an RC low-pass filter |
| `uio[1]` | out | Sigma-delta audio output — the same audio, a different encoding |
| `uo_out` | out | Unused (driven low) |

Pulse a trigger pin high and the corresponding voice fires on the rising edge. The clock is
`clk` (25 MHz) and reset is `rst_n`, active low.

## How it works

One audio sample is produced every `TICKDIV` clocks. With the default `TICKDIV = 128` and a
25 MHz clock, the sample rate is

\[
f_s = \frac{25\,000\,000}{128} = 195\,312.5\ \text{Hz}.
\]

`TICKDIV` could have been increased to 500 for a more realistic audio sampling frequency
(\(25\,\text{MHz}/500 = 50\ \text{kHz}\)), but the design works fine at the higher 195 kHz
rate simply by using lower relative pitch constants. Note that raising `TICKDIV` now would drop
every pitch by about \(128/500 \approx 0.26\) and stretch all envelope times by the same factor.

Each voice advances its phase and its envelope once per sample tick (`ip_tick`), and outputs one
signed sample per tick (0 when it is not sounding). The core sums them and converts to an
unsigned 8-bit level for the output stages.

### Phase accumulator

Each voice keeps its own 16-bit phase accumulator inline rather than using the provided module.

On each tick the phase advances by a fixed step and wraps around; the top bits of the phase
address a sine lookup table (`ip_rom_sine.v`, which holds three tables of 64, 32 and 16 entries).
The depth of each table is a balance between audio quality and die usage: a finer table means
quieter quantisation noise, while a coarser one uses less logic. The oscillator frequency is

\[
f_{\text{osc}} = \frac{\Delta\phi}{2^{16}}\, f_s .
\]

With \(f_s = 195\,312.5\) Hz that is about \(2.98\ \text{Hz}\) per unit of phase step.

### Amplitude envelope

Envelopes are fixed-width integers. Attack ramps the envelope up by a fixed increment each tick
until it reaches full scale, so a larger increment gives a faster attack. A softer (slower) attack
reduces the buzzing and harshness at the start of a kick, rising to full level gradually instead
of jumping there instantly.

Decay is an approximate exponential computed as

\[
E[n+1] = E[n] - (E[n] \gg \text{SHIFT}),
\]

with a small threshold that forces the tail to zero so it does not freeze at a low value. A
larger shift gives a longer decay, so the `ENV_SHIFT` parameter sets each voice's decay length.

Each voice multiplies its waveform by the top 6 bits of its envelope and shifts the product down
to size. See the module headers in `src/` for the exact constants per voice.

Only the top 6 bits reach the multiply: the lower bits mostly refine the decay tail, where the
difference is inaudible. A 16-bit envelope is probably more resolution than the multiply can
use, and a narrower one would save logic at little audible cost.

### White noise

The snare and hi-hat get their "rattle" from white noise, generated with a linear-feedback shift
register (LFSR): a 16-bit shift register that shifts one place every sample tick and feeds back
the XOR of a few taps (\(x^{16}+x^{14}+x^{13}+x^{11}+1\)). With a non-zero seed it runs through
every non-zero state before repeating, so the top 8 bits look like a fresh random byte each tick —
pseudo-random noise from a handful of gates and no memory.

## Voices

### Kick

The goal is a deep, round thump: a low sine that starts slightly higher and drops quickly in
pitch, with a fast attack and a medium decay.

`ip_kick` gets there with a single sine oscillator whose phase step sweeps downward (a falling
pitch), shaped by an exponential envelope.

### Snare

The goal is a bright, snappy hit: a noisy "rattle" (the wires) over two detuned tones that form
the drum head, ringing briefly.

`ip_snare` sums white noise from `ip_noise` with two sine tones read from the small sine ROM,
then shapes the mix with an exponential envelope.

### Hi-hat

The goal is a very short, metallic "tss": bright and noisy with almost no discernible pitch,
gone almost immediately.

`ip_hat` mixes three inharmonic square waves — their unrelated frequencies give the metallic
character — with white noise, under a fast, very short exponential envelope.

## Source files

| File | Role |
|---|---|
| `src/project.v` | Tiny Tapeout wrapper: pin mapping, audio-only output |
| `src/drum_machine_core.v` | Voice instantiates, mixing, level conversion |
| `src/ip_tick.v` | Sample-tick generator (one pulse every `DIV` clocks) |
| `src/ip_kick.v` | Kick voice |
| `src/ip_snare.v` | Snare voice |
| `src/ip_hat.v` | Hi-hat voice |
| `src/ip_noise.v` | White-noise source (16-bit maximal-length LFSR) |
| `src/ip_rom_sine.v` | Sine lookup tables: `ip_rom_sine64` / `ip_rom_sine32` / `ip_rom_sine16` |
| `src/ip_pwm.v` | PWM output stage |
| `src/ip_sigma_delta.v` | First-order sigma-delta output stage |

## Tuning

- `TICKDIV` in `drum_machine_core` sets the sample rate and, because the voices advance once per
  tick, the pitch *and* the envelope times together. The voice constants were written for
  `TICKDIV = 128`.
- Each voice has an `ENV_SHIFT` parameter that sets its decay length: kick, snare and hat default
  to 13, 12 and 11. 
- Each voice reads a slice of its 16-bit phase into a sine table in `ip_rom_sine.v`: the kick
  uses the 64-entry table with `phase[15:10]` and the snare the 16-entry table with
  `phase[15:12]`. A finer table means quieter quantisation noise; a coarser one saves logic.
- The hat's `>>> 2` scaling in `drum_machine_core` brings its larger amplitude in line with the
  other two voices.

## Area and die size

This design now fits on a **1x2 Tiny Tapeout tile**. The
single biggest thing that bought the fit was shrinking the multipliers: each voice multiplies its
waveform by only the top 6 bits of its envelope (`env[15:10]`) rather than the full 16 bits, then
shifts the product back down to size. A 16x16 multiplier per voice would have been far too large;
a 9x6 (or 13x6) one is affordable. The low ten bits of the envelope barely change the decay tail
where the ear is concerned, so dropping them costs almost nothing audibly.

There is more area available if it were ever needed:

- **Smaller multipliers still.** The voice multipliers are already narrowed, but the widths are
  generous relative to the signals they carry, and could be trimmed further.
- **Narrower envelopes.** The envelope is 16 bits wide even though only 6 of those bits are ever
  used in the multiply. An 8- or 10-bit envelope feeding a proportionally smaller multiplier would
  save more, since most of the width is discarded anyway.
- **Shared noise generators.** `ip_snare` and `ip_hat` each instantiate their own `ip_noise` LFSR.
  One generator feeding both would save an LFSR's worth of registers and XOR gates, at the cost of
  correlating the two voices' noise.

I don't think this could realistically be squeezed from 1x2 down to 1x1, though. The signal generator
that this design grew out of already needed a 1x2 tile, and although parts of that were dropped
along the way (a `uart_rx`, for instance), this version *adds* things back: the kick's 64-entry sine
ROM in particular, which is what makes the kick sound like a kick rather than a buzz.

**A note on pitch:** in simulation the design runs slower, so every pitch comes out lower than on the
real chip — the simulated audio only reaches about 70% of the real pitch. The voice constants
were tuned by ear for the actual silicon, so the design is intended to sound right on hardware
rather than in simulation.
