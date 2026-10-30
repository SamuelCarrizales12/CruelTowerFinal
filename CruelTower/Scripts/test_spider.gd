extends Node3D

@onready var anim_player: AnimationPlayer = $SpiderModel/AnimationPlayer
@onready var label_info: Label3D = $LabelInfo
@onready var spider_model: Node3D = $SpiderModel

var lista_animaciones: Array[String] = [
	"spider_idle",
	"spider_walk",
	"Action_AnimRun__spider_walk",
	"spider_attack",
	"spider_bite",
	"spider_lashr",
	"spider_hit1",
	"spider_death1",
	"spider_death2"
]

var todas_las_animaciones: Array[String] = []
var indice_actual: int = 0
var escala_reducida: bool = true

func _ready() -> void:
	if anim_player:
		todas_las_animaciones.assign(anim_player.get_animation_list())
		# Reproducir primera animación en loop para visualización
		reproducir_por_indice(0, true)
	_actualizar_escala()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return

	# Teclas 1 a 9
	for i in range(1, 10):
		if event.keycode == (KEY_0 + i):
			reproducir_por_indice(i - 1)
			return

	# Tecla T: alternar escala original (1.0 = ~20 m) vs escala adaptada (0.075 = ~1.8 m)
	if event.keycode == KEY_T:
		escala_reducida = not escala_reducida
		_actualizar_escala()

	# Tecla L: alternar loop en la animación actual
	if event.keycode == KEY_L:
		_toggle_loop()

	# Flechas izquierda/derecha para navegar todas las 41 animaciones
	if event.keycode == KEY_RIGHT:
		indice_actual = (indice_actual + 1) % todas_las_animaciones.size()
		reproducir_nombre(todas_las_animaciones[indice_actual])
	elif event.keycode == KEY_LEFT:
		indice_actual = (indice_actual - 1 + todas_las_animaciones.size()) % todas_las_animaciones.size()
		reproducir_nombre(todas_las_animaciones[indice_actual])


func reproducir_por_indice(idx: int, forzar_loop: bool = false) -> void:
	if idx < 0 or idx >= lista_animaciones.size() or not anim_player:
		return
	indice_actual = idx
	var nombre = lista_animaciones[idx]
	reproducir_nombre(nombre, forzar_loop)


func reproducir_nombre(nombre_clip: String, forzar_loop: bool = false) -> void:
	if not anim_player or not anim_player.has_animation(nombre_clip):
		return

	var anim = anim_player.get_animation(nombre_clip)
	if forzar_loop:
		anim.loop_mode = Animation.LOOP_LINEAR

	anim_player.play(nombre_clip)
	_actualizar_label(nombre_clip, anim)


func _toggle_loop() -> void:
	if not anim_player or not anim_player.current_animation:
		return
	var cur_name = anim_player.current_animation
	var anim = anim_player.get_animation(cur_name)
	if anim.loop_mode == Animation.LOOP_NONE:
		anim.loop_mode = Animation.LOOP_LINEAR
	else:
		anim.loop_mode = Animation.LOOP_NONE
	_actualizar_label(cur_name, anim)


func _actualizar_escala() -> void:
	if not spider_model:
		return
	if escala_reducida:
		spider_model.scale = Vector3(0.075, 0.075, 0.075)
		spider_model.position = Vector3(1.5, 0.0, 0.0)
	else:
		spider_model.scale = Vector3.ONE
		spider_model.position = Vector3(5.0, 0.0, 0.0)
	
	if anim_player and anim_player.current_animation:
		_actualizar_label(anim_player.current_animation, anim_player.get_animation(anim_player.current_animation))


func _actualizar_label(nombre_clip: String, anim: Animation) -> void:
	if not label_info:
		return
	var loop_str = "SÍ" if anim.loop_mode != Animation.LOOP_NONE else "NO"
	var escala_str = "1.8 m (x0.075)" if escala_reducida else "ORIGINAL (20 m x 27 m)"
	label_info.text = "ENEMIGO SPIDER (DND Heroes VisKit)\n" + \
		"Clip: " + nombre_clip + " (" + str(snapped(anim.length, 0.01)) + " s)\n" + \
		"Loop: " + loop_str + " | Escala: " + escala_str + "\n" + \
		"[Teclas 1-9: Atajos | T: Escala | L: Loop | Flechas: 41 Clips]"
