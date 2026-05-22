extends Resource
class_name WeaponData

@export var display_name := "Weapon"
@export var damage := 10.0
@export var damage_type := "kinetic"
@export var magazine_size := 8
@export var reserve_ammo := 32
@export_range(0.0, 1.0, 0.01) var lock_retention_after_shot := 0.45
@export var reload_log := "reloaded"
