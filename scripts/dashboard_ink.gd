extends RefCounted
## Original live vector controls adapted from the supplied FedUp UI sheet.
const INK:=Color("10121e")
const GOLD:=Color("ffd044")
const CREAM:=Color("f3ebd8")
static var textures:Dictionary={}
static func texture(key:String,body:String,box:String,pixels:Vector2i) -> Texture2D:
	if not textures.has(key):
		var svg:="<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='%s'>%s</svg>" % [pixels.x,pixels.y,box,body]
		var image:=Image.new();var error:=image.load_svg_from_string(svg)
		assert(error==OK,"HUD vector cache could not rasterize: "+key)
		textures[key]=ImageTexture.create_from_image(image)
	return textures[key]
static func plate(c:CanvasItem,r:Rect2,pressed:=false,purple:=false) -> void:
	var w:=r.size.x;var h:=r.size.y
	var key:="plate-%s-%s-%s" % [r.size,pressed,purple]
	if textures.has(key):
		c.draw_texture_rect(textures[key],r.grow(4),false);return
	var pts:="8,0 %f,0 %f,%f %f,%f 0,%f 0,8" % [w-4,w,h-8,w-8,h,h]
	var body:="<polygon points='%s' fill='#%s' stroke='#10121e' stroke-width='7'/><polygon points='%s' fill='none' stroke='#ffd044' stroke-width='2'/><path d='M10 5 H%f' stroke='#c2a8c1'/>" % [pts,"8b5cb1" if pressed else "282333",pts,w-9]
	if purple:body+="<path d='M7 %f H%f' stroke='#8953b4' stroke-width='4'/>" % [h-5,w-10]
	for at in [Vector2(6,11),Vector2(w-6,h-11)]:body+="<circle cx='%f' cy='%f' r='2.5' fill='#10121e'/><path d='M%f %f h2' stroke='#bda98e'/>" % [at.x,at.y,at.x-1,at.y]
	c.draw_texture_rect(texture(key,body,"-4 -4 %f %f" % [w+8,h+8],Vector2i(ceil((w+8)*2),ceil((h+8)*2))),r.grow(4),false)
static func hatch(c:CanvasItem,rect:Rect2) -> void:
	var body:=""
	if not textures.has("hatch"):
		for x in range(6,720,18):body+="<path d='M%d 12 l9 -8' stroke='#6e516a'/>" % x
	c.draw_texture_rect(texture("hatch",body,"0 0 720 14",Vector2i(1440,28)),rect,false)
static func line(c:CanvasItem,pts:Array,at:Vector2,s:float,tone:Color,width:=2.0) -> void:
	var path:=PackedVector2Array()
	for point in pts:path.append(at+Vector2(point[0],point[1])*s)
	c.draw_polyline(path,tone,width,true)
static func icon(c:CanvasItem,key:String,at:Vector2,s:float,tone:=CREAM) -> void:
	var paths:Dictionary={
		"camera":"<path d='M-11 -6 H-6 L-3 -10 H5 L8 -6 H12 V9 H-11 Z'/><circle cx='1' cy='1' r='5'/>",
		"map":"<path d='M-12 -8 L-4 -11 L4 -7 L12 -10 V9 L4 12 L-4 8 L-12 11 Z M-4 -10 V8 M4 -6 V12'/>",
		"options":"<circle r='8' stroke-width='3'/><path d='M-12 0 H12 M0 -12 V12 M-9 -9 L9 9 M-9 9 L9 -9' stroke-width='4'/><circle r='4' fill='#10121e' stroke='none'/>",
		"exit":"<path d='M1 -12 H-10 V12 H1 M-4 0 H13 L7 -6 M13 0 L7 6'/>",
		"fuel":"<path d='M-9 11 V-11 H3 V11 H-12 M3 11 H6 M-6 -7 H0 V-1 H-6 Z M4 -8 L9 -3 V7 H6 V1 H3'/>",
		"engine":"<path d='M-12 -5 H-6 V-9 H5 V-5 H11 V7 H7 L4 10 H-7 V5 H-12 Z'/>",
		"lights":"<path d='M1 -8 L8 -5 V5 L1 8 Z M-11 -6 H-3 M-11 0 H-3 M-11 6 H-3'/>",
		"temp":"<path d='M0 -11 V3 M5 -6 H11 M5 0 H11 M5 6 H11'/><circle cy='6' r='4' fill='currentColor'/>",
		"hand":"<circle r='10'/><path d='M-14 -7 L-16 0 L-14 7 M14 -7 L16 0 L14 7 M-3 6 V-6 H3 L5 -3 L3 0 H-3'/>",
		"upright":"<path d='M-8 -6 A10 10 0 1 1 -5 9 M-10 -7 V0 L-3 -4'/>",
		"left":"<path d='M-11 0 L-2 -8 V-4 H11 V4 H-2 V8 Z' fill='currentColor' stroke='none'/>",
		"right":"<path d='M11 0 L2 -8 V-4 H-11 V4 H2 V8 Z' fill='currentColor' stroke='none'/>"}
	if not paths.has(key):return
	var body:="<g stroke='#%s' color='#%s' fill='none' stroke-width='2' stroke-linejoin='round' stroke-linecap='round'>%s</g>" % [tone.to_html(false),tone.to_html(false),paths[key]]
	c.draw_texture_rect(texture(key+tone.to_html(),body,"-18 -18 36 36",Vector2i(96,96)),Rect2(at-Vector2.ONE*18*s,Vector2.ONE*36*s),false)
static func wheel(c:Control,r:Rect2,steer:float,moving:Vector2) -> void:
	if not textures.has("wheel"):
		var body:="<circle r='93' fill='#121019' fill-opacity='.48'/><circle r='84' fill='none' stroke='#10121e' stroke-width='17'/><circle r='84' fill='none' stroke='#8a6b68' stroke-width='10'/><path d='M-87 0 A87 87 0 0 1 87 0' fill='none' stroke='#efc28e' stroke-width='3'/><circle r='79' fill='none' stroke='#372b40' stroke-width='3'/>"
		for i in 28:
			var d:=Vector2.from_angle(TAU*i/28);body+="<path d='M%f %f L%f %f' stroke='#dbb69b'/>" % [d.x*82,d.y*82,d.x*85,d.y*85]
		for i in 3:
			var d:=Vector2.from_angle(TAU*i/3);body+="<path d='M0 0 L%f %f' stroke='#10121e' stroke-width='13'/><path d='M0 0 L%f %f' stroke='#766173' stroke-width='7'/>" % [d.x*75,d.y*75,d.x*75,d.y*75]
		body+="<circle r='20' fill='#10121e'/><circle cy='-2' r='16' fill='#4f3b64'/>"
		texture("wheel",body,"-100 -100 200 200",Vector2i(400,400))
	var at:=r.get_center();var factor:=c.size.x/720
	c.draw_set_transform(at*factor,steer*1.8,Vector2.ONE*factor)
	c.draw_texture_rect(textures.wheel,Rect2(-r.size/2,r.size),false)
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	if not moving.is_zero_approx():c.draw_circle(at+moving.limit_length()*r.size.x*.21,6,GOLD)
