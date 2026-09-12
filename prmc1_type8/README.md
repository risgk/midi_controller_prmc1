MIDI Controller PRMC-1 (type-8)
===============================

**Version 0.2.1 (2026-09-07)**

MIDI Controller made with PicoRuby/R2P2 by ISGK Instruments (Ryo Ishigaki)

Required Software
-----------------

- R2P2 PICORUBY 4.0.3 PICO2_W https://github.com/picoruby/picoruby/releases/tag/4.0.3
- R2P2 Web Terminal https://picoruby.org/terminal

Required Hardware
-----------------

- Raspberry Pi Pico 2 https://www.raspberrypi.com/products/raspberry-pi-pico-2/
- Grove Shield for Pi Pico https://wiki.seeedstudio.com/Grove-Starter-Kit-for-Raspberry-Pi-Pico/ (5V)
- M5Stack Unit 8Angle https://docs.m5stack.com/en/unit/8angle (I2C1)
- M5Stack Unit ByteSwitch https://docs.m5stack.com/en/unit/Unit%20ByteSwitch (I2C1)
- M5Stack Unit Dual Button https://docs.m5stack.com/en/unit/dual_button (D18)
- M5Stack Unit MIDI https://docs.m5stack.com/en/unit/Unit-MIDI (Separate Mode, UART1)

Usage
-----

- MIDI Channel: 1
    - Alternatively, 2 is used when the red button is pressed at the app startup
- Send and receive Start/Stop: true
    - Alternatively, false is used when the blue button is pressed at the app startup
- CH1 Knob: Root of Step 1 Chord, 1 - 32
    - 1 - 16: 1st - 16th degrees
    - 17 - 32: 1st - 16th degrees with alternative pattern (Up, Up & Down)
    - C3, D3, E3, F3, G3, A3, B3, C4, D4, E4, F4, G4, A4, B4, C5, D5 in C Major Scale
    - C3, D3, E3, E3, G3, A3, C4, C4, D4, E4, E4, G4, A4, C5, C5, D5 in C Major Pentatonic Scale
- CH2 Knob: Root of Step 2 Chord, Ditto
- CH3 Knob: Root of Step 3 Chord, Ditto
- CH4 Knob: Root of Step 4 Chord, Ditto
- CH5 Knob: Arpeggio Pattern, 1 - 32
    - Pattern 1 - 16: 8th Note
    - Pattern 17 - 32: 16th Note
    - Pattern 1 - 8, 17 - 24: Major Scale
        - Pattern 1, 17: Root + 3rd + 5th + 7th scale degrees, Up
        - Pattern 2, 18: Root + 3rd + 5th + 7th scale degrees, Up & Down
        - Pattern 3, 19: Root + 3rd + 5th scale degrees, Up
        - Pattern 4, 20: Root + 3rd + 5th scale degrees, Up & Down
        - Pattern 5, 21: Root + 5th + 7th + 10th scale degrees, Up
        - Pattern 6, 22: Root + 5th + 7th + 10th scale degrees, Up & Down
        - Pattern 7, 23: Root + 5th + 10th scale degrees, Up
        - Pattern 8, 24: Root + 5th + 10th scale degrees, Up & Down
    - Pattern 9 - 16, 25 - 32: Major Pentatonic Scale
        - Pattern 9, 25: Root + 3rd + 5th + 7th scale degrees, Up
        - Pattern 10, 26: Root + 3rd + 5th + 7th scale degrees, Up & Down
        - Pattern 11, 27: Root + 3rd + 5th scale degrees, Up
        - Pattern 12, 28: Root + 3rd + 5th scale degrees, Up & Down
        - Pattern 13, 29: Root + 4th + 7th + 10th scale degrees, Up
        - Pattern 14, 30: Root + 4th + 7th + 10th scale degrees, Up & Down
        - Pattern 15, 31: Root + 4th + 7th scale degrees, Up
        - Pattern 16, 32: Root + 4th + 7th scale degrees, Up & Down
- CH6 Knob: Diatonic Transpose, 1 - 8
    - 1st, 2nd, 3rd, 4th, 5th, 6th, 7th, 8th scale degrees in Major Scale
    - 1st, 2nd, 3rd, 3rd, 4th, 4th, 5th, 5th scale degrees in Major Pentatonic Scale
- CH7 Knob: Brightness (Cutoff), 0 - 64 - 127 (-64 - +0 - +63)
- CH8 Knob: BPM, 30 - 120 - 240
    - BPM setting is disabled when MIDI clock is received
    - BPM setting is enabled by turning the knob
- SW Switch: 0 to Stop Sequencer, 1 to Start Sequencer
- Blue Button: Transpose - (min: -24)
- Red Button: Transpose + (max: +24)
    - With the Blue Button pressed, press the Red Button to increment the program number from 0 to 7 (Program Change)
- Byte Switch: Sub-Step On/Off flags, 0 - 255
    - bit 7: Sub-Step 1 (and 9), ..., bit 0: Sub-Step 8 (and 16)

[MIDI Implementation Chart](./MIDI_Implementation_Chart.md)
----------------------------------------------------------

Known Issues
------------

- Calling methods such as `set_blue_led` sometimes result in an IOError (timeout)

Change History
--------------

- Version 0.2.1 (2026-09-07): Fix initial value of Sub-Step On/Off flags
- Version 0.2.0 (2026-08-26): Display current Sub-Step on Byte Switch LEDs
- Version 0.1.0 (2026-08-17): Initial release

License
-------

MIDI Controller PRMC-1 (type-8) by ISGK Instruments (Ryo Ishigaki) is marked with CC0 1.0.
To view a copy of this license, visit https://creativecommons.org/publicdomain/zero/1.0/
