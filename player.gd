
extends CharacterBody2D

@export var speed: float = 100.0

@onready var player_sprite: Sprite2D = $Sprite2D

var move_direction := Vector2.ZERO


func _physics_process(_delta: float) -> void:
	if move_direction.x < 0.0:
		player_sprite.flip_h = true
	elif move_direction.x > 0.0:
		player_sprite.flip_h = false

	velocity = move_direction * speed
	move_and_slide()


func set_move_direction(direction: Vector2) -> void:
	move_direction = direction
