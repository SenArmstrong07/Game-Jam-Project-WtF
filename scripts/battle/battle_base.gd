extends Node2D
class_name BattleBase

@onready var arena_tiles : TileMapLayer = $GridMap

enum BattlePhase {
	PREPARATION,
	BATTLE,
	END
}
var current_phase: BattlePhase = BattlePhase.PREPARATION
var occupied_tiles := {}
var broken_tiles: Dictionary = {}
var blocked_tiles: Array[Vector2i] = []
var firewalls: Dictionary = {}

func break_tile(tile: Vector2i):

	if broken_tiles.has(tile):
		return

	# Destroy firewall on this tile
	if firewalls.has(tile):
		firewalls[tile].queue_free()
		firewalls.erase(tile)
		blocked_tiles.erase(tile)

	var source = arena_tiles.get_cell_source_id(tile)
	var atlas = arena_tiles.get_cell_atlas_coords(tile)

	broken_tiles[tile] = {
		"source": source,
		"atlas": atlas
	}

	arena_tiles.erase_cell(tile)
		
func restore_tile(tile: Vector2i):
	if !broken_tiles.has(tile):
		return

	var data = broken_tiles[tile]

	arena_tiles.set_cell(
		tile,
		data.source,
		data.atlas
	)

	broken_tiles.erase(tile)
	
# Used by enemies
func is_tile_free(tile: Vector2i) -> bool:
	if broken_tiles.has(tile):
		return false

	if blocked_tiles.has(tile):
		return false

	if occupied_tiles.has(tile):
		return false

	return true

# Used by the player
func is_tile_walkable(tile: Vector2i) -> bool:
	if broken_tiles.has(tile):
		return false

	if blocked_tiles.has(tile):
		return false

	return true
