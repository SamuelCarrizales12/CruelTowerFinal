extends CharacterBody3D

const SPEED = 2.5
const SPEED_RUN = 3.5
const MOUSE_SENSITIVITY = 0.003

@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm = $CameraPivot/SpringArm3D
@onready var raycast = $CameraPivot/SpringArm3D/Camera3D/RayCast3D
@onready var camara = $CameraPivot/SpringArm3D/Camera3D
@onready var mirilla = $CanvasLayer/ColorRect

const FOV_NORMAL = 75.0
const FOV_APUNTADO = 40.0
var esta_disparando = false
var tiempo_paso = 0.0

var tiene_pistola = false
@onready var texto_interaccion = $CanvasLayer/Label
@onready var texto_municion = $CanvasLayer/TextoMunicion
@onready var barra_vida = $CanvasLayer/BarraVida

var municion_actual := 12
var tamano_cargador := 12
var municion_reserva := 36
var recargando := false

var salud_maxima := 100
var salud_actual := 100
var vector_retroceso := Vector3.ZERO

var coleccionables_obtenidos := []
var esta_muerto := false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	barra_vida.max_value = salud_maxima
	barra_vida.value = salud_actual
	
	# --- TELEMETRÍA ---
	add_to_group("jugador")
	Telemetria.iniciar_run(self, str(SaveLoad.contents_to_save.get("level_name", "Nivel 1")))

func _unhandled_input(event):
	if esta_disparando:
		return
		
	if event is InputEventMouseMotion:
		pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-75), deg_to_rad(45))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not esta_disparando:	
		var velocidad_actual = SPEED
		if Input.is_action_pressed("correr") and not Input.is_action_pressed("apuntar"):
			velocidad_actual = SPEED_RUN
			
		var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
		var direction := (pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
		if direction:
			velocity.x = direction.x * velocidad_actual
			velocity.z = direction.z * velocidad_actual
		else:
			velocity.x = move_toward(velocity.x, 0, velocidad_actual)
			velocity.z = move_toward(velocity.z, 0, velocidad_actual)
	
		if Input.is_action_just_pressed("disparar") and tiene_pistola and not recargando:
			disparar()
		
		if Input.is_action_just_pressed("recargar") and tiene_pistola and not recargando:
			recargar()
			
		if Input.is_action_just_pressed("interactuar"):
			raycast.force_raycast_update()
			if raycast.is_colliding():
				var objeto_mirado = raycast.get_collider()
				
				# Si el objeto tiene la función 'recoger', se ejecuta
				if objeto_mirado.has_method("recoger"):
					var distancia = global_position.distance_to(objeto_mirado.global_position)
					if distancia <= 3.0:
						objeto_mirado.recoger(self)
			
		if direction and is_on_floor() and not esta_disparando:
			tiempo_paso += delta * velocity.length() * 1.5
			var amplitud = 0.02
			if velocidad_actual == SPEED_RUN:
				amplitud = 0.06
				
			camara.h_offset = cos(tiempo_paso * 0.5) * amplitud
			camara.v_offset = sin(tiempo_paso) * amplitud
		else:
			camara.h_offset = lerp(camara.h_offset, 0.0, 8.0 * delta)
			camara.v_offset = lerp(camara.v_offset, 0.0, 8.0 * delta)
			
		if Input.is_action_pressed("apuntar"):
			camara.fov = lerp(camara.fov, FOV_APUNTADO, 10.0 * delta)
		else:
			camara.fov = lerp(camara.fov, FOV_NORMAL, 10.0 * delta)
	
	else:
		velocity.x = lerp(velocity.x, 0.0, 8.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 8.0 * delta)
		
	# --- LÓGICA DE COLOR DE LA MIRA Y TEXTO DE INTERACCIÓN ---
	if raycast.is_colliding():
		var objetivo_mirado = raycast.get_collider()
		if is_instance_valid(objetivo_mirado):
			# 1. Si miramos a un enemigo
			if objetivo_mirado.has_method("recibir_dano") or objetivo_mirado.has_method("alertar"):
				mirilla.color = Color(0.714, 0.0, 0.157, 1.0) 
				texto_interaccion.visible = false
			# 2. Si miramos a un objeto interactuable
			elif objetivo_mirado.has_method("recoger"):
				var distancia = global_position.distance_to(objetivo_mirado.global_position)
				if distancia <= 3.0:
					mirilla.color = Color(1, 1, 1) 
					texto_interaccion.visible = true
					texto_interaccion.text = "Presiona [ E ] para interactuar"
				else:
					mirilla.color = Color(1, 1, 1)
					texto_interaccion.visible = false
			# 3. Si es pared o suelo
			else:
				mirilla.color = Color(1, 1, 1) 
				texto_interaccion.visible = false
		else:
			mirilla.color = Color(1, 1, 1)
			texto_interaccion.visible = false
	else:
		mirilla.color = Color(1, 1, 1)
		texto_interaccion.visible = false
	
	if vector_retroceso.length() > 0.1:
		velocity.x += vector_retroceso.x
		velocity.z += vector_retroceso.z
		
		vector_retroceso = vector_retroceso.lerp(Vector3.ZERO, 10.0 * delta)
	else:
		vector_retroceso = Vector3.ZERO
		
	move_and_slide()
	
	if tiene_pistola:
		texto_municion.visible = true
		texto_municion.text = str(municion_actual) + " / " + str(municion_reserva)
	else:
		texto_municion.visible = false

func disparar():
	if municion_actual <= 0:
		print("Cargador vacío")
		return
		
	municion_actual -= 1
	Telemetria.evento("shot", {"ammo": municion_actual})
	esta_disparando = true
	
	var direccion_retroceso = pivot.transform.basis.z.normalized()
	velocity.x = direccion_retroceso.x * 10.0
	velocity.z = direccion_retroceso.z * 10.0
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var objetivo = raycast.get_collider()
		
		if objetivo.has_method("recibir_dano"):
			var direccion_tiro = global_position.direction_to(objetivo.global_position)
			objetivo.recibir_dano(35, direccion_tiro, self)
		
	var tween = create_tween()
	var posicion_original_z = 7.0
	
	tween.tween_property(camara, "position:z", 0.5, 0.0)
	tween.tween_property(camara, "position:z", posicion_original_z, 0.8)
	tween.tween_callback(func(): esta_disparando = false)

func recargar():
	if municion_actual == tamano_cargador or municion_reserva <= 0:
		return
	
	recargando = true
	Telemetria.evento("reload")
	print("Recargando...")
	
	await get_tree().create_timer(1.5).timeout
	var balas_faltantes = tamano_cargador - municion_actual
	
	if municion_reserva >= balas_faltantes:
		municion_reserva -= balas_faltantes
		municion_actual += balas_faltantes
	else:
		municion_actual += municion_reserva
		municion_reserva = 0
		
	recargando = false
	print("Arma lista. Munición: ", municion_actual, "/", municion_reserva)

func recibir_dano(cantidad: int, direccion_impacto: Vector3 = Vector3.ZERO, _atacante: Node3D = null):
	if esta_muerto:
		return
	
	salud_actual -= cantidad
	barra_vida.value = salud_actual
	
	# --- TELEMETRÍA: quién nos golpeó ---
	var fuente := "desconocido"
	if _atacante != null and _atacante.get("nombre_manada") != null:
		fuente = str(_atacante.get("nombre_manada"))
	Telemetria.evento("damage_taken", {"amount": cantidad, "hp": salud_actual, "source": fuente})
	
	if direccion_impacto != Vector3.ZERO:
		vector_retroceso = direccion_impacto * 3.0 
		velocity.y = 5.0 
	
	if salud_actual <= 0:
		print("¡ESTÁS MUERTO!")
		esta_muerto = true
		Telemetria.muerte(fuente)
		# Opcional: reiniciar el nivel para poder volver a intentarlo (y medir más muertes):
		# get_tree().create_timer(1.5).timeout.connect(func(): get_tree().reload_current_scene())

func curar(cantidad: int):
	Telemetria.evento("heal", {"amount": cantidad})
	salud_actual += cantidad
	if salud_actual > salud_maxima:
		salud_actual = salud_maxima
	
	barra_vida.value = salud_actual
