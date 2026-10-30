extends Node3D
class_name AnimadorEnemigo

signal animacion_terminada(nombre_logico: String)

## Mapeo de nombres lógicos a nombres reales en el AnimationPlayer
@export var mapa_animaciones: Dictionary = {
	"idle": "",
	"caminar": "",
	"correr": "",
	"atacar": "",
	"morir": ""
}

## Animación de respaldo si el nombre lógico solicitado no existe
@export var respaldo: Dictionary = {
	"caminar": "idle",
	"correr": "idle",
	"atacar": "idle",
	"morir": ""
}

## Eliminar desplazamiento del hueso raíz (root motion) para control por código
@export var neutralizar_root_motion: bool = true

## Nombre lógico actual en reproducción
var animacion_actual: String = ""

var _anim_player: AnimationPlayer = null

func _ready() -> void:
	_anim_player = _find_animation_player(self)
	if not _anim_player:
		push_warning("[AnimadorEnemigo] No se encontró AnimationPlayer en " + name)
		return
		
	# Conectar señal de fin de animación
	_anim_player.animation_finished.connect(_on_animation_finished)
	
	_configurar_animaciones()
			
	# Reproducir idle por defecto al iniciar
	if mapa_animaciones.has("idle") and mapa_animaciones["idle"] != "":
		reproducir("idle")

func _configurar_animaciones() -> void:
	if not _anim_player:
		return
	
	var clip_morir = mapa_animaciones.get("morir", "")
	var clip_atacar = mapa_animaciones.get("atacar", "")

	for anim_name in _anim_player.get_animation_list():
		var anim = _anim_player.get_animation(anim_name)
		if not anim:
			continue

		# Loop activado en idle, caminar y correr; sin loop en atacar y morir
		if anim_name == clip_atacar or anim_name == clip_morir:
			anim.loop_mode = Animation.LOOP_NONE
		else:
			anim.loop_mode = Animation.LOOP_LINEAR

		# Neutralizar root motion en traslación (sin aplanar la animación de muerte)
		if neutralizar_root_motion and anim_name != clip_morir:
			_neutralizar_traslacion_root(anim)

func reproducir(nombre_logico: String, velocidad: float = 1.0) -> void:
	if not _anim_player:
		return
		
	var clip_real: String = ""
	if mapa_animaciones.has(nombre_logico) and mapa_animaciones[nombre_logico] != "":
		clip_real = mapa_animaciones[nombre_logico]
	else:
		# Buscar en el mapa de respaldos
		if respaldo.has(nombre_logico) and respaldo[nombre_logico] != "":
			var nombre_respaldo = respaldo[nombre_logico]
			if mapa_animaciones.has(nombre_respaldo) and mapa_animaciones[nombre_respaldo] != "":
				clip_real = mapa_animaciones[nombre_respaldo]
				print("[AnimadorEnemigo] '" + nombre_logico + "' no existe en " + get_parent().name + ". Usando respaldo '" + nombre_respaldo + "' (" + clip_real + ").")
		
		if clip_real == "":
			print("[AnimadorEnemigo] Animación '" + nombre_logico + "' no disponible en " + get_parent().name + ". Sin cambios.")
			return

	if not _anim_player.has_animation(clip_real):
		print("[AnimadorEnemigo] Clip real '" + clip_real + "' no encontrado en AnimationPlayer de " + get_parent().name + ".")
		return
		
	# Asegurar loop_mode correcto en tiempo de reproducción
	var anim = _anim_player.get_animation(clip_real)
	if anim:
		if nombre_logico in ["atacar", "morir"]:
			anim.loop_mode = Animation.LOOP_NONE
		elif nombre_logico in ["idle", "caminar", "correr"]:
			anim.loop_mode = Animation.LOOP_LINEAR

	animacion_actual = nombre_logico
	_anim_player.play(clip_real, 0.2, velocidad)

func _on_animation_finished(clip_name: String) -> void:
	animacion_terminada.emit(animacion_actual)

func _neutralizar_traslacion_root(anim: Animation) -> void:
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var path_str = str(anim.track_get_path(t)).to_lower()
			if "root" in path_str or "hips" in path_str or "armature" in path_str:
				var kc = anim.track_get_key_count(t)
				if kc > 1:
					var p0 = anim.track_get_key_value(t, 0)
					for k in range(kc):
						anim.track_set_key_value(t, k, p0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found = _find_animation_player(c)
		if found:
			return found
	return null
