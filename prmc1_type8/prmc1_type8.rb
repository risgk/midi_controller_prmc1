require 'i2c'
require 'uart'

# options
MIDI_CHANNEL = 1
MIDI_CHANNEL_ALT = 2  # used when the red button is pressed at the app startup
SEND_RECV_START_STOP = true  # inverted when the blue button is pressed at the app startup
TRANSPOSE = 0  # min: -24, max: +24
GATE_TIME = 3  # min: 1, max: 6
NOTE_ON_VELOCITY = 100
NOTE_OFF_VELOCITY = 64
LED_ON_VALUE = 1
FOR_SAM2695 = true

class M5UnitAngle8
  # refs https://github.com/m5stack/M5Unit-8Angle
  ANGLE8_I2C_ADDR            = 0x43
  ANGLE8_ANALOG_INPUT_8B_REG = 0x10
  ANGLE8_DIGITAL_INPUT_REG   = 0x20
  ANGLE8_RGB_24B_REG         = 0x30

  def initialize(i2c:)
    @i2c = i2c
  end

  def prepare_to_get_analog_input(ch)
    @i2c.write(ANGLE8_I2C_ADDR, ANGLE8_ANALOG_INPUT_8B_REG + ch)
  rescue IOError => e
    p e
    retry
  end

  def get_analog_input
    @i2c.read(ANGLE8_I2C_ADDR, 1).getbyte(0)
  rescue IOError => e
    p e
    retry
  end

  def prepare_to_get_digital_input
    @i2c.write(ANGLE8_I2C_ADDR, ANGLE8_DIGITAL_INPUT_REG)
  rescue IOError => e
    p e
    retry
  end

  def get_digital_input
    @i2c.read(ANGLE8_I2C_ADDR, 1).getbyte(0)
  rescue IOError => e
    p e
    retry
  end

  def set_red_led(ch, value)
    @i2c.write(ANGLE8_I2C_ADDR, ANGLE8_RGB_24B_REG + ch * 4 + 0, value)
  rescue IOError => e
    p e
    retry
  end

  def set_green_led(ch, value)
    @i2c.write(ANGLE8_I2C_ADDR, ANGLE8_RGB_24B_REG + ch * 4 + 1, value)
  rescue IOError => e
    p e
    retry
  end

  def set_blue_led(ch, value)
    @i2c.write(ANGLE8_I2C_ADDR, ANGLE8_RGB_24B_REG + ch * 4 + 2, value)
  rescue IOError => e
    p e
    retry
  end
end

class M5UnitDualButton
  def initialize(gpio_blue_button:, gpio_red_button:)
    @button_blue = GPIO.new(gpio_blue_button, GPIO::IN)
    @button_red = GPIO.new(gpio_red_button, GPIO::IN)
  end

  def get_blue_button_input
    @button_blue.read == 1 ? 0 : 1
  end

  def get_red_button_input
    @button_red.read == 1 ? 0 : 1
  end
end

class M5UnitByteSwitch
  # refs https://github.com/m5stack/M5Unit-ByteButton/tree/main/examples/unit-byteSwitch
  BYTE_SWITCH_I2C_ADDR = 0x46
  UNIT_BYTE_STATUS_REG = 0x00
  UNIT_BYTE_RGB233_REG = 0x50

  def initialize(i2c:)
    @i2c = i2c
  end

  def prepare_to_get_switch_status
    @i2c.write(BYTE_SWITCH_I2C_ADDR, UNIT_BYTE_STATUS_REG)
  rescue IOError => e
    p e
    retry
  end

  def get_switch_status
    @i2c.read(BYTE_SWITCH_I2C_ADDR, 1).getbyte(0)
  rescue IOError => e
    p e
    retry
  end

  def set_led(ch, value)
    @i2c.write(BYTE_SWITCH_I2C_ADDR, UNIT_BYTE_RGB233_REG + 7 - ch, (value > 0) ? 0x80 : 0x00)
  rescue IOError => e
    p e
    retry
  end
end

class Midi
  # refs https://github.com/FortySevenEffects/arduino_midi_library
  def initialize(uart:)
    @uart = uart
  end

  def send_note_on(note_number, velocity, channel)
    @uart.write((0x90 + channel - 1).chr + note_number.chr + velocity.chr)
  end

  def send_note_off(note_number, velocity, channel)
    @uart.write((0x80 + channel - 1).chr + note_number.chr + velocity.chr)
  end

  def send_control_change(control_number, control_value, channel)
    @uart.write((0xB0 + channel - 1).chr + control_number.chr + control_value.chr)
  end

  def send_program_change(program_number, channel)
    @uart.write((0xC0 + channel - 1).chr + program_number.chr)
  end

  def send_clock
    @uart.write(0xF8.chr)
  end

  def send_start
    @uart.write(0xFA.chr)
  end

  def send_stop
    @uart.write(0xFC.chr)
  end

  def receive_byte
    @uart.read(1)&.getbyte(0)
  end
end

class Prmc1Core
  NUMBER_OF_STEPS = 4
  CLOCKS_PER_STEP = 96

  def initialize(midi:, midi_channel:, send_recv_start_stop:)
    @midi = midi
    @midi_channel = midi_channel
    @send_recv_start_stop = send_recv_start_stop
    @bpm = 120
    @root_degrees_candidate = []
    @root_degrees = @root_degrees_candidate
    @alternative_patterns_candidate = []
    @alternative_patterns = @alternative_patterns_candidate
    @arpeggio_intervals_candidate = []
    @arpeggio_intervals = @arpeggio_intervals_candidate
    @alternative_arpeggio_intervals_candidate = []
    @alternative_arpeggio_intervals = @alternative_arpeggio_intervals_candidate
    @step_division_candidate = 8
    @step_division = @step_division_candidate
    @sub_steps_of_on_bits_candidate = 0x00
    @sub_steps_of_on_bits = @sub_steps_of_on_bits
    @scale_is_pentatonic_candidate = false
    @scale_is_pentatonic = @scale_is_pentatonic_candidate
    @scale_notes = [nil,  48,  50,  52,  53,  55,  57,  59,
                          60,  62,  64,  65,  67,  69,  71,
                          72,  74,  76,  77,  79,  81,  83,
                          84,  86,  88,  89,  91,  93,  95,
                          96,  98, 100, 101, 103, 105, 107,
                         108, 110, 112, 113, 115, 117, 119,
                         120, 122, 124, 125, 127]
    @scale_notes_pentatonic = [nil,  48,  50,  52,  55,  57,
                                     60,  62,  64,  67,  69,
                                     72,  74,  76,  79,  81,
                                     84,  86,  88,  91,  93,
                                     96,  98, 100, 103, 105,
                                    108, 110, 112, 115, 117,
                                    120, 122, 124, 127]
    @playing = false
    @playing_note = nil
    @step = 0
    @clock = 0
    @usec = Time.now.usec
    @usec_remain = 0
    @step_status_bits = 0x0
    @sub_step_status_bits = 0x0
    @parameter_status_bits = 0x0
    @diatonic_transpose_candidate = 1
    @diatonic_transpose = @diatonic_transpose_candidate
    @transpose_candidate = TRANSPOSE
    @transpose = @transpose_candidate
    @synced_to_ext_clock = false
  end

  def process_sequencer
    byte = @midi.receive_byte
    case byte
    when 0xFA
      change_parameter(8, 1) if @send_recv_start_stop
    when 0xFC
      change_parameter(8, 0) if @send_recv_start_stop
    when 0xF8
      @synced_to_ext_clock = true
      on_midi_clock
    end

    return if @synced_to_ext_clock

    usec = Time.now.usec
    @usec_remain += (usec - @usec + 1_000_000) % 1_000_000
    @usec = usec
    usec_per_clock = 2_500_000 / @bpm
    while @usec_remain >= usec_per_clock
      @usec_remain -= usec_per_clock
      on_midi_clock
    end
  end

  def change_parameter(key, value)
    case key
    when 0..3
      @root_degrees_candidate[key] = ((value / 4) % 16) + 1
      @alternative_patterns_candidate[key] = ((value / 4) / 16 == 1) ? true : false
      set_parameter_status_with_flag((@root_degrees_candidate[key] - 1) % 7 + 1, @alternative_patterns_candidate[key])
    when 4
      arpeggio_pattern = value / 4 + 1

      case (arpeggio_pattern - 1) % 16 + 1
      when 1
        @arpeggio_intervals_candidate             = [1,  3,  5,  7,  1,  3,  5,  7,  1,  3,  5,  7,  1,  3,  5,  7]
        @alternative_arpeggio_intervals_candidate = [1,  3,  5,  7,  5,  3,  1,  3,  5,  7,  5,  3,  1,  3,  5,  7]
      when 2
        @arpeggio_intervals_candidate             = [1,  3,  5,  7,  5,  3,  1,  3,  5,  7,  5,  3,  1,  3,  5,  7]
        @alternative_arpeggio_intervals_candidate = [1,  3,  5,  7,  1,  3,  5,  7,  1,  3,  5,  7,  1,  3,  5,  7]
      when 3
        @arpeggio_intervals_candidate             = [1,  3,  5,  1,  3,  5,  1,  3,  5,  1,  3,  5,  1,  3,  5,  1]
        @alternative_arpeggio_intervals_candidate = [1,  3,  5,  3,  1,  3,  5,  3,  1,  3,  5,  3,  1,  3,  5,  3]
      when 4
        @arpeggio_intervals_candidate             = [1,  3,  5,  3,  1,  3,  5,  3,  1,  3,  5,  3,  1,  3,  5,  3]
        @alternative_arpeggio_intervals_candidate = [1,  3,  5,  1,  3,  5,  1,  3,  5,  1,  3,  5,  1,  3,  5,  1]
      when 5
        @arpeggio_intervals_candidate             = [1,  5,  7, 10,  1,  5,  7, 10,  1,  5,  7, 10,  1,  5,  7, 10]
        @alternative_arpeggio_intervals_candidate = [1,  5,  7, 10,  7,  5,  1,  5,  7, 10,  7,  5,  1,  5,  7, 10]
      when 6
        @arpeggio_intervals_candidate             = [1,  5,  7, 10,  7,  5,  1,  5,  7, 10,  7,  5,  1,  5,  7, 10]
        @alternative_arpeggio_intervals_candidate = [1,  5,  7, 10,  1,  5,  7, 10,  1,  5,  7, 10,  1,  5,  7, 10]
      when 7
        @arpeggio_intervals_candidate             = [1,  5, 10,  1,  5, 10,  1,  5, 10,  1,  5, 10,  1,  5, 10,  1]
        @alternative_arpeggio_intervals_candidate = [1,  5, 10,  5,  1,  5, 10,  5,  1,  5, 10,  5,  1,  5, 10,  5]
      when 8
        @arpeggio_intervals_candidate             = [1,  5, 10,  5,  1,  5, 10,  5,  1,  5, 10,  5,  1,  5, 10,  5]
        @alternative_arpeggio_intervals_candidate = [1,  5, 10,  1,  5, 10,  1,  5, 10,  1,  5, 10,  1,  5, 10,  1]
      when 9
        @arpeggio_intervals_candidate             = [1,  3,  5,  7,  1,  3,  5,  7,  1,  3,  5,  7,  1,  3,  5,  7]
        @alternative_arpeggio_intervals_candidate = [1,  3,  5,  7,  5,  3,  1,  3,  5,  7,  5,  3,  1,  3,  5,  7]
      when 10
        @arpeggio_intervals_candidate             = [1,  3,  5,  7,  5,  3,  1,  3,  5,  7,  5,  3,  1,  3,  5,  7]
        @alternative_arpeggio_intervals_candidate = [1,  3,  5,  7,  1,  3,  5,  7,  1,  3,  5,  7,  1,  3,  5,  7]
      when 11
        @arpeggio_intervals_candidate             = [1,  3,  5,  1,  3,  5,  1,  3,  5,  1,  3,  5,  1,  3,  5,  1]
        @alternative_arpeggio_intervals_candidate = [1,  3,  5,  3,  1,  3,  5,  3,  1,  3,  5,  3,  1,  3,  5,  3]
      when 12
        @arpeggio_intervals_candidate             = [1,  3,  5,  3,  1,  3,  5,  3,  1,  3,  5,  3,  1,  3,  5,  3]
        @alternative_arpeggio_intervals_candidate = [1,  3,  5,  1,  3,  5,  1,  3,  5,  1,  3,  5,  1,  3,  5,  1]
      when 13
        @arpeggio_intervals_candidate             = [1,  4,  7, 10,  1,  4,  7, 10,  1,  4,  7, 10,  1,  4,  7, 10]
        @alternative_arpeggio_intervals_candidate = [1,  4,  7, 10,  7,  4,  1,  4,  7, 10,  7,  4,  1,  4,  7, 10]
      when 14
        @arpeggio_intervals_candidate             = [1,  4,  7, 10,  7,  4,  1,  4,  7, 10,  7,  4,  1,  4,  7, 10]
        @alternative_arpeggio_intervals_candidate = [1,  4,  7, 10,  1,  4,  7, 10,  1,  4,  7, 10,  1,  4,  7, 10]
      when 15
        @arpeggio_intervals_candidate             = [1,  4,  7,  1,  4,  7,  1,  4,  7,  1,  4,  7,  1,  4,  7,  1]
        @alternative_arpeggio_intervals_candidate = [1,  4,  7,  4,  1,  4,  7,  4,  1,  4,  7,  4,  1,  4,  7,  4]
      when 16
        @arpeggio_intervals_candidate             = [1,  4,  7,  4,  1,  4,  7,  4,  1,  4,  7,  4,  1,  4,  7,  4]
        @alternative_arpeggio_intervals_candidate = [1,  4,  7,  1,  4,  7,  1,  4,  7,  1,  4,  7,  1,  4,  7,  1]
      end

      case (arpeggio_pattern - 1) % 16 + 1
      when 1..8
        @scale_is_pentatonic_candidate = false
      when 9..16
        @scale_is_pentatonic_candidate = true
      end

      case arpeggio_pattern
      when 1..16
        @step_division_candidate = 8
      when 17..32
        @step_division_candidate = 16
      end

      set_parameter_status((arpeggio_pattern - 1) % 8 + 1)
    when 5
      @diatonic_transpose_candidate = value / 16 + 1
      set_parameter_status((@diatonic_transpose_candidate - 1) % 7 + 1)
    when 6
      # filter cutoff
      @midi.send_control_change(0x4A, value, @midi_channel)

      if FOR_SAM2695
        @midi.send_control_change(0x63, 0x01, @midi_channel)
        @midi.send_control_change(0x62, 0x20, @midi_channel)
        @midi.send_control_change(0x06, value, @midi_channel)
      end

      set_parameter_status_with_center_mark(value)
    when 7
      @synced_to_ext_clock = false
      @bpm = value * 2 - 8
      @bpm = 240 if @bpm > 240
      @bpm = 30 if @bpm < 30
      set_parameter_status_with_center_mark(value)
    when 8
      if value > 0
        @midi.send_start if @send_recv_start_stop
        @playing = true
        @playing_note = nil
        @step = NUMBER_OF_STEPS - 1
        @clock = CLOCKS_PER_STEP - 1
      else
        @midi.send_stop if @send_recv_start_stop
        @playing = false
        @midi.send_note_off(@playing_note, NOTE_OFF_VELOCITY, @midi_channel) if !@playing_note.nil?
        set_step_status(0)
        set_sub_step_status(0)
      end
    when 9
      @transpose_candidate -= 1 if @transpose_candidate > -24 && value == 1
      set_parameter_status_for_transpose(@transpose_candidate)
    when 10
      @transpose_candidate += 1 if @transpose_candidate < +24 && value == 1
      set_parameter_status_for_transpose(@transpose_candidate)
    when 11
      reversed_value = ((value & 0xF0) >> 4) | ((value & 0x0F) << 4)
      reversed_value = ((reversed_value & 0xCC) >> 2) | ((reversed_value & 0x33) << 2)
      reversed_value = ((reversed_value & 0xAA) >> 1) | ((reversed_value & 0x55) << 1)
      @sub_steps_of_on_bits_candidate = reversed_value & 0xFF
      @parameter_status_bits = @sub_steps_of_on_bits_candidate
    end
  end

  def step_status_bits
    @step_status_bits
  end

  def sub_step_status_bits
    @sub_step_status_bits
  end

  def parameter_status_bits
    @parameter_status_bits
  end

  # private

  def on_midi_clock
    @midi.send_clock
    return if !@playing
    @clock += 1

    if @clock == CLOCKS_PER_STEP
      @clock = 0
      @root_degrees_candidate.each_with_index {|item, index| @root_degrees[index] = item }
      @alternative_patterns_candidate.each_with_index {|item, index| @alternative_patterns[index] = item }
      @arpeggio_intervals_candidate.each_with_index {|item, index| @arpeggio_intervals[index] = item }
      @alternative_arpeggio_intervals_candidate.each_with_index {|item, index| @alternative_arpeggio_intervals[index] = item }
      @step_division = @step_division_candidate
      @sub_steps_of_on_bits = @sub_steps_of_on_bits_candidate
      @scale_is_pentatonic = @scale_is_pentatonic_candidate
      @diatonic_transpose = @diatonic_transpose_candidate
      @transpose = @transpose_candidate
      @step += 1
      @step = 0 if @step == NUMBER_OF_STEPS
      set_step_status(@step + 1)
    end

    playing_note_old = @playing_note

    if @clock % (CLOCKS_PER_STEP / @step_division) == 0
      root = @root_degrees[@step]
      root = [1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 8, 9, 10, 11, 11, 12].at(root - 1) if @scale_is_pentatonic
      sub_step = @clock / (CLOCKS_PER_STEP / @step_division)
      set_sub_step_status((sub_step & 0x07) + 1)
      arpeggio_intervals = @arpeggio_intervals
      arpeggio_intervals = @alternative_arpeggio_intervals if @alternative_patterns[@step]
      interval = arpeggio_intervals[sub_step % arpeggio_intervals.length]
      @playing_note = nil
      scale_notes = @scale_notes
      scale_notes = @scale_notes_pentatonic if @scale_is_pentatonic
      diatonic_transpose = @diatonic_transpose
      diatonic_transpose = [1, 2, 3, 3, 4, 5, 6, 6].at(diatonic_transpose - 1) if @scale_is_pentatonic
      @playing_note = scale_notes[root + interval - 1 + diatonic_transpose - 1] + @transpose if
                      !root.nil? && !interval.nil? && ((1 << (sub_step % 8)) & @sub_steps_of_on_bits) > 0
      @playing_note = 127 if !@playing_note.nil? && @playing_note > 127
      @midi.send_note_on(@playing_note, NOTE_ON_VELOCITY, @midi_channel) if !@playing_note.nil?
    end

    if @clock % (CLOCKS_PER_STEP / @step_division) ==
       CLOCKS_PER_STEP * GATE_TIME / 6 / @step_division % (CLOCKS_PER_STEP / @step_division)
      @midi.send_note_off(playing_note_old, NOTE_OFF_VELOCITY, @midi_channel) if !@playing_note.nil? 
    end
  end

  def set_step_status(value)
    @step_status_bits = [0x0, 0x1, 0x2, 0x4, 0x8].at(value)
  end

  def set_sub_step_status(value)
    @sub_step_status_bits = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80].at(value)
  end

  def set_parameter_status(value)
    @parameter_status_bits = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80].at(value)
  end

  def set_parameter_status_with_flag(value, flag)
    @parameter_status_bits = [0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40].at(value) + (flag ? 0x80 : 0x00)
  end

  def set_parameter_status_with_center_mark(value)
    set_parameter_status(value / 16 + 1)
    @parameter_status_bits = 0x18 if value == 64
  end

  def set_parameter_status_for_transpose(value)
    @parameter_status_bits = [0x01, 0x03, 0x02, 0x06, 0x04, 0x08, 0x18, 0x10, 0x30, 0x20, 0x60, 0x40].at((value + 12) % 12)
  end
end

# setup
i2c1 = I2C.new(unit: :RP2040_I2C1, frequency: 400_000, sda_pin: 6, scl_pin: 7, timeout: 2)
angle8 = M5UnitAngle8.new(i2c: i2c1)
dual_button = M5UnitDualButton.new(gpio_blue_button: 18, gpio_red_button: 19)
byte_switch = M5UnitByteSwitch.new(i2c: i2c1)
uart1 = UART.new(unit: :RP2040_UART1, txd_pin: 4, rxd_pin: 5, baudrate: 31_250)
midi = Midi.new(uart: uart1)
current_inputs = [nil, nil, nil, nil, nil, nil, nil, nil, 0, 0, 0, 0]
current_inputs[9] = dual_button.get_blue_button_input
current_inputs[10] = dual_button.get_red_button_input
midi_channel = MIDI_CHANNEL
midi_channel = MIDI_CHANNEL_ALT if current_inputs[10] == 1
send_recv_start_stop = SEND_RECV_START_STOP
send_recv_start_stop = !send_recv_start_stop if current_inputs[9] == 1
prmc1_core = Prmc1Core.new(midi: midi, midi_channel: midi_channel, send_recv_start_stop: send_recv_start_stop)

current_program = 0

if FOR_SAM2695
  midi.send_program_change(0x51, midi_channel)

  # filter resonance
  midi.send_control_change(0x63, 0x01, midi_channel)
  midi.send_control_change(0x62, 0x21, midi_channel)
  midi.send_control_change(0x06, 0x7F, midi_channel)

  # envelope release time
  midi.send_control_change(0x63, 0x01, midi_channel)
  midi.send_control_change(0x62, 0x66, midi_channel)
  midi.send_control_change(0x06, 0x60, midi_channel)
end

led_builtin = GPIO.new(25, GPIO::OUT)
led_builtin.write(1)

# loop
loop do
  analog_input = 0
  digital_input = 0
  blue_button_input = 0
  red_button_input = 0

  [6, 0, 1, 2, 3, 4, 5, 6, 7].each do |ch|
    prmc1_core.process_sequencer
    angle8.prepare_to_get_analog_input(ch)
    prmc1_core.process_sequencer
    analog_input = angle8.get_analog_input

    if current_inputs[ch].nil? ||
       analog_input > current_inputs[ch] + 1 ||
       analog_input < current_inputs[ch] - 1
      current_inputs[ch] = analog_input
      prmc1_core.change_parameter(ch, 127 - current_inputs[ch] / 2)
    end
  end

  prmc1_core.process_sequencer
  angle8.prepare_to_get_digital_input
  prmc1_core.process_sequencer
  digital_input = angle8.get_digital_input

  if current_inputs[8] != digital_input
    current_inputs[8] = digital_input
    prmc1_core.change_parameter(8, current_inputs[8])
  end

  blue_button_input = dual_button.get_blue_button_input

  if current_inputs[9] != blue_button_input
    current_inputs[9] = blue_button_input
    prmc1_core.change_parameter(9, current_inputs[9])
  end

  red_button_input = dual_button.get_red_button_input

  if current_inputs[10] != red_button_input
    current_inputs[10] = red_button_input
    prmc1_core.change_parameter(10, current_inputs[10])

    if red_button_input == 1 && blue_button_input == 1
      current_program = (current_program + 1) & 0x07
      midi.send_program_change(current_program, midi_channel)
    end
  end

  prmc1_core.process_sequencer
  byte_switch.prepare_to_get_switch_status
  prmc1_core.process_sequencer
  switch_status = byte_switch.get_switch_status

  if current_inputs[11] != switch_status
    current_inputs[11] = switch_status
    prmc1_core.change_parameter(11, current_inputs[11])
  end

  # workaround for CH1 blue LED flickering issue
  prmc1_core.process_sequencer
  angle8.set_blue_led(7, 0)

  (0..3).each do |ch|
    prmc1_core.process_sequencer
    angle8.set_blue_led(ch, (prmc1_core.step_status_bits >> ch & 0x01) * LED_ON_VALUE)
  end

  (0..7).each do |ch|
    prmc1_core.process_sequencer
    byte_switch.set_led(ch, prmc1_core.sub_step_status_bits >> ch & 0x01)
  end

  (0..7).each do |ch|
    prmc1_core.process_sequencer
    angle8.set_green_led(ch, (prmc1_core.parameter_status_bits >> ch & 0x01) * LED_ON_VALUE)
  end
end
