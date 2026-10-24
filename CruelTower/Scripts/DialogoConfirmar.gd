class_name DialogoConfirmar
extends Control
## Ventana de confirmación con el estilo del menú. Se construye por código.
## Uso:
##   var d := DialogoConfirmar.new()
##   d.titulo = "¿BORRAR PARTIDA?"
##   d.mensaje = "Esta acción no se puede deshacer."
##   d.texto_confirmar = "BORRAR"
##   d.confirmado.connect(mi_funcion)
##   add_child(d)

signal confirmado
signal cancelado

const FUENTE_PATH: String = "res://Recursos/Cinzel.ttf"

# Se asignan ANTES de add_child()
var titulo: String = "¿ESTÁS SEGURO?"
var mensaje: String = ""
var texto_confirmar: String = "CONFIRMAR"
var texto_cancelar: String = "CANCELAR"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS  # funciona también con el juego en pausa

	var fuente: Font = null
	if ResourceLoader.exists(FUENTE_PATH):
		fuente = load(FUENTE_PATH)

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.72)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	caja.custom_minimum_size = Vector2(420, 0)
	caja.add_theme_constant_override("separation", 16)
	panel.add_child(caja)

	caja.add_child(_etiqueta(titulo, 26, Color(0.96, 0.89, 0.74), fuente))
	if mensaje != "":
		var m := _etiqueta(mensaje, 15, Color(0.82, 0.76, 0.64), fuente)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size = Vector2(420, 0)
		caja.add_child(m)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 14)
	caja.add_child(botones)

	var btn_no := _boton(texto_cancelar, Color(0.22, 0.17, 0.16), fuente)
	btn_no.pressed.connect(_cancelar)
	botones.add_child(btn_no)

	# El botón de confirmar es rojizo para que se note que es una acción destructiva
	var btn_si := _boton(texto_confirmar, Color(0.5, 0.14, 0.16), fuente)
	btn_si.pressed.connect(_confirmar)
	botones.add_child(btn_si)

	btn_no.grab_focus.call_deferred()  # por defecto el foco queda en "cancelar": más seguro

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancelar()

func _confirmar() -> void:
	confirmado.emit()
	queue_free()

func _cancelar() -> void:
	cancelado.emit()
	queue_free()

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
