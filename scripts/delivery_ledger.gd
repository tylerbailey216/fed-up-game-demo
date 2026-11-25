extends RefCounted
## Stable consignment IDs and idempotent delivery receipts; no scene/physics ownership.
var job_id:=""
var manifest:Dictionary={}
var receipt_issued:=false
var load_lost:=false

func begin(count:int,id:="") -> void:
	job_id=id if not id.is_empty() else "%d-%d" % [int(Time.get_unix_time_from_system()*1000000),randi()]
	manifest.clear();receipt_issued=false;load_lost=false
	for i in count:manifest[i]="aboard"

func lose_load() -> void:
	if receipt_issued or load_lost:return
	load_lost=true
	for id in manifest:manifest[id]="lost"

func recover(id:int) -> bool:
	if receipt_issued or not manifest.has(id) or manifest[id]!="lost":return false
	manifest[id]="aboard";return true

func ready() -> bool:
	return not manifest.is_empty() and not manifest.values().has("lost")

func receipt(route_clear:bool,stopped:bool) -> Dictionary:
	if receipt_issued or not route_clear or not stopped or not ready():return {}
	receipt_issued=true
	for id in manifest:manifest[id]="delivered"
	return {"job_id":job_id,"packages":manifest.size(),"delivered_at":Time.get_unix_time_from_system()}
