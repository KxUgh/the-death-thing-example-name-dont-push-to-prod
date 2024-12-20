extends Enemy

enum State{
	IDLE,
	MOVING,
	CHANNELING,
	ATTACKING,
	SMITING,
	CHANNELING_SMITE,
	DEAD,
}

@export var potions: Array[PackedScene]
@export var nav_agent: NavigationAgent2D
@export var nav_timer: Timer
@export var sword: Weapon
@export var smiter: Weapon
@export var sprite: AnimatedSprite2D
@export var attack_cooldown: float
@export var smite_cooldown: float
@export var channeling_duration: float
@export var attack_duration: float
@export var hit_cooldown: float

@onready var since_last_attack = attack_cooldown
@onready var since_last_smite = 0
@onready var since_last_hit = hit_cooldown
@onready var state = State.IDLE

var target: Node2D
var attack_position: Vector2

func _ready() -> void:
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_timer.timeout.connect(update_nav_agent)

func _physics_process(delta: float) -> void:
	since_last_attack += delta
	since_last_hit += delta
	since_last_smite += delta
	
	if get_distance_to_target() > 200:
		return
	
	var next_path_position: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = position.direction_to(next_path_position)
	
	nav_agent.set_velocity(direction * speed)
	
	var previous_state: State = state
	state = determine_state()
	process_state(previous_state)

	
func determine_state() -> State:
	if state == State.DEAD:
		return State.DEAD
		
	if state in [State.CHANNELING_SMITE, State.SMITING] and channeling_duration < since_last_smite and since_last_smite < attack_duration + channeling_duration:
		return State.SMITING
	
	if state in [State.CHANNELING, State.ATTACKING] and channeling_duration < since_last_attack and since_last_attack < attack_duration + channeling_duration:
		return State.ATTACKING
	

	if target is Player and ((get_distance_to_target() < 100 and can_smite()) or (since_last_smite < channeling_duration and state == State.CHANNELING_SMITE)):
		return State.CHANNELING_SMITE

	if (get_distance_to_target() < 100 and can_attack()) or (since_last_attack < channeling_duration and state == State.CHANNELING):
		return State.CHANNELING

	if velocity.length() > 0.0001:
		return State.MOVING
	
	return State.IDLE

func process_state(previous_state: State) -> void:
	match state:
		State.IDLE:
			move_and_slide()
			sprite.play("Idle")
			
		State.CHANNELING:
			if previous_state != state:
				since_last_attack = 0
				attack_position = target.position
				Common.play_sprite_animation_duration(sprite, "Channel_Attack", channeling_duration)
		State.ATTACKING:
			if previous_state != state:
				Common.play_sprite_animation_duration(sprite, "Attack", attack_duration)
				sword.attack(position,attack_position)
		State.CHANNELING_SMITE:
			if previous_state != state:
				since_last_smite = 0
				Common.play_sprite_animation_duration(sprite, "Channel_Smite", channeling_duration)
		State.SMITING:
			if previous_state != state:
				Common.play_sprite_animation_duration(sprite, "Smite", attack_duration)
				smiter.attack(position,target.position)
		
		State.MOVING:
			move_and_slide()
			if velocity.x > 0:
				sprite.play("Right")
			else:
				sprite.play("Left")
		State.DEAD:
			if sprite.animation != "Death":
				sprite.play("Death")
			if not sprite.is_playing():
				queue_free()



func get_navigation_direction() -> Vector2:
	if not target:
		return Vector2.ZERO
	nav_agent.target_position = target.position
	if nav_agent.is_navigation_finished():
		return Vector2.ZERO
	var next_position: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = position.direction_to(next_position)
	return direction

func get_distance_to_target() -> float:
	if target:
		return (target.position - position).length()
	return INF
	
func take_damage(damage: float, _type: Entity_type, _buff: PlayerData.BuffType = PlayerData.BuffType.NONE) -> void:
	if state in [State.DEAD] or since_last_hit < hit_cooldown:
		return
	since_last_hit = 0
	var previous_health: float = health
	health -= damage
	if previous_health > 1:
		health = clampf(health,1,max_health)
	else:
		health = clampf(health,0,max_health)
	if health == 0:
		die()

func die() -> void:
	if RandomNumberGenerator.new().randf() < get_potion_probability():
		var potion: Potion = potions.pick_random().instantiate()
		potion.position = position
		get_node("/root/Node2D").add_child(potion)
	state = State.DEAD
	
func can_attack() -> bool:
	return since_last_attack > attack_cooldown
	
func can_smite() -> bool:
	return since_last_smite > smite_cooldown
	
func find_target() -> void:
	var players = get_tree().get_nodes_in_group("Players")
	if len(players) > 0:
		target = players[0]
		
func update_nav_agent() -> void:
	find_target()
	nav_agent.target_position = target.position

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
