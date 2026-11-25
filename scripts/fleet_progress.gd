extends RefCounted
## Local/browser-local progression. Tests can inject a separate save path.
var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/player_vehicles.json")).vehicles
var deliveries:=0
var selected:="truck"
var receipts:Array=[]
var path:="user://fedup_fleet.cfg"
var persistent:=true
var save_error:=OK

func load_progress() -> void:
	if not persistent:return
	var cfg:=ConfigFile.new()
	if cfg.load(path)!=OK:return
	deliveries=maxi(0,int(cfg.get_value("progress","deliveries",0)))
	receipts=cfg.get_value("progress","receipts",[])
	selected=str(cfg.get_value("progress","vehicle","truck"))
	if not unlocked(selected):selected="truck"

func spec(id:String) -> Dictionary:
	for vehicle in catalog:
		if vehicle.id==id:return vehicle
	return catalog[0]

func unlocked(id:String) -> bool:
	for vehicle in catalog:
		if vehicle.id==id:return deliveries>=int(vehicle.deliveries)
	return false

func choose(id:String) -> bool:
	if not unlocked(id):return false
	selected=id;save_progress();return true

func award(receipt:Dictionary) -> bool:
	if receipt.is_empty() or not receipt.has("job_id") or int(receipt.get("packages",0))<=0:return false
	if receipts.has(str(receipt.job_id)):return false
	receipts.append(str(receipt.job_id));deliveries+=1;save_progress();return true

func save_progress() -> void:
	if not persistent:return
	var cfg:=ConfigFile.new()
	cfg.set_value("progress","deliveries",deliveries);cfg.set_value("progress","receipts",receipts)
	cfg.set_value("progress","vehicle",selected);save_error=cfg.save(path)
