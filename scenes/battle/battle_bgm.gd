extends AudioStreamPlayer2D

const VICTORY_MUSIC = preload("res://assets/FX/VictoryGenug.ogg")

func play_music(stream: AudioStream):
	if self.stream == stream and playing:
		return

	self.stream = stream
	play()

func play_victory_music() -> void:
	play_music(VICTORY_MUSIC)
