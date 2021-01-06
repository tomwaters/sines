--- ~ Sines v0.8 ~
-- E1 - norns volume
-- E2 - select sine 1-16
-- E3 - set sine amplitude
-- K2 + E2 - change note
-- K2 + E3 - detune
-- K2 + K3 - set voice panning
-- K3 + E2 - change envelope
-- K3 + E3 - change FM index
-- K1 + E2 - change sample rate
-- K1 + E3 - change bit depth
local sliders = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local edit = 1
local accum = 1
local env_edit = 1
local env_accum = 1
local step = 0
local freq_increment = 0
local cents_increment = 0
local cents_values = {}
local scale_names = {}
local notes = {}
local key_1_pressed = 0
local key_2_pressed = 0
local key_3_pressed = 0
local toggle = false
local pan_display = "m"

engine.name = "Sines"
MusicUtil = require "musicutil"

function init()
  print("loaded Sines engine")
  add_params()
  edit = 0
end

function add_params()
  --set vols
  for i = 1,16 do
    params:add_control("vol" .. i, "voice " .. i .. " vol", controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0))
    params:set_action("vol" .. i, function(x) set_vol(i - 1, x) end)
  end
  --set voice params
  for i = 1,16 do
    params:add_group("voice " .. i .. " params", 8)
    --params:add_number("note" .. i, "note " .. i, 0, 127, 60)
    --maybe you don't need a set action here?
    --or maybe you just don't need the default?
    params:add{type = "number", id = "note" ..i, name = "note " .. i, min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end, action = function() set_freq(i - 1, x) end}
    params:add_number("cents" .. i, "cents " .. i, 0, 100, 0)
    params:set_action("cents" .. i, function(x) tune(i, x) end)
    params:add_control("fm_index" .. i, "fm index " .. i, controlspec.new(1, 200, 'lin', 1, 3))
    params:set_action("fm_index" .. i, function(x) set_fm_index(i - 1, x) end)
    params:add_control("attack" .. i, "env attack " .. i, controlspec.new(0.01, 15, 'lin', 0.01, 1.0,'s'))
    params:set_action("attack" .. i, function(x) set_amp_atk(i - 1, x) end)
    params:add_control("decay" .. i, "env decay " .. i, controlspec.new(0.01, 15, 'lin', 0.01, 1.0,'s'))
    params:set_action("decay" .. i, function(x) set_amp_rel(i - 1, x) end)
    params:add_control("env_bias" .. i, "env bias " .. i, controlspec.new(0.0, 1.0, 'lin', 0.01, 1.0))
    params:set_action("env_bias" .. i, function(x) set_env_bias(i - 1, x) end)
    params:add_control("bit_depth" .. i, "bit depth " .. i, controlspec.new(1, 24, 'lin', 1, 24, 'bits'))
    params:set_action("bit_depth" .. i, function(x) set_bit_depth(i - 1, x) end)
    params:add_control("smpl_rate" .. i, "sample rate " .. i, controlspec.new(4410, 44100, 'lin', 100, 44100,'hz'))
    params:set_action("smpl_rate" .. i, function(x) set_sample_rate(i - 1, x) end)
  end
  --set the scale note values
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
  end
  params:add{type = "option", id = "scale_mode", name = "scale mode",
    options = scale_names, default = 5,
  action = function() build_scale() end}
  params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
  action = function() build_scale() end}
  --do we need params:default?
  params:default()
  params:bang()
end

function build_scale()
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), 16)
  local num_to_add = 16 - #notes
  for i = 1, num_to_add do
    --notes are midi note numbers
    params:set("note" .. i, notes[i])
  end
end

function set_freq(synth_num, value)
  engine.hz(synth_num, MusicUtil.note_num_to_freq(value))
  engine.hz_lag(synth_num, 0.005)
  edit = synth_num
  redraw()
end

function set_vol(synth_num, value)
  engine.vol(synth_num, value)
  edit = synth_num
end

function tune(synth_num, value)
    --increase the hz from orig midi_note_to_freq value
    --calculate cents increase from midi note to new tuned value
    --output the cents value
    --this might need to pull the current note value to calculate the cents value
    --E.G. for your given two frequencies, 440Hz and 450Hz
    --Cents difference = 3986*log(450/440)= 38.9 cents
    print (params:get("cents" .. synth_num))
 end

function set_cents(synth_num, value)
  value = params:get("cents" .. synth_num) + value
  value = value * 0.1
  --argh this is goofy af
  --set cents values in 0.1 increments
  -- increment the current note freq
  freq_increment = freq_increment + value
  -- calculate increase in cents
  -- https://music.stackexchange.com/questions/17566/how-to-calculate-the-difference-in-cents-between-a-note-and-an-arbitrary-frequen
  cents_increment = 3986*math.log((MusicUtil.note_num_to_freq(params:get("note" .. synth_num)) + freq_increment)/(MusicUtil.note_num_to_freq(notes[synth_num])))
  -- round down to 2 dec points
  cents_increment = math.floor((cents_increment) * 10 / 10)
  engine.hz(synth_num, MusicUtil.note_num_to_freq(params:get("note" .. synth_num)) + freq_increment)
  engine.hz_lag(synth_num, 0.005)
  edit = synth_num
end

function set_fm_index(synth_num, value)
  engine.fm_index(synth_num, value)
  edit = synth_num
  redraw()
end

function set_amp_atk(synth_num, value)
  engine.amp_atk(synth_num, value)
  edit = synth_num
  redraw()
end

function set_amp_rel(synth_num, value)
  engine.amp_rel(synth_num, value)
  edit = synth_num
  redraw()
end

function set_env_bias(synth_num, value)
  engine.env_bias(synth_num, value)
  edit = synth_num
  redraw()
end

function set_bit_depth(synth_num, value)
  engine.bit_depth(synth_num, value)
  edit = synth_num
  redraw()
end

function set_sample_rate(synth_num, value)
  engine.sample_rate(synth_num, value)
  edit = synth_num
  redraw()
end

function set_synth_pan(synth_num, value)
  engine.pan(synth_num - 1, value)
end

function set_pan()
  -- pan position on the bus, -1 is left, 1 is right
  if key_2_pressed == 1 and key_3_pressed == 1 then
    toggle = not toggle
    if toggle then
      pan_display = "l/r"
      --set hard l/r pan values
      for i = 1,16 do
        if i % 2 == 0 then
          --even, pan right
          set_synth_pan(i,1)
        elseif i % 2 == 1 then
          --odd, pan left
          set_synth_pan(i,-1)
        end
      end
    end
    if not toggle then
      pan_display = "m"
      for i = 1,16 do
        set_synth_pan(i,0)
      end
    end
  end
end

--update when a cc change is detected
m = midi.connect()
m.event = function(data)
redraw()
local d = midi.to_msg(data)
if d.type == "cc" then
  --set all the sliders + fm values
  for i = 1,16 do
    sliders[i] = (params:get("vol" .. i))*32-1
    if sliders[i] > 32 then sliders[i] = 32 end
    if sliders[i] < 0 then sliders[i] = 0 end
  end
end
--allow root note to be set from midi keyboard
if d.type == "note_on" then
  params:set("root_note", d.note)
end
redraw()
end


function enc(n, delta)
  if n == 1 then
    if key_1_pressed == 0 then
      params:delta('output_level', delta)
    end
  elseif n == 2 then
    if key_1_pressed == 0 and key_2_pressed == 0 and key_3_pressed == 0 then
      --navigate up/down the list of sliders
      --accum wraps around 0-15
      accum = (accum + delta) % 16
      --edit is the slider number
      edit = accum

    elseif key_1_pressed == 0 and key_2_pressed == 0 and key_3_pressed == 1 then
      params:set("attack" .. edit+1,  params:get("attack" .. edit+1) + delta * 0.1)
      params:set("decay" .. edit+1,  params:get("decay" .. edit+1) + delta * 0.1)

    elseif key_1_pressed == 0 and key_2_pressed == 1 and key_3_pressed == 0 then
      -- increment the note value with delta
      params:set("note" .. edit+1,  params:get("note" .. edit+1) + delta)
      params:set("cents" .. edit+1, 0)

    elseif key_1_pressed == 1 and key_2_pressed == 0 and key_3_pressed == 0 then
      --set sample rate
      params:set("smpl_rate" .. edit+1, params:get("smpl_rate" .. edit+1) + (delta) * 1000)
    end

  elseif n == 3 then
    if key_1_pressed == 0 and key_3_pressed == 0 and key_2_pressed == 0 then
      --set the slider value
      sliders[edit+1] = sliders[edit+1] + delta
      amp_value = util.clamp(((sliders[edit+1] + delta) * .026), 0.0, 1.0)
      params:set("vol" .. edit+1, amp_value)
      if sliders[edit+1] > 32 then sliders[edit+1] = 32 end
      if sliders[edit+1] < 0 then sliders[edit+1] = 0 end

    elseif key_1_pressed == 0 and key_2_pressed == 1 and key_3_pressed == 0 then
      --set the cents value to increment by
      params:set("cents" .. edit+1, params:get("cents" .. edit+1) + delta)

    elseif key_1_pressed == 0 and key_2_pressed == 0 and key_3_pressed == 1 then
      -- set the fm value
      params:set("fm_index" .. edit+1, params:get("fm_index" .. edit+1) + delta)

    elseif key_1_pressed == 1  and key_2_pressed == 0 and key_3_pressed == 0 then
      --set bit depth
      params:set("bit_depth" .. edit+1, params:get("bit_depth" .. edit+1) + delta)
    end
  end
  redraw()
end

function key(n, z)
  --use these keypress variables to add extra functionality on key hold
  if n == 1 and z == 1 then
    key_1_pressed = 1
  elseif n == 1 and z == 0 then
    key_1_pressed = 0
  elseif n == 2 and z == 1 then
    key_2_pressed = 1
  elseif n == 2 and z == 0 then
    key_2_pressed = 0
  elseif n == 3 and z == 1 then
    key_3_pressed = 1
  elseif n == 3 and z == 0 then
    key_3_pressed = 0
  end
  set_pan()
  redraw()
end

function redraw()
  screen.aa(1)
  screen.line_width(2.0)
  screen.clear()

  for i= 0, 15 do
    if i == edit then
      screen.level(15)
    else
      screen.level(2)
    end
    screen.move(32+i*4, 62)
    screen.line(32+i*4, 60-sliders[i+1])
    screen.stroke()
  end
  screen.level(10)
  screen.line(32+step*4, 68)
  screen.stroke()
  --display current values
  screen.move(0,5)
  screen.level(2)
  screen.text("Note: ")
  screen.level(15)
  screen.text(MusicUtil.note_num_to_name(params:get("note" .. edit+1), true) .. " ")
  screen.level(2)
  screen.text("Detune: ")
  screen.level(15)
  screen.text(params:get("cents" .. edit+1))
  screen.move(0,12)
  screen.level(2)
  screen.text("Atk/Dec: ")
  screen.level(15)
  screen.text(params:get("attack" .. edit+1) .. "/" ..  params:get("decay" .. edit+1))
  screen.level(2)
  screen.text(" FM ind: ")
  screen.level(15)
  screen.text(params:get("fm_index" .. edit+1))
  screen.move(0,19)
  screen.level(2)
  screen.text("Smpl rate: ")
  screen.level(15)
  screen.text(params:get("smpl_rate" .. edit+1)/1000)
  screen.level(2)
  screen.text(" Bit dpt: ")
  screen.level(15)
  screen.text(params:get("bit_depth" .. edit+1))
  screen.move(0,26)
  screen.level(2)
  screen.text("Pan: ")
  screen.level(15)
  screen.text(pan_display)
  screen.level(2)
  screen.text(" Vol: ")
  screen.level(15)
  screen.text(math.floor((params:get('output_level')) * 10 / 10) .. " dB")
  screen.update()
end
