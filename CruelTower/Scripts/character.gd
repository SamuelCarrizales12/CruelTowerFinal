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

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	
		if Input.is_action_just_pressed("disparar") and tiene_pistola:
			disparar()
			
		if Input.is_action_just_pressed("interactuar"):
			raycast.force_raycast_update()
			if raycast.is_colliding():
				var objeto_mirado = raycast.get_collider()
				
				# Si el objeto tiene la función 'recoger', se ejecuta
				if objeto_mirado.has_method("recoger"):
					var distancia = global_position.distance_to(objeto_mirado.global_position)
					if distancia <= 1.0:
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
				if distancia <= 1.0:
					mirilla.color = Color(1, 1, 1) 
					texto_interaccion.visible = true
					texto_interaccion.text = "Presiona [ E ] para recoger arma"
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
		
	move_and_slide()

func disparar():
	esta_disparando = true
	var direccion_retroceso = pivot.transform.basis.z.normalized()
	velocity.x = direccion_retroceso.x * 10.0
	velocity.z = direccion_retroceso.z * 10.0
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var objetivo = raycast.get_collider() # Obtenemos el nodo golpeado
		
		if objetivo.has_method("recibir_dano"):
			var direccion_tiro = global_position.direction_to(objetivo.global_position)
			objetivo.recibir_dano(35, direccion_tiro, self)
		
	var tween = create_tween()
	var posicion_original_z = 7.0
	
	tween.tween_property(camara, "position:z", 0.5, 0.0)
	tween.tween_property(camara, "position:z", posicion_original_z, 0.8)
	tween.tween_callback(func(): esta_disparando = false)
