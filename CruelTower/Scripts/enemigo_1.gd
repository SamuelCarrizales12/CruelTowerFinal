extends CharacterBody3D

@onready var sprite = $Sprite3D

# --- VARIABLES DE MANADA ---
# Aparecerá en el Inspector. Puedes ponerle "manada_1", "manada_2", etc., a cada copia en tu mapa.
@export var nombre_manada: String = "manada_1"

# --- VARIABLES DE LEVITACIÓN ---
var tiempo := 0.0
const AMPLITUD := 0.5
const VELOCIDAD_FLOTE := 3.0
@onready var pos_y_inicial = sprite.position.y

# --- VARIABLES DE PERSECUCIÓN ---
var persiguiendo := false
var objetivo: Node3D = null
const SPEED = 1.0

func _ready():
	# El enemigo se une automáticamente a su mini-manada al aparecer en el mundo
	add_to_group(nombre_manada)

func alertar(quien_disparo: Node3D):
	if persiguiendo:
		return
		
	persiguiendo = true
	objetivo = quien_disparo
	
	# Solo alertará a los miembros que tengan exactamente el mismo 'nombre_manada'
	get_tree().call_group(nombre_manada, "alertar", quien_disparo)

func _physics_process(delta: float) -> void:
	# Gravedad estándar
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Lógica de persecución con NavigationAgent3D
	if persiguiendo and objetivo != null:
		# Obtenemos la dirección hacia el jugador
		var direccion = global_position.direction_to(objetivo.global_position)
		
		# Anulamos el eje Y para que el enemigo no intente volar hacia tu cabeza o hundirse
		direccion.y = 0 
		direccion = direccion.normalized()
		
		velocity.x = direccion.x * SPEED
		velocity.z = direccion.z * SPEED
	else:
		# Si no persigue, se queda quieto
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()

# --- LEVITACIÓN VISUAL ---
# Es vital que esto esté en _process y afecte solo a sprite.position.y
func _process(delta: float) -> void:
	tiempo += delta
	sprite.position.y = pos_y_inicial + sin(tiempo * VELOCIDAD_FLOTE) * AMPLITUD
