extends AudioStreamPlayer2D


func play_music(stream: AudioStream):
	if self.stream == stream and playing:
		return

	self.stream = stream
	play()
