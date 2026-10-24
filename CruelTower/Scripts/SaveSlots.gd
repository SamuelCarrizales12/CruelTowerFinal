class_name SaveSlotsMenu
extends Control

## Ruta de la escena principal jugable y del menú de inicio
const PLAYABLE_SCENE_PATH: String = "res://escenaprueba.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://Menu Inicio.tscn"

# Texturas de madera originales para los botones
const TEX_CONTINUAR: Texture2D = preload("res://Iconos/BotonesInicio/Boton CP.png")
const TEX_CONTINUAR_P: Texture2D = preload("res://Iconos/Botones presionados/Boton CPP.png")
const TEX_NUEVA: Texture2D = preload("res://Iconos/BotonesInicio/Boton NP.png")
const TEX_NUEVA_P: Texture2D = preload("res://Iconos/Botones presionados/Boton NPP.png")

# Referencias a los componentes de la interfaz
@onready var title_label: Label = %TitleLabel if has_node("%TitleLabel") else null
@onready var btn_return: TextureButton = %BtnReturn if has_node("%BtnReturn") else null
@onready var slots_hbox: HBoxContainer = %SlotsHBox if has_node("%SlotsHBox") else null

# Diccionario de tweens activos para evitar competencia de animaciones
var _tweens: Dictionary = {}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_viga_and_chains()
	_setup_return_button()
	_setup_slots()
	update_all_slots_ui()
	_play_intro_animation()

## Asegura que la viga y las cadenas carguen correctamente sus texturas
func _setup_viga_and_chains() -> void:
	var viga_tex: Texture2D = null
	if ResourceLoader.exists("res://VIGA.png"):
		viga_tex = load("res://VIGA.png")
	if viga_tex == null:
		var img := Image.load_from_file("res://VIGA.png")
		if img:
			viga_tex = ImageTexture.create_from_image(img)
			
	var viga: TextureRect = get_node_or_null("VigaTexture")
	if is_instance_valid(viga) and viga_tex:
		viga.texture = viga_tex
		
	var chain_tex: Texture2D = null
	if ResourceLoader.exists("res://Cadena.png"):
		chain_tex = load("res://Cadena.png")
	if chain_tex == null:
		var cimg := Image.load_from_file("res://Cadena.png")
		if cimg:
			chain_tex = ImageTexture.create_from_image(cimg)
			
	for slot_idx in range(1, 4):
		var slot_card := _get_slot_node(slot_idx)
		if is_instance_valid(slot_card) and chain_tex:
			for chain_name in ["ChainLeft", "ChainRight"]:
				var chain: TextureRect = slot_card.get_node_or_null(chain_name)
				if is_instance_valid(chain):
					chain.texture = chain_tex

## Configura el botón de retorno superior derecho
func _setup_return_button() -> void:
	if not is_instance_valid(btn_return):
		return
		
	btn_return.pivot_offset = btn_return.size / 2.0
	btn_return.resized.connect(func():
		if is_instance_valid(btn_return):
			btn_return.pivot_offset = btn_return.size / 2.0
	)
	
	btn_return.pressed.connect(_on_return_pressed)
	btn_return.mouse_entered.connect(_on_widget_hovered.bind(btn_return, 1.06, Color(1.15, 1.10, 1.02, 1.0)))
	btn_return.mouse_exited.connect(_on_widget_unhovered.bind(btn_return))
	btn_return.focus_entered.connect(_on_widget_hovered.bind(btn_return, 1.06, Color(1.15, 1.10, 1.02, 1.0)))
	btn_return.focus_exited.connect(_on_widget_unhovered.bind(btn_return))
	btn_return.button_down.connect(_on_widget_pressed.bind(btn_return, 0.95))
	btn_return.button_up.connect(_on_widget_hovered.bind(btn_return, 1.06, Color(1.15, 1.10, 1.02, 1.0)))

## Conecta y prepara las 3 ranuras
func _setup_slots() -> void:
	for slot_idx in range(1, 4):
		var slot_card: Control = _get_slot_node(slot_idx)
		if not is_instance_valid(slot_card):
			continue
			
		slot_card.pivot_offset = slot_card.custom_minimum_size / 2.0
		slot_card.resized.connect(func():
			if is_instance_valid(slot_card):
				slot_card.pivot_offset = slot_card.size / 2.0
		)
		
		# Animación hover suave en toda la tarjeta del slot
		slot_card.mouse_entered.connect(_on_widget_hovered.bind(slot_card, 1.02, Color(1.06, 1.04, 1.01, 1.0)))
		slot_card.mouse_exited.connect(_on_widget_unhovered.bind(slot_card))
		
		var btn_action: TextureButton = slot_card.get_node_or_null("BottomFrame/BtnAction")
		if is_instance_valid(btn_action):
			btn_action.pivot_offset = btn_action.custom_minimum_size / 2.0
			btn_action.resized.connect(func():
				if is_instance_valid(btn_action):
					btn_action.pivot_offset = btn_action.size / 2.0
			)
			btn_action.pressed.connect(_on_slot_action_pressed.bind(slot_idx))
			btn_action.mouse_entered.connect(_on_widget_hovered.bind(btn_action, 1.05, Color(1.15, 1.10, 1.02, 1.0)))
			btn_action.mouse_exited.connect(_on_widget_unhovered.bind(btn_action))
			btn_action.focus_entered.connect(_on_widget_hovered.bind(btn_action, 1.05, Color(1.15, 1.10, 1.02, 1.0)))
			btn_action.focus_exited.connect(_on_widget_unhovered.bind(btn_action))
			btn_action.button_down.connect(_on_widget_pressed.bind(btn_action, 0.96))
			btn_action.button_up.connect(_on_widget_hovered.bind(btn_action, 1.05, Color(1.15, 1.10, 1.02, 1.0)))
			
		var btn_delete: TextureButton = slot_card.get_node_or_null("TopRightFrame/BtnDelete")
		if is_instance_valid(btn_delete):
			btn_delete.pivot_offset = btn_delete.size / 2.0
			btn_delete.resized.connect(func():
				if is_instance_valid(btn_delete):
					btn_delete.pivot_offset = btn_delete.size / 2.0
			)
			btn_delete.pressed.connect(_on_slot_delete_pressed.bind(slot_idx))
			btn_delete.mouse_entered.connect(_on_widget_hovered.bind(btn_delete, 1.08, Color(1.15, 0.95, 0.95, 1.0)))
			btn_delete.mouse_exited.connect(_on_widget_unhovered.bind(btn_delete))
			btn_delete.button_down.connect(_on_widget_pressed.bind(btn_delete, 0.92))
			btn_delete.button_up.connect(_on_widget_hovered.bind(btn_delete, 1.08, Color(1.15, 0.95, 0.95, 1.0)))

## Actualiza la información visual de todos los slots
func update_all_slots_ui() -> void:
	for slot_idx in range(1, 4):
		_update_slot_card_ui(slot_idx)

## Refresca los textos, texturas y estados de un slot específico sin emojis
func _update_slot_card_ui(slot_idx: int) -> void:
	var slot_card: Control = _get_slot_node(slot_idx)
	if not is_instance_valid(slot_card):
		return
		
	var lbl_title: Label = slot_card.get_node_or_null("TopLeftFrame/SlotTitle")
	var lbl_status: Label = slot_card.get_node_or_null("TopLeftFrame/SlotStatus")
	var btn_delete: TextureButton = slot_card.get_node_or_null("TopRightFrame/BtnDelete")
	var lbl_level: Label = slot_card.get_node_or_null("BottomFrame/InfoContainer/LevelLabel")
	var lbl_meta: Label = slot_card.get_node_or_null("BottomFrame/InfoContainer/MetaLabel")
	var btn_action: TextureButton = slot_card.get_node_or_null("BottomFrame/BtnAction")
	
	if is_instance_valid(lbl_title):
		lbl_title.text = "RANURA %d" % slot_idx
		
	var has_saved_game: bool = SaveLoad.has_save(slot_idx)
	
	if has_saved_game:
		# Slot Ocupado
		if is_instance_valid(lbl_status):
			lbl_status.text = "OCUPADO"
			lbl_status.modulate = Color(0.95, 0.82, 0.45, 1.0)
			
		if is_instance_valid(btn_delete):
			btn_delete.visible = true
			
		var info: Dictionary = {}
		if SaveLoad.has_method("get_slot_info"):
			info = SaveLoad.get_slot_info(slot_idx)
		else:
			info = SaveLoad.contents_to_save
			
		var level_text: String = str(info.get("level_name", "Nivel 1"))
		var date_text: String = str(info.get("save_date", "Reciente"))
		var time_text: String = str(info.get("play_time", "00:00"))
		
		if is_instance_valid(lbl_level):
			lbl_level.text = level_text
			lbl_level.visible = true
			
		if is_instance_valid(lbl_meta):
			lbl_meta.text = "%s  |  Tiempo: %s" % [date_text, time_text]
			lbl_meta.visible = true
			
		if is_instance_valid(btn_action):
			btn_action.texture_normal = TEX_CONTINUAR
			btn_action.texture_pressed = TEX_CONTINUAR_P
			btn_action.tooltip_text = "Continuar partida en Ranura %d" % slot_idx
	else:
		# Slot Vacío
		if is_instance_valid(lbl_status):
			lbl_status.text = "VACÍO"
			lbl_status.modulate = Color(0.70, 0.65, 0.58, 0.85)
			
		if is_instance_valid(btn_delete):
			btn_delete.visible = false
			
		if is_instance_valid(lbl_level):
			lbl_level.text = "Ranura Disponible"
			lbl_level.visible = true
			
		if is_instance_valid(lbl_meta):
			lbl_meta.text = "Sin partida guardada"
			lbl_meta.visible = true
			
		if is_instance_valid(btn_action):
			btn_action.texture_normal = TEX_NUEVA
			btn_action.texture_pressed = TEX_NUEVA_P
			btn_action.tooltip_text = "Crear nueva partida en Ranura %d" % slot_idx

## Acción al presionar Continuar o Nueva Partida
func _on_slot_action_pressed(slot_idx: int) -> void:
	if SaveLoad.has_save(slot_idx):
		print("Cargando partida del slot %d..." % slot_idx)
		SaveLoad.load_game(slot_idx)
	else:
		print("Creando nueva partida en slot %d..." % slot_idx)
		if SaveLoad.has_method("create_new_game"):
			SaveLoad.create_new_game(slot_idx)
		else:
			SaveLoad.save_game(slot_idx)
			
	get_tree().change_scene_to_file(PLAYABLE_SCENE_PATH)

## Acción al presionar Borrar
func _on_slot_delete_pressed(slot_idx: int) -> void:
	print("Eliminando slot %d..." % slot_idx)
	SaveLoad.delete_slot(slot_idx)
	_update_slot_card_ui(slot_idx)
	
	# Efecto visual de sacudida sutil en el slot al borrar
	var slot_card := _get_slot_node(slot_idx)
	if is_instance_valid(slot_card):
		_kill_tween(slot_card)
		var shake_tween := create_tween()
		shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		shake_tween.tween_property(slot_card, "scale", Vector2(0.95, 0.95), 0.1)
		shake_tween.tween_property(slot_card, "scale", Vector2.ONE, 0.15)

## Regreso al Menú Principal
func _on_return_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

## Animación de entrada inicial con retraso escalonado
func _play_intro_animation() -> void:
	if is_instance_valid(title_label):
		title_label.modulate.a = 0.0
		var title_tween := create_tween()
		title_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		title_tween.tween_property(title_label, "modulate:a", 1.0, 0.6)
		
	for i in range(1, 4):
		var card := _get_slot_node(i)
		if not is_instance_valid(card):
			continue
			
		card.modulate.a = 0.0
		card.scale = Vector2(0.9, 0.9)
		
		var card_tween := create_tween()
		card_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card_tween.tween_interval(0.1 + (i * 0.08))
		card_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.4)
		card_tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.4)

## Helpers de Tweens
func _on_widget_hovered(node: Control, scale_mult: float, mod_color: Color) -> void:
	if not is_instance_valid(node):
		return
	_kill_tween(node)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(scale_mult, scale_mult), 0.18)
	tween.tween_property(node, "modulate", mod_color, 0.18)
	_tweens[node] = tween

func _on_widget_unhovered(node: Control) -> void:
	if not is_instance_valid(node):
		return
	_kill_tween(node)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.2)
	tween.tween_property(node, "modulate", Color.WHITE, 0.2)
	_tweens[node] = tween

func _on_widget_pressed(node: Control, scale_mult: float) -> void:
	if not is_instance_valid(node):
		return
	_kill_tween(node)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(scale_mult, scale_mult), 0.08)
	_tweens[node] = tween

func _kill_tween(node: Control) -> void:
	if _tweens.has(node) and is_instance_valid(_tweens[node]):
		_tweens[node].kill()
	_tweens.erase(node)

func _get_slot_node(slot_idx: int) -> Control:
	if not is_instance_valid(slots_hbox):
		return null
	return slots_hbox.get_node_or_null("Slot" + str(slot_idx))
