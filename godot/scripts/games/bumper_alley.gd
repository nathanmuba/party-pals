extends "res://scripts/games/race.gd"

const NAME := "Bumper Alley"
const MODES := ["ffa", "1v3"]
const HOW := "Move to run · Action: dive forward (dive across gaps!)"

static func desc(m: String) -> String:
	if m == "1v3": return "A pinball-mad course of bumpers and sweepers. The solo pal must finish in the top 2. The trio just needs to beat them!"
	return "A pinball-mad course packed with bumpers and spinning sweepers. First to the top wins!"

func cfg() -> Dictionary:
	return {"name": NAME, "length": 4200.0, "dur": 80.0, "boulders": false, "segs": ["bump9", "sweep", "bump5"], "sky": [Color("#ffd1f0"), Color("#c8a8ff")], "edge": Color("#d6336c"), "floor": [Color("#fff4fb"), Color("#ffe3f3")], "bridge": Color("#ffc93c")}
