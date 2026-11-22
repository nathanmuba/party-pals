extends "res://scripts/games/race.gd"

const NAME := "Conveyor Chaos"
const MODES := ["ffa", "2v2"]
const HOW := "Move to run · Action: dive forward (dive across gaps!)"

static func desc(m: String) -> String:
	return ("Team race! Best combined finish wins. " if m == "2v2" else "") + "Fight up a course of backwards conveyor belts and sliding walls. First to the top wins!"

func cfg() -> Dictionary:
	return {"name": NAME, "length": 4200.0, "dur": 80.0, "boulders": false, "segs": ["belt", "slide", "beltslide"], "sky": [Color("#c3f0ff"), Color("#9ad0ff")], "edge": Color("#3a6ea5"), "floor": [Color("#e8f4ff"), Color("#d6eaff")], "bridge": Color("#ffc93c")}
