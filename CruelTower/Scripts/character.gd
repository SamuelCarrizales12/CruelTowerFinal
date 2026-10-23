extends CharacterBody3D

const SPEED = 2.5
const MOUSE_SENSITIVITY = 0.003

@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm = $CameraPivot/SpringArm3D
@onready var raycast = $CameraPivot/SpringArm3D/Camera3D/RayCast3D
@onready var camara = $CameraPivot/SpringArm3D/Camera3D

const FOV_NORMAL =75.0
const FOV_APUNTADO =40.0
var esta_disparando = false

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
		var input_dir := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
		var direction := (pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			#var look_dir = Vector2(velocity.z, velocity.x)
			#rotation.y = look_dir.angle()
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	
		if Input.is_action_just_pressed("disparar"):
			disparar()
		
		if Input.is_action_pressed("apuntar"):
			# lerp hace una transición suave entre el valor actual y el deseado
			camara.fov = lerp(camara.fov, FOV_APUNTADO, 10.0 * delta)
		else:
			camara.fov = lerp(camara.fov, FOV_NORMAL, 10.0 * delta)
	
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
	move_and_slide()

func disparar():
	esta_disparando = true
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var objetivo = raycast.get_collider() # Obtenemos el nodo golpeado
		var _punto_impacto = raycast.get_collision_point() # Obtenemos la coordenada exacta en 3D
		
		print("¡Disparo acertado! Le diste a: ", objetivo.name)
		
	var tween = create_tween()
	var posicion_original_z = 7.0
	
	tween.tween_property(camara, "position:z", 0.2, 0.0)
	tween.tween_property(camara, "position:z", posicion_original_z, 0.75)
	tween.tween_callback(func(): esta_disparando = false)
		# Aquí podrías llamar a una función del enemigo para restarle vida. Ejemplo:
		# if objetivo.has_method("recibir_dano"):
		#     objetivo.recibir_dano(10)
