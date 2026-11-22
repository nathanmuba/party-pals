extends "res://scripts/games/race.gd"

const NAME := "Obstacle Dash"
const MODES := ["ffa", "2v2", "1v3"]
const HOW := "Move to run · Action: dive forward (dive across gaps!)"

static func desc(m: String) -> String:
	if m == "1v3": return "Race up the obstacle course. The solo pal must finish in the top 2 to win. The trio just needs to beat them!"
	if m == "2v2": return "Race up the obstacle course. Your team scores by finishing positions. Best combined finish wins!"
	return "Race up a wild obstacle course full of sweepers, sliders and gaps. First to the finish wins!"

func cfg() -> Dictionary:
	return {"name": NAME, "length": 4600.0, "dur": 80.0, "boulders": false, "segs": ["sweep", "slide", "pits", "bump", "sweep", "belt"], "sky": [Color("#7fd0ff"), Color("#ffb6e6")], "edge": Color("#7a52d6"), "floor": [Color("#fff0fa"), Color("#ffe0f2")], "bridge": Color("#ffc93c")}
