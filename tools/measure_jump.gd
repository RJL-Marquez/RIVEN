extends SceneTree
## Print the Mixamo jump clip's hips-height profile over time so we can find
## when it actually launches (hips start rising), peaks, and lands — to sync the
## physics jump to the animation.

func _initialize() -> void:
	var path := "res://actors/fighter3d/Jumping.fbx"
	if not ResourceLoader.exists(path):
		print("MISSING ", path)
		quit()
		return
	var inst := (load(path) as PackedScene).instantiate()
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		print("no AnimationPlayer")
		quit()
		return
	var names := ap.get_animation_list()
	var an := "mixamo_com" if "mixamo_com" in names else names[0]
	var a := ap.get_animation(an)
	var length := a.length
	# Find the hips position track.
	var hips := -1
	for ti in a.get_track_count():
		if a.track_get_type(ti) == Animation.TYPE_POSITION_3D and "Hips" in String(a.track_get_path(ti)):
			hips = ti
			break
	print("clip=", an, "  length=", snapped(length, 0.001), "s  hips_track=", hips)
	if hips < 0:
		quit()
		return
	var n := 40
	var base: float = (a.track_get_key_value(hips, 0) as Vector3).y
	print("baseline hips.y=", snapped(base, 0.001))
	for i in range(n + 1):
		var t := length * float(i) / float(n)
		var y: float = (a.position_track_interpolate(hips, t) as Vector3).y
		var bar := ""
		var d := int((y - base) * 60.0)
		for j in range(maxi(0, d)):
			bar += "#"
		print(str(snapped(t, 0.001)).pad_decimals(3), "s  y=", str(snapped(y - base, 0.001)).pad_decimals(3), "  ", bar)
	quit()
