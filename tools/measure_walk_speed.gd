extends SceneTree
## Measure the baked ground speed (m/s) of the Mixamo walk clips so the
## CharacterBody3D travel speed can match the stride (no foot sliding).

func _measure(path: String) -> void:
	if not ResourceLoader.exists(path):
		print(path, " : MISSING")
		return
	var scene := load(path) as PackedScene
	var inst := scene.instantiate()
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		print(path, " : no AnimationPlayer")
		return
	var names := ap.get_animation_list()
	var an := "mixamo_com" if "mixamo_com" in names else (names[0] if names.size() > 0 else "")
	if an == "":
		print(path, " : no anim")
		return
	var a := ap.get_animation(an)
	var length := a.length
	# Find the hips position track.
	var hips_track := -1
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var p := String(a.track_get_path(t))
			if "Hips" in p:
				hips_track = t
				break
	if hips_track < 0:
		print(path, " : no hips position track")
		return
	var kc := a.track_get_key_count(hips_track)
	var p0: Vector3 = a.track_get_key_value(hips_track, 0)
	var p1: Vector3 = a.track_get_key_value(hips_track, kc - 1)
	# Horizontal travel over the clip (ignore vertical bob).
	var d := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	var mps := d / length if length > 0.0 else 0.0
	print(path.get_file(), " | len=", snapped(length, 0.001), "s  travel=", snapped(d, 0.001), "m  speed=", snapped(mps, 0.001), " m/s")

func _initialize() -> void:
	for p in [
		"res://actors/fighter3d/Walking.fbx",
		"res://actors/fighter3d/Walking Backwards.fbx",
	]:
		_measure(p)
	quit()
