extends SceneTree
# One-shot: print the structure + animation names of the imported Mixamo FBX.

func _initialize() -> void:
	var scn = load("res://actors/fighter3d/Fight Idle.fbx")
	if scn == null:
		print("FAILED to load FBX (not imported?)")
		quit()
		return
	var inst = scn.instantiate()
	print("=== TREE ===")
	_print_tree(inst, 0)
	var ap = _find_anim_player(inst)
	if ap:
		print("=== ANIMS ===")
		for a in ap.get_animation_list():
			var anim = ap.get_animation(a)
			print("  '", a, "'  length=", anim.length)
	var mesh = _find_mesh(inst)
	if mesh:
		var aabb = mesh.get_aabb()
		print("=== MESH AABB size ===", aabb.size)
	quit()

func _print_tree(n, d):
	print("  ".repeat(d), n.name, " (", n.get_class(), ")")
	for c in n.get_children():
		_print_tree(c, d + 1)

func _find_anim_player(n):
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r = _find_anim_player(c)
		if r:
			return r
	return null

func _find_mesh(n):
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r = _find_mesh(c)
		if r:
			return r
	return null
