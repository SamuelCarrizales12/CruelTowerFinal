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
			#var look_dir = Vector2(velocity.z, velocity.x)
			#rotation.y = look_dir.angle()
		else:
			velocity.x = move_toward(velocity.x, 0, velocidad_actual)
			velocity.z = move_toward(velocity.z, 0, velocidad_actual)
	
		if Input.is_action_just_pressed("disparar"):
			disparar()
			
		if direction and is_on_floor() and not esta_disparando:
			tiempo_paso += delta * velocity.length() * 1.5
			var amplitud = 0.02
			if velocidad_actual == SPEED_RUN:
				amplitud = 0.06
				
			camara.h_offset = cos(tiempo_paso * 0.5) * amplitud
			camara.v_offset = sin(tiempo_paso) * amplitud
			#camara.rotation.x = cos(tiempo_paso * 0.5) * amplitud
			#camara.rotation.y = sin(tiempo_paso) * amplitud
		else:
			camara.h_offset = lerp(camara.h_offset, 0.0, 8.0 * delta)
			camara.v_offset = lerp(camara.v_offset, 0.0, 8.0 * delta)
			#camara.rotation.x = lerp(camara.rotation.x, 0.0, 8.0 * delta)
			#camara.rotation.y = lerp(camara.rotation.y, 0.0, 8.0 * delta)
			
		if Input.is_action_pressed("apuntar"):
			# lerp hace una transición suave entre el valor actual y el deseado
			camara.fov = lerp(camara.fov, FOV_APUNTADO, 10.0 * delta)
		else:
			camara.fov = lerp(camara.fov, FOV_NORMAL, 10.0 * delta)
	
	else:
		velocity.x = lerp(velocity.x, 0.0, 8.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 8.0 * delta)
		
	if raycast.is_colliding():
		var objetivo_mirado = raycast.get_collider()
		if objetivo_mirado.has_method("alertar"):
			mirilla.color = Color(0.714, 0.0, 0.157, 1.0) # Rojo
		else:
			mirilla.color = Color(1, 1, 1) # Blanco (si mira a una pared)
	else:
		mirilla.color = Color(1, 1, 1) # Blanco (si mira al vacío)
	move_and_slide()

func disparar():
	esta_disparando = true
	var direccion_retroceso = pivot.transform.basis.z.normalized()
	velocity.x = direccion_retroceso.x * 10.0
	velocity.z = direccion_retroceso.z * 10.0
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var objetivo = raycast.get_collider() # Obtenemos el nodo golpeado
		if objetivo.has_method("alertar"):
			objetivo.alertar(self)
		
	var tween = create_tween()
	var posicion_original_z = 7.0
	
	tween.tween_property(camara, "position:z", 0.3, 0.0)
	tween.tween_property(camara, "position:z", posicion_original_z, 0.2)
	tween.tween_callback(func(): esta_disparando = false)
		# Aquí podrías llamar a una función del enemigo para restarle vida. Ejemplo:
		# if objetivo.has_method("recibir_dano"):
		#     objetivo.recibir_dano(10)
