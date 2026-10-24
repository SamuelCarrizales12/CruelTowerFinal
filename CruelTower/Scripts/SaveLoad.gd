extends Node

# Usamos %d como marcador para insertar el número del slot dinámicamente
const SAVE_PATH_TEMPLATE: String = "user://save_slot_%d.dat"
const ESCENA_JUEGO: String = "uid://b3wdss57u3gxq" # res://Scenes/escenaprueba.tscn

# true = viene de "Nueva Partida", false = viene de "Continuar Partida"
var es_nueva_partida: bool = true

# Slot seleccionado actualmente (1, 2 o 3)
var current_slot: int = 1

# Estructura base de datos
var contents_to_save: Dictionary = _default_data()

# Valores iniciales de una partida nueva
func _default_data() -> Dictionary:
	return {
		"progress_bar_value": 0.0,
		"new_data_to_save": false,
		"save_date": "",         # Ej: "17/10/2026 21:40"
		"level_name": "Nivel 1", # Ej: "Bosque Encantado"
		"play_time": "00:00"     # Tiempo jugado
	}

# Obtiene la ruta formateada según el número de slot
func _get_save_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot

# Reinicia los datos y crea el archivo del slot desde cero
func new_game(slot: int) -> void:
	contents_to_save = _default_data()
	save_game(slot)

# Guardar en un slot específico (por defecto usa current_slot)
func save_game(slot: int = current_slot) -> void:
	current_slot = slot
	var path = _get_save_path(slot)
	
	# Guardamos la fecha actual en el diccionario
	var datetime = Time.get_datetime_dict_from_system()
	contents_to_save["save_date"] = "%02d/%02d/%04d %02d:%02d" % [
		datetime.day, datetime.month, datetime.year,
		datetime.hour, datetime.minute
	]
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(contents_to_save)
		file.close()

# Cargar desde un slot específico
func load_game(slot: int = current_slot) -> bool:
	current_slot = slot
	var path = _get_save_path(slot)
	
	if not FileAccess.file_exists(path):
		print("El slot %d no existe. Usando valores por defecto." % slot)
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Error al cargar el slot %d: %s" % [slot, FileAccess.get_open_error()])
		return false
		
	var loaded_data = file.get_var()
	file.close()
	
	if loaded_data is Dictionary:
		# Partimos de los valores por defecto y encima aplicamos lo guardado
		contents_to_save = _default_data()
		contents_to_save.merge(loaded_data, true)
		_apply_loaded_data()
		print("Slot %d cargado correctamente." % slot)
		return true
		
	return false

# Verifica si existe partida en un slot determinado (útil para la UI)
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))

# Borra el archivo de un slot
func delete_slot(slot: int) -> void:
	var path = _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Slot %d eliminado." % slot)

func _apply_loaded_data() -> void:
	# Aplica los datos cargados a tu partida
	pass

## Retorna un diccionario con los datos del slot sin sobreescribir el estado global en memoria
func get_slot_info(slot: int) -> Dictionary:
	var path: String = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var()
	file.close()
	if data is Dictionary:
		return data
	return {}

## Inicializa una partida nueva con datos limpios y la guarda en el slot indicado
func create_new_game(slot: int) -> void:
	current_slot = slot
	contents_to_save = {
		"progress_bar_value": 0.0,
		"new_data_to_save": true,
		"save_date": "",
		"level_name": "Nivel 1",
		"play_time": "00:00"
	}
	save_game(slot)

