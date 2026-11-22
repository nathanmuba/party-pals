extends "res://scripts/games/race.gd"

const NAME := "Gap Jumper"
const MODES := ["ffa", "coop"]
const HOW := "Move to run · Action: dive forward (dive across gaps!)"

static func desc(m: String) -> String:
	if m == "coop": return "A course full of gaps with narrow bridges. Dive across! Get all four pals to the finish before time runs out."
	return "A course full of gaps with narrow bridges. Find the bridges or dive across. First to the top wins!"

func cfg() -> Dictionary:
	return {"name": NAME, "length": 3800.0, "dur": 80.0, "boulders": false, "segs": ["pits", "pits1", "pitbump"], "sky": [Color("#2a1650"), Color("#5a3a9a")], "edge": Color("#3a2a6e"), "floor": [Color("#d9ccff"), Color("#c8b8ff")], "bridge": Color("#7dff9a"), "coop_dur": 19.0}
