extends AudioStreamPlayer

class_name meta_player

## Use these properties to determine whether this player will loop,
## and whether it should play automatically on _ready.
## IMPORTANT - >> MAKE SURE THE AUDIO FILE LOADED IS IMPORTED WITH
## THE 'LOOP' FLAG DISABLED. META_PLAYER DUPLICATES AUDIO FILES TO
## LOOP, SO THIS WILL CAUSE UNWANTED DESYNCHRONISATION << - ##

@export_group("Playback")
@export var loop := true
@export var auto_play := false

## Set the exact BPM, time signature and length, or looping and beat/bar
## signals will not work correctly. Don't count reveryb/decay tails in
## this, to allow smooth looping.

@export_group("Music")
@export var tempo := 120
@export var beats_per_bar := 4
@export var bars := 16

## Enable volume automation to raise/lower volume of this player based
## on the value of a chosen parameter. Set the target node in
## 'target', and the property name to monitor in 'target_param'.
## 'val_min' and 'val_max' should be set with the minimum and
## maximum range of values to react to, and 'param_smooth' lerps the
## input value. The seek up and down weights control the speed of
## volume modulation upwards and downwards. Toggle 'invert' on if
## the volume should rise in response to the parameter decreasing,
## rather than increasing.

@export_group("Automation")
@export var automate_volume := false
@export var target : Node
@export var target_param := ""
@export_range(0.0,1.0) var param_smooth := 0.5
@export var val_min := 0.0
@export var val_max := 0.0
@export_range(0.1,3.0) var seek_up_weight := 0.8
@export_range(0.1,3.0) var seek_down_weight := 0.8
@export var invert := false

## Enable randomisation to leave the playing of this player to chance.
## 'Chance' is the probability of playing, as a percentage.

@export_group("Randomisation")
@export var randomise := false
@export_range(0.0,100.0) var chance := 100.0

## 'is_in_play_group' is set to true if the player is a child of another
## meta_player. This will cause this player to play in sync with its
## parent. Be sure to only group tracks of the same bar length.

var is_in_play_group := false

var copy : AudioStreamPlayer
var beats_in_sec := 0.0
var time := 0.0
var current_beat := 1
var last_beat := 0
var param := 0.0
var b2bar := 1

signal beat
signal bar

func _ready():
	if get_parent() is meta_player:
		is_in_play_group = true
	beats_in_sec = 60000.0/tempo
	if auto_play:
		mplay()

func _process(delta):
	calc_beat(delta)
	if automate_volume and target:
		if copy.playing:
			var t_param := float(target.get(target_param))
			var smooth := (param_smooth * -1) + 1
			param = lerp(param, t_param, smooth)
			fade_to(get_range_vol())

func calc_beat(_delta):
	if copy.playing:
		time = copy.get_playback_position()
		current_beat = int(floor(((time/beats_in_sec) * 1000.0) + 1.0))
		if current_beat != last_beat && (current_beat - 1) % int(bars * beats_per_bar) + 1 != last_beat:
			_beat()
		last_beat = current_beat
	
func fade_to(value : float, instant=false) -> void:
	if instant:
		volume_db = value
		if copy:
			copy.volume_db = value
	else:
		var above := (volume_db > value) 
		var sw = seek_down_weight
		if above:
			sw = seek_up_weight
		volume_db = move_toward(volume_db, value, sw)
		if copy:
			copy.volume_db = move_toward(copy.volume_db, value, sw)
			
func get_range_vol() -> float:
	var vol : float = param
	if !invert:
		vol -= val_min
	else:
		vol *= -1
		vol += val_max
	vol /= float(abs(val_max - val_min))
	vol = (vol*65) - 65
	vol = clamp(vol,-65,0)
	return vol
			
func mplay():
	spawn_copy()
	if automate_volume and target:
		param = target.get(target_param)
		fade_to(get_range_vol(), true)
	if get_child_count() > 0:
		play_group()
	else:
		copy.play()
	on_beat(1)

func spawn_copy():
	var c = AudioStreamPlayer.new()
	add_child(c)
	c.finished.connect(func(): c.queue_free())
	c.stream = stream
	c.volume_db = volume_db
	c.bus = bus
	copy = c

func on_start():
	if randomise:
		if randf_range(0,100) > chance:
			volume_db = -65

func _beat():
	var _s = emit_signal("beat", current_beat)
	if b2bar < (beats_per_bar):
		b2bar += 1
	else:
		b2bar = 1
		_bar()
	if current_beat == (bars*beats_per_bar + 1):
		end()

func _bar():
	var _s = emit_signal("bar")

func on_beat(b):
	if b == 1:
		on_start()
		
func end():
	if !is_in_play_group:
		if loop:
			mplay()

func mstop():
	if get_child_count() > 0:
		stop_group()
	else:
		var t = create_tween()
		t.tween_property(copy, 'volume_db', -65, 0.3)
		await t.finished
		copy.queue_free()
	
func play_group():
	copy.play()
	for i in get_children():
		if i is meta_player:
			i.mplay()
		if !(i is meta_copy):
			i.play()

func stop_group():
	var t = create_tween()
	t.tween_property(copy, 'volume_db', -65, 0.3)
	for i in get_children():
		i.mstop()
	await t.finished
	copy.queue_free()

func transition(to : meta_player, type : String):
	match type:
		"beat":
			await beat
		"bar":
			await bar
	mstop()
	to.mplay()
