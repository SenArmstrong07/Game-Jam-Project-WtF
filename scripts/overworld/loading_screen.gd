extends CanvasLayer

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var loading_label: Label = %LoadingLabel
var frontlayer: TileMapLayer

func _ready() -> void:
	add_to_group("LoadingScreen")
	_hide_overlay()

	if SignalBus.in_transition or not SignalBus.overworld_state.is_empty():
		print("[LOADING_SCREEN] Skipping loading overlay for restored overworld transition")
		return

	# Get reference to frontlayer
	frontlayer = get_tree().get_first_node_in_group("frontlayer")
	
	if frontlayer:
		# Connect to world generation signals
		frontlayer.world_generation_started.connect(_on_generation_started)
		frontlayer.world_generation_progress.connect(_on_generation_progress)
		frontlayer.world_generation_complete.connect(_on_generation_complete)
		
		progress_bar.value = 0
		loading_label.text = "Generating world..."
	else:
		print("ERROR: Could not find frontlayer")


func _on_generation_started() -> void:
	if SignalBus.in_transition or not SignalBus.overworld_state.is_empty():
		_hide_overlay()
		return

	progress_bar.value = 0
	loading_label.text = "Generating world..."
	_show_overlay()


func _on_generation_progress(progress: float) -> void:
	progress_bar.value = int(progress * 100)
	loading_label.text = "Generating world... %d%%" % [int(progress * 100)]


func _on_generation_complete() -> void:
	progress_bar.value = 100
	loading_label.text = "World ready! Starting game..."
	
	if SignalBus.in_transition or not SignalBus.overworld_state.is_empty():
		_hide_overlay()
		return
	
	# Hide loading screen after a brief delay
	await get_tree().create_timer(0.5).timeout
	_hide_overlay()

func _show_overlay(message: String = "Generating world...") -> void:
	loading_label.text = message
	progress_bar.value = 0
	visible = true

func _hide_overlay() -> void:
	visible = false
