extends AudioStreamPlayer

class_name meta_player

## A music player designed to adapt to game events.

## Use these properties to determine whether this player will loop,
## and whether it should play automatically on _ready.
## IMPORTANT - >> MAKE SURE THE AUDIO FILE LOADED IS IMPORTED WITH
## THE 'LOOP' FLAG DISABLED. META_PLAYER DUPLICATES AUDIO FILES TO
## LOOP, SO THIS WILL CAUSE UNWANTED DESYNCHRONISATION << - ##

@export_group("Playback") ## Options for playback.
@export var loop := true ## Repeat the song over and over.

@export var auto_play := false ## Play the song on scene load.

## Set the exact BPM, time signature and length, or looping and beat/bar
## signals will not work correctly. Don't count reverb/decay tails in
## this, to allow smooth looping. E.g, if the song 'ends' on bar 64, but
## has 2 bars of decay where instruments ring out so that the audio file
## is 66 bars long, still put 64.

@export_group("Music")
@export var tempo := 120 ## The BPM (beats per minute) of the song.
@export var beats_per_bar := 4 ## Time signature analog - the number of musical pulses per bar. A time signature of 4/4 would be 4, 5/4 would be 5, etc.
@export var bars := 16 ## How many bars/measures there are in the song. Mainly used for looping.

## Enable volume automation to raise/lower volume of this player based
## on the value of a chosen parameter. Set the target node in
## 'target', and the property name to monitor in 'target_param'.
## 'val_min' and 'val_max' should be set with the minimum and
## maximum range of values to react to, and 'param_smooth' lerps the
## input value. The seek up and down weights control the speed of
## volume modulation upwards and downwards. Toggle 'invert' on if
## the volume should rise in response to the parameter decreasing,
## rather than increasing.

@export_group("Volume Automation")
@export var automate_volume := false ## Toggle on to enable the volume modulation feature. Ensure the other options are filled out correctly before running, including adding an automation rule.
@export var target : Node ## The node containing the parameter to monitor for changes.
@export var target_param := "" ## The name of the Float parameter to monitor.
@export_range(0.1,1.0) var param_smooth := 0.5 ## The smoothing to apply to parameter changes. 1.0 updates instantly.
@export var automation_rule : fade_rule ## Choose how to automate the volume. A `point_fade` will fade the volume in based on the parameter's absolute distance from a point. A `range_fade` will fade the volume in (or out) based on its relative progress from a minumum to maximum value.
@export_range(0.1,3.0) var seek_up_weight := 0.8 ## How quickly the volume should rise, in decibels per frame.
@export_range(0.1,3.0) var seek_down_weight := 0.8 ## How quickly the volume should fall, in decibels per frame.

## Enable randomisation to leave the playing of this song to chance.
## 'Chance' is the probability of playing, as a percentage.

@export_group("Randomisation")
@export var randomise := false ## Enable to use random chance to decide whether this song plays.
@export_range(0.0,100.0) var chance := 100.0 ## The percentage chance of this song playing.

## In the inspector, add elements to `transition_rules` to enable auto-
## matic transitions between songs. Target the other meta_player to
## transition to, and a node and signal to trigger the transition, as
## well as choosing whether to triggered transition should happen on
## a beat or bar. Alternatively, leave node and signal blank, and choose
## "At End" to transition automatically at the end of the song after
## playing once. This is useful for transition segments. When using
## transition segments, set the source track to transition to the
## transition segment by some signal, then let the transition segment
## auto-transition at the end.

@export_group("Transitions")
@export var transition_rules : Array[transition_rule] = [] ## Add transition_rules here to automatically transition between songs. Each rule should target another meta_player. When using `on_beat` or `on_bar` transition types, a target node and signal must be provided to trigger the transition. No signal is required for `at_end`, which transitions at the end of the song.

## To arrange your multitrack song, choose one to be a "core" track,
## and add the other tracks as children in the scene tree. The children
## tracks will be considered a "play group", and play in sync with the
## parent. Ensure that all grouped tracks, and the parent, have the
## same bar length, though decay tails are free to vary.

var is_in_play_group := false

var copy : AudioStreamPlayer
var beats_in_sec := 0.0
var time := 0.0
var current_beat := 0
var current_bar := 0
var beat_index := -1
var last_beat := 0
var param := 0.0
var total_beats := 0
var trans_buffer := {}
var short := false
var precision_margin := 0.02

signal beat ## Emitted every beat during playback.
signal bar ## Emitted at the start of each bar during playback.

func _ready():
	if get_parent() is meta_player:
		is_in_play_group = true
	beats_in_sec = 60000.0/float(tempo)
	var stream_length_ms = stream.get_length() * 1000.0
	var loop_length_ms = beats_in_sec * (bars * beats_per_bar)
	## Indicates that the stream duration is just equal or slightly shorter than the theorical loop length 
	short = absf(stream_length_ms - loop_length_ms) <= precision_margin
	total_beats = bars * beats_per_bar
	if auto_play:
		mplay()

func _process(delta):
	calc_beat(delta)
	if automate_volume and target:
		if !copy: return
		if copy.playing:
			var t_param := float(target.get(target_param))
			var smooth := (param_smooth * -1) + 1
			if param_smooth != 1.0:
				param = lerp(param, t_param, smooth)
			else:
				param = t_param
			var range : bool = (automation_rule is range_fade)
			if range:
				fade_to(get_range_vol())
			else:
				fade_to(get_dis_vol())

func calc_beat(_delta):
	if !copy: return
	if copy.playing:
		time = copy.get_playback_position()
		beat_index = int(floor((time/beats_in_sec) * 1000.0))
		current_beat = beat_index % total_beats + 1
		if current_beat != last_beat:
			_beat()
		last_beat = current_beat
	
func fade_to(value : float, instant=false) -> void:
	if instant:
		volume_db = value
		if copy:
			copy.volume_db = value
	else:
		var above := (volume_db < value) 
		var sw = seek_down_weight
		if above:
			sw = seek_up_weight
		volume_db = move_toward(volume_db, value, sw)
		if copy:
			copy.volume_db = move_toward(copy.volume_db, value, sw)
			
func get_range_vol() -> float:
	var vol : float = param
	var rule : range_fade = automation_rule
	var invert : bool = rule.invert
	var val_min : float = rule.val_min
	var val_max : float = rule.val_max
	if !invert:
		vol -= val_min
	else:
		vol *= -1
		vol += val_max
	vol /= float(abs(val_max - val_min))
	vol = (vol*70) - 70
	vol = clamp(vol,-70,0)
	return vol

func get_dis_vol() -> float:
	var rule : point_fade = automation_rule
	var point : float = rule.median
	var max_range : float = rule.range
	var vol : float = abs(param - point)
	vol *= -1
	vol += max_range
	vol /= max_range
	vol = (vol*70) - 70
	vol = clamp(vol,-70,0)
	return vol

func add_trans_buffer(player : meta_player, type : String):
	assert(player, str("A transition was attempted by %s, but the transition has no target." % name))
	trans_buffer = {"player": player,
					"type": type}

func check_buffer(type : String):
	if trans_buffer == {}: return false
	return (trans_buffer.type == type)

func transition(player : meta_player = trans_buffer.player):
	mstop()
	player.mplay()
	trans_buffer = {}

func mplay():
	spawn_copy()
	current_bar = 0
	connect_trans_signals()
	if automate_volume and target:
		assert(automation_rule, str("No automation rule has been defined for %s, but it is set to automate." % name))
		param = target.get(target_param)
		if (automation_rule is range_fade):
			fade_to(get_range_vol(), true)
		else:
			fade_to(get_dis_vol(), true)
	if get_child_count() > 0:
		play_group()
	else:
		copy.play()
	on_beat(1)

func connect_trans_signals():
	for tr in transition_rules:
		if tr.signal_name.length() == 0:
			if tr.transition_type == "At End":
				var target_player = get_node(tr.target_player)
				add_trans_buffer(target_player, "At End")
			continue
		var sig_node : Node = get_node(tr.signal_node)
		assert(sig_node, str("%s attempted to connect transition signal, but target node was invalid." % name))
		if !sig_node.is_connected(tr.signal_name, trans_signal_callback):
			sig_node.connect(tr.signal_name, trans_signal_callback.bind(tr))

func trans_signal_callback(rule : transition_rule):
	var nm = rule.signal_name
	var player = get_node(rule.target_player)
	var sig_node : Node = get_node(rule.signal_node)
	var type = rule.transition_type
	add_trans_buffer(player, type)
	sig_node.disconnect(nm, trans_signal_callback)

func spawn_copy():
	var c = AudioStreamPlayer.new()
	add_child(c)
	c.finished.connect(func():
		c.queue_free()
		if short:
			if current_beat == bars*beats_per_bar:
				end()
			elif !is_in_play_group:
				push_error("Stream finished before bars count")
	)
	c.stream = stream
	c.volume_db = volume_db
	c.bus = bus
	copy = c

func on_start():
	if randomise:
		if randf_range(0,100) > chance:
			volume_db = -70

func _beat():
	var trans : bool = check_buffer("On Beat")
	if trans:
		transition()
		return
	var _s = emit_signal("beat", current_beat)
	if beat_index % beats_per_bar == 0:
		_bar()
	if beat_index == total_beats:
		end()

func _bar():
	var trans : bool = check_buffer("On Bar")
	if trans:
		transition()
		return
	current_bar = floor(beat_index / beats_per_bar) + 1
	var _s = emit_signal("bar", current_bar)

func on_beat(b):
	if b == 1:
		on_start()
		
func end():
	var trans : bool = check_buffer("At End")
	if trans:
		transition()
		return
	if !is_in_play_group:
		if loop:
			mplay()

func mstop():
	if get_child_count() > 0:
		stop_group()
	else:
		var t = create_tween()
		t.tween_property(copy, 'volume_db', -70, 0.6)
		await t.finished
		if copy:
			copy.queue_free()
	
func play_group():
	copy.play()
	for i in get_children():
		if i is meta_player:
			i.mplay()

func stop_group():
	var t = create_tween()
	t.tween_property(copy, 'volume_db', -70, 0.6)
	for i in get_children():
		if i is meta_player:
			i.mstop()
	await t.finished
	if copy:
		copy.queue_free()
