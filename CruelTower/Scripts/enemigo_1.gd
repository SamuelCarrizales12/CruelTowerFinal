extends CharacterBody3D

@onready var sprite = $Sprite3D

# --- VARIABLES DE MANADA ---
@export var nombre_manada: String = "manada_1"

# --- VARIABLES DE LEVITACIÓN ---
var tiempo := 0.0
const AMPLITUD := 0.5
const VELOCIDAD_FLOTE := 3.0
@onready var pos_y_inicial = sprite.position.y

# --- VARIABLES DE PERSECUCIÓN ---
var persiguiendo := false
var objetivo: Node3D = null
const SPEED = 1.5

var vida := 100
var aturdido := false

var muerto := false
@export var tex_explosion1: Texture2D
@export var tex_explosion2: Texture2D
@export var tex_explosion3: Texture2D
@export var tex_explosion4: Texture2D
@export var tex_explosion5: Texture2D

@export var textura_dano: Texture2D # La imagen roja o de daño
@export var textura_dano2: Texture2D
@onready var textura_normal = sprite.texture

var cooldown_ataque := 0.0

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
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not aturdido:
		if persiguiendo and is_instance_valid(objetivo):
			var direccion = global_position.direction_to(objetivo.global_position)
			direccion.y = 0 
			direccion = direccion.normalized()
			
			velocity.x = direccion.x * SPEED
			velocity.z = direccion.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			
	else:
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)

	move_and_slide()
	
	# --- DAÑO POR CONTACTO AL JUGADOR ---
	if not aturdido and not muerto and cooldown_ataque <= 0.0:
		
		# Revisamos todos los objetos con los que el enemigo está chocando físicamente
		for i in get_slide_collision_count():
			var colision = get_slide_collision(i)
			var objeto_chocado = colision.get_collider()
			
			if is_instance_valid(objeto_chocado):
				# Usamos has_method("curar") como truco para asegurarnos de que es el jugador
				# y no otro enemigo u otra caja de madera
				if objeto_chocado.has_method("curar"):
					var direccion_golpe = global_position.direction_to(objeto_chocado.global_position)
					direccion_golpe.y = 0
					direccion_golpe = direccion_golpe.normalized()
					
					objeto_chocado.recibir_dano(3, direccion_golpe, self)
					cooldown_ataque = 1.0 

# --- LEVITACIÓN VISUAL ---
# Es vital que esto esté en _process y afecte solo a sprite.position.y
func _process(delta: float) -> void:
	tiempo += delta
	sprite.position.y = pos_y_inicial + sin(tiempo * VELOCIDAD_FLOTE) * AMPLITUD

func recibir_dano(cantidad: int, direccion_impacto: Vector3, atacante: Node3D):
	# Si ya está muerto, ignoramos más disparos
	if muerto:
		return
		
	vida -= cantidad
	alertar(atacante)
	
	if vida <= 0:
		morir() # Llamamos a la animación en lugar de borrarlo de golpe
		return
		
	if vida <= 35:
		textura_normal = textura_dano2
	elif vida <= 70:
		textura_normal = textura_dano
		
	sprite.texture = textura_normal
		
	aturdido = true
	
	direccion_impacto.y = 0.5
	velocity = direccion_impacto * 12.0
	
	await get_tree().create_timer(0.3).timeout

	aturdido = false

func morir():
	muerto = true
	aturdido = true # Congelamos su movimiento para que no siga resbalando
	
	# Apagamos la colisión de forma segura
	$CollisionShape3D.set_deferred("disabled", true)
	
	# --- ANIMACIÓN DE EXPLOSIÓN ---
	sprite.texture = tex_explosion1
	await get_tree().create_timer(0.05).timeout
	sprite.texture = tex_explosion2
	await get_tree().create_timer(0.05).timeout
	sprite.texture = tex_explosion3
	await get_tree().create_timer(0.05).timeout
	sprite.texture = tex_explosion4
	await get_tree().create_timer(0.05).timeout
	sprite.texture = tex_explosion5
	await get_tree().create_timer(0.05).timeout
	
	# Una vez terminada la animación, eliminamos el nodo
	queue_free()
