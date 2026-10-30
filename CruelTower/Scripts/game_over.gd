extends CanvasLayer
class_name GameOverScreen

@onready var fondo_negro: ColorRect = $FondoNegro
@onready var contenido: Control = $Contenido
@onready var btn_reintentar: Button = $Contenido/VBoxContainer/BtnReintentar
@onready var btn_menu: Button = $Contenido/VBoxContainer/BtnMenu

var _mostrado: bool = false
var tween_anim: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	fondo_negro.modulate.a = 0.0
	contenido.modulate.a = 0.0
	
	if btn_reintentar:
		btn_reintentar.pressed.connect(_on_reintentar_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_menu_pressed)

func mostrar() -> void:
	if _mostrado:
		return
	_mostrado = true
	
	visible = true
	if is_inside_tree() and get_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Fundido de fondo negro (1.5 s), luego aparición de "HAS MUERTO" y botones
	if tween_anim and tween_anim.is_valid():
		tween_anim.kill()
	tween_anim = create_tween().set_parallel(false)
	tween_anim.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_anim.tween_property(fondo_negro, "modulate:a", 1.0, 1.5).from(0.0)
	tween_anim.tween_property(contenido, "modulate:a", 1.0, 0.8).from(0.0)

func _on_reintentar_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Menu Inicio.tscn")
