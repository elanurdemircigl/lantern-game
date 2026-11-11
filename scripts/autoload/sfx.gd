extends Node
## Tüm ses efektlerini ve ambiyans müziğini kodla sentezler.
## Böylece oyun hiçbir harici ses dosyasına ihtiyaç duymaz.
## İleride gerçek sesler eklemek için _streams sözlüğüne AudioStream yüklemek yeterli.

const RATE := 22050
const MUSIC_RATE := 11025
const POOL_SIZE := 10

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_build_sounds()


func play(sound: String, pitch_jitter := 0.0, volume_db := 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.volume_db = volume_db
	player.play()


func play_music() -> void:
	if _music.playing:
		return
	if not _streams.has("music"):
		_streams["music"] = _make_music()
	_music.stream = _streams["music"]
	_music.volume_db = -3.0
	_music.play()


func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]


# --- Sentez yardımcıları ---------------------------------------------------

func _synth(duration: float, gen: Callable, rate := RATE, loop := false) -> AudioStreamWAV:
	var n := int(duration * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = gen.call(float(i) / rate)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


## Basit atak + üstel olmayan sönüm zarfı.
static func _env(t: float, attack: float, length: float) -> float:
	if t < attack:
		return t / attack
	var k := 1.0 - (t - attack) / maxf(length - attack, 0.0001)
	return clampf(k, 0.0, 1.0) * clampf(k, 0.0, 1.0)


## f0'dan f1'e doğrusal frekans kayması için faz (dur süresince).
static func _sweep_phase(t: float, f0: float, f1: float, dur: float) -> float:
	var tt := minf(t, dur)
	var phase := f0 * tt + (f1 - f0) * tt * tt / (2.0 * dur)
	if t > dur:
		phase += f1 * (t - dur)
	return TAU * phase


static func _square(phase: float) -> float:
	return 1.0 if sin(phase) >= 0.0 else -1.0


func _build_sounds() -> void:
	# Işık küresi: yükselen yumuşak çan
	_streams["orb"] = _synth(0.25, func(t: float) -> float:
		var p := _sweep_phase(t, 520.0, 1040.0, 0.12)
		return (sin(p) * 0.45 + sin(p * 2.0) * 0.12) * _env(t, 0.004, 0.25))

	# Kıvılcım: parlak arpej
	_streams["spark"] = _synth(0.45, func(t: float) -> float:
		var notes := [880.0, 1108.73, 1318.51]
		var idx := mini(int(t / 0.07), 2)
		var local := t - idx * 0.07
		var f: float = notes[idx]
		var length := 0.38 if idx == 2 else 0.09
		return (sin(TAU * f * t) * 0.35 + sin(TAU * f * 2.0 * t) * 0.08) * _env(local, 0.003, length))

	# Parlama: gürültü patlaması + inen ton
	var flash_state := [0.0]
	_streams["flash"] = _synth(0.45, func(t: float) -> float:
		flash_state[0] = lerpf(flash_state[0], randf_range(-1.0, 1.0), 0.35)
		var noise: float = flash_state[0] * 0.5 * _env(t, 0.002, 0.3)
		var tone := sin(_sweep_phase(t, 1400.0, 180.0, 0.4)) * 0.3 * _env(t, 0.002, 0.45)
		return noise + tone)

	# Hasar: inen kare dalga
	_streams["hurt"] = _synth(0.32, func(t: float) -> float:
		return _square(_sweep_phase(t, 320.0, 80.0, 0.3)) * 0.22 * _env(t, 0.002, 0.32))

	# Kapı açıldı: kademeli akor
	_streams["door"] = _synth(0.9, func(t: float) -> float:
		var v := 0.0
		var freqs := [392.0, 523.25, 659.25, 783.99]
		for i in freqs.size():
			var start := i * 0.08
			if t >= start:
				v += sin(TAU * float(freqs[i]) * t) * 0.16 * _env(t - start, 0.01, 0.8 - start)
		return v)

	# Kazanma: neşeli arpej
	_streams["win"] = _synth(1.0, func(t: float) -> float:
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var idx := mini(int(t / 0.11), 3)
		var local := t - idx * 0.11
		var f: float = notes[idx]
		var length := 0.65 if idx == 3 else 0.14
		return (sin(TAU * f * t) * 0.3 + _square(TAU * f * t) * 0.05) * _env(local, 0.004, length))

	# Kaybetme: titreyen inen ton
	_streams["lose"] = _synth(1.4, func(t: float) -> float:
		var vib := sin(TAU * 6.0 * t) * 0.6
		var p := _sweep_phase(t, 330.0, 82.0, 1.3) + vib
		return (sin(p) * 0.35 + sin(p * 0.5) * 0.2) * _env(t, 0.02, 1.4))

	# Gölge fark etti: alçak fısıltı
	var alert_state := [0.0]
	_streams["alert"] = _synth(0.5, func(t: float) -> float:
		alert_state[0] = lerpf(alert_state[0], randf_range(-1.0, 1.0), 0.08)
		var hum := sin(TAU * 98.0 * t + sin(TAU * 3.0 * t)) * 0.25
		return (float(alert_state[0]) * 0.6 + hum) * _env(t, 0.08, 0.5))

	# Arayüz tıklaması
	_streams["click"] = _synth(0.06, func(t: float) -> float:
		return sin(TAU * 1250.0 * t) * 0.3 * _env(t, 0.001, 0.06))

	# Yetersiz ışık
	_streams["deny"] = _synth(0.15, func(t: float) -> float:
		return _square(TAU * 140.0 * t) * 0.15 * _env(t, 0.002, 0.15))


## 8 saniyelik, kusursuz dönen ambiyans. Tüm frekanslar × 8 tam sayı olduğundan döngü dikişsiz.
func _make_music() -> AudioStreamWAV:
	return _synth(8.0, func(t: float) -> float:
		var lfo := 0.5 + 0.5 * sin(TAU * 0.25 * t)
		var lfo2 := 0.5 + 0.5 * sin(TAU * 0.125 * t + 1.0)
		var v := sin(TAU * 55.0 * t) * 0.32
		v += sin(TAU * 82.5 * t) * 0.2 * lfo
		v += sin(TAU * 110.0 * t) * 0.14 * lfo2
		v += sin(TAU * 659.25 * t) * 0.03 * lfo2 * (0.5 + 0.5 * sin(TAU * 0.5 * t))
		return v * 0.6, MUSIC_RATE, true)
