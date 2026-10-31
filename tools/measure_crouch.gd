extends SceneTree
## Print the crouch clip's hips-height profile so we can find the frame where
## the character is fully crouched / held down.

func _initialize() -> void:
	var path := "res://actors/fighter3d/Standing Idle To Crouch.fbx"
	if not ResourceLoader.exists(path):
		print("MISSING ", path)
		quit()
		return
	var inst := (load(path) as PackedScene).instantiate()
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var names := ap.get_animation_list()
	var an := "mixamo_com" if "mixamo_com" in names else names[0]
	var a := ap.get_animation(an)
	var length := a.length
	var hips := -1
	for ti in a.get_track_count():
		if a.track_get_type(ti) == Animation.TYPE_POSITION_3D and "Hips" in String(a.track_get_path(ti)):
			hips = ti
			break
	print("clip=", an, "  length=", snapped(length, 0.001), "s")
	if hips < 0:
		quit()
		return
	var base: float = (a.track_get_key_value(hips, 0) as Vector3).y
	print("baseline hips.y=", snapped(base, 0.001))
	var n := 30
	for i in range(n + 1):
		var t := length * float(i) / float(n)
		var y: float = (a.position_track_interpolate(hips, t) as Vector3).y
		var bar := ""
		for j in range(maxi(0, int((base - y) * 60.0))):
			bar += "#"
		print(str(snapped(t, 0.001)).pad_decimals(3), "s  drop=", str(snapped(base - y, 0.001)).pad_decimals(3), "  ", bar)
	quit()
