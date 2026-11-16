extends Node
## Original offline synthesized sounds. Levels follow live vehicle state.
var van: Node
var master_volume := 0.7
var nature_volume := 0.5
var players: Dictionary = {}
var previous_flash := false
var previous_engine := true
var impact_cooldown := 0.0
var previous_brake := false
var horn_time := 0.0
var seen_collision := 0

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	set_process(false)
	for player in players.values():
		player.stop()
		player.stream = null
	players.clear()

func _ready() -> void:
	for sound in ["engine_idle","engine_load","road","wind","nature","horn","indicator","impact","brake_air","starter","tire_squeal","bump","scrape","crash"]:
		var player := AudioStreamPlayer.new()
		var path: String = "res://assets/audio/"+sound+".wav"
		if ResourceLoader.exists(path):
			var stream: AudioStreamWAV = load(path).duplicate()
			if sound in ["engine_idle","engine_load","road","wind","nature","horn","tire_squeal"]:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = int(stream.get_length()*stream.mix_rate)
			player.stream = stream
		player.volume_db = -80
		add_child(player)
		players[sound] = player

func level(sound: String, amount: float, pitch := 1.0) -> void:
	var player: AudioStreamPlayer = players[sound]
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(maxf(0.0001,amount*master_volume))
	if amount > 0.001 and van.active and player.stream:
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()

func effect(sound: String, amount := 0.5) -> void:
	var player: AudioStreamPlayer = players[sound]
	player.volume_db = linear_to_db(maxf(0.0001,amount*master_volume))
	if player.stream:
		player.play()

func _process(delta: float) -> void:
	if not van.active:
		for player in players.values():
			player.stop()
		return
	var speed: float = absf(van.speed)
	var engine: float = float(van.engine_on)
	level("engine_idle",engine*(0.28 if van.cockpit else 0.42),clampf(van.rpm/1000,0.65,3.5))
	level("engine_load",engine*van.throttle_load*0.30,clampf(van.rpm/1100,0.65,3))
	level("road",clampf(speed/35,0,1)*0.42,0.8+speed/65)
	level("tire_squeal",van.tire_squeal*0.52,0.9+speed/120)
	level("wind",(0.10+speed/35*0.25)*nature_volume)
	level("nature",0.32*nature_volume*(1-speed/50))
	level("horn",0.55 if Input.is_physical_key_pressed(KEY_B) or horn_time > 0 else 0.0)
	horn_time = maxf(0,horn_time-delta)
	var flash: bool = fmod(van.blink_time,1.0) < 0.5 and (van.hazards or van.indicator != 0)
	if flash != previous_flash:
		effect("indicator",0.28)
	previous_flash = flash
	if van.engine_on and not previous_engine:
		effect("starter",0.5)
	previous_engine = van.engine_on
	impact_cooldown = maxf(0,impact_cooldown-delta)
	if van.collision_serial != seen_collision:
		seen_collision = van.collision_serial
		effect(van.collision_kind,0.22+van.collision_level*0.6)
	var braking: bool = van.brake_load > 0.5 and speed > 4
	if braking and not previous_brake:
		effect("brake_air",0.4)
	previous_brake = braking
