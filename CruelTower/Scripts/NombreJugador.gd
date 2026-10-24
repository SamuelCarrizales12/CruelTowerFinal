class_name DialogoNombre
extends Control
## Ventana emergente para escribir el nombre del jugador.
## Se construye por código con el estilo del menú (fuente Cinzel, marco dorado),
## así no depende de ninguna escena .tscn.

signal confirmado(nombre: String)
signal cancelado

const FUENTE_PATH: String = "res://Recursos/Cinzel.ttf"
const MIN_LARGO: int = 2
const MAX_LARGO: int = 14

# Se asignan ANTES de add_child()
var slot_num: int = 1
var nombre_inicial: String = ""

var _campo: LineEdit
var _error: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # bloquea los botones de las ranuras de atrás

	var fuente: Font = null
	if ResourceLoader.exists(FUENTE_PATH):
		fuente = load(FUENTE_PATH)

	# Fondo oscuro
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.72)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Tarjeta con marco dorado
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.045, 0.06, 0.97)
	estilo.border_color = Color(0.45, 0.35, 0.2, 0.9)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.shadow_color = Color(0, 0, 0, 0.7)
	estilo.shadow_size = 16
	estilo.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(400, 0)
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	caja.add_child(_etiqueta("NOMBRE DEL JUGADOR", 26, Color(0.96, 0.89, 0.74), fuente))
	caja.add_child(_etiqueta("Se guardará en la ranura %d" % slot_num, 14, Color(0.75, 0.68, 0.55), fuente))

	_campo = LineEdit.new()
	_campo.placeholder_text = "Escribe tu nombre"
	_campo.max_length = MAX_LARGO
	_campo.text = nombre_inicial
	_campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campo.custom_minimum_size = Vector2(0, 46)
	if fuente:
		_campo.add_theme_font_override("font", fuente)
	_campo.add_theme_font_size_override("font_size", 20)
	_campo.text_changed.connect(func(_t: String): _error.text = "")
	_campo.text_submitted.connect(func(_t: String): _confirmar())
	caja.add_child(_campo)

	_error = _etiqueta("", 13, Color(1.0, 0.45, 0.5), fuente)
	_error.custom_minimum_size = Vector2(0, 18)
	caja.add_child(_error)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 14)
	caja.add_child(botones)

	var btn_cancelar := _boton("CANCELAR", Color(0.22, 0.17, 0.16), fuente)
	btn_cancelar.pressed.connect(_cancelar)
	botones.add_child(btn_cancelar)

	var btn_ok := _boton("CONFIRMAR", Color(0.42, 0.30, 0.12), fuente)
	btn_ok.pressed.connect(_confirmar)
	botones.add_child(btn_ok)

	_campo.grab_focus.call_deferred()
	_campo.select_all.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancelar()

func _confirmar() -> void:
	var nombre: String = _campo.text.strip_edges()
	if nombre.length() < MIN_LARGO:
		_error.text = "Escribe al menos %d letras." % MIN_LARGO
		return
	var re := RegEx.new()
	re.compile("^[\\p{L}\\p{N}_ \\-]+$")
	if re.search(nombre) == null:
		_error.text = "Solo letras, números, espacios, - y _"
		return
	confirmado.emit(nombre)
	queue_free()

func _cancelar() -> void:
	cancelado.emit()
	queue_free()

# --- ayudas de estilo ---

func _etiqueta(texto: String, tam: int, color: Color, fuente: Font) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	l.add_theme_constant_override("outline_size", 4)
	if fuente:
		l.add_theme_font_override("font", fuente)
	return l

func _boton(texto: String, color: Color, fuente: Font) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	if fuente:
		b.add_theme_font_override("font", fuente)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = Color(0.45, 0.35, 0.2, 0.8)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.18)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	return b
