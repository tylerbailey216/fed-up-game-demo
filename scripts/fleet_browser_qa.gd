extends Node
## Explicit qa=fleet fixture. Career remains ephemeral; never loaded in normal play.
var game:Node
var clock:=0.0
func _process(delta:float) -> void:
	clock+=delta
	if clock<.1:return
	clock=0
	var command:String=str(JavaScriptBridge.eval("window.fedupFleetCommand || ''"))
	if not command.is_empty():
		JavaScriptBridge.eval("window.fedupFleetCommand=''")
		if command=="unlock":
			for i in 5:game.fleet.award({"job_id":"fixture-%d" % i,"packages":12})
			game.garage.inspect(game.fleet.selected)
		elif command=="garage":
			game.return_to_menu();game.has_started=false;game.open_garage()
		elif command=="flight":game.flight.toggle()
	var cards:Array=[]
	for card in game.garage.cards:
		var rect:Rect2=card.get_global_rect()
		cards.append({"id":card.vehicle.id,"locked":card.locked,"x":rect.get_center().x,"y":rect.get_center().y,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
	var confirm:Rect2=game.garage.confirm.get_global_rect()
	var state:Dictionary={"garage":game.garage.visible,"vehicle":game.vehicle_id,"driving":game.driving,"deliveries":game.fleet.deliveries,"cards":cards,"confirm":[confirm.get_center().x,confirm.get_center().y],"disabled":game.garage.confirm.disabled,"viewport":[game.garage.size.x,game.garage.size.y],"y":game.van.position.y,"flight":game.flight.enabled,"wheels":game.vehicle_visuals.wheels.size()}
	state.actions=[]
	for action in game.garage.actions:
		var bounds:Rect2=action.get_global_rect();state.actions.append([bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y])
	if game.flight_button:
		var button:Vector2=game.flight_button.get_global_rect().get_center();state.flight_button=[button.x,button.y]
	JavaScriptBridge.eval("window.fedupFleet="+JSON.stringify(state))
