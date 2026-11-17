extends RefCounted
## One geometry contract for painted HUD, touch hits, camera exclusion and prompts.
static func wide(h:float) -> bool:return h<600
static func deck_height(h:float) -> float:return 116.0 if wide(h) else 250.0
static func header_height(h:float) -> float:return 62.0 if wide(h) else 90.0
static func map_rect(h:float,expanded:bool) -> Rect2:
	if expanded:return Rect2(162,68,396,maxf(96,h-200)) if wide(h) else Rect2(30,204,660,maxf(180,h-deck_height(h)-226))
	return Rect2(588,68,116,72) if wide(h) else Rect2(524,102,180,124)
static func prompt_rect(h:float) -> Rect2:
	return Rect2(166,h-174,390,50) if wide(h) else Rect2(206,h-240,374,116)
static func regions(h:float) -> Dictionary:
	var result:Dictionary={}
	for i in 4:
		result[["camera","map","options","exit"][i]]=Rect2(426+i*70,10,62,44) if wide(h) else Rect2(20+i*100,102,88,88)
	if wide(h):
		result.merge({"stick":Rect2(18,h-142,132,132),"gas":Rect2(590,h-140,112,60),"brake":Rect2(590,h-72,112,60),"hand":Rect2(430,h-54,128,42),"gear":Rect2(430,h-104,128,42)})
	else:
		result.merge({"stick":Rect2(18,h-192,172,172),"gas":Rect2(594,h-198,108,88),"brake":Rect2(594,h-102,108,88),"hand":Rect2(340,h-102,118,88),"gear":Rect2(224,h-102,104,88)})
	result["upright"]=result.gear
	return result
static func scene_rect(h:float) -> Rect2:
	var top:=header_height(h) if wide(h) else 226.0
	return Rect2(0,top,720,maxf(1,h-top-deck_height(h)))
