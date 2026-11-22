extends "res://scripts/games/race.gd"

const NAME := "Boulder Hill"
const MODES := ["ffa", "coop"]
const HOW := "Move to run · Action: dive forward (dive across gaps!)"

static func desc(m: String) -> String:
	if m == "coop": return "Giant boulders roll down the hill! Get all four pals to the summit before time runs out."
	return "Climb the hill while giant boulders roll down at you. First to the summit wins!"

func cfg() -> Dictionary:
	return {"name": NAME, "length": 3800.0, "dur": 75.0, "boulders": true, "segs": ["belt", "bump5", "pits1"], "sky": [Color("#ffb35a"), Color("#ff6b8a")], "edge": Color("#6b4a2e"), "floor": [Color("#c9e98a"), Color("#b6dd78")], "bridge": Color("#a0743c"), "coop_dur": 30.0}
