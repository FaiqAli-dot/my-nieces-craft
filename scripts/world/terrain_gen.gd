extends RefCounted
class_name TerrainGen
## Seeded biome terrain around the hand-built meadow. Meadow columns (blocks
## 0..MEADOW_SIZE-1) are flat ground exactly as before; everything outside is
## shaped by noise and blended back to meadow height near its edge and the rim.

enum Biome { MEADOW, FOREST, SNOW, BEACH, FLOWERS }

const DEFAULT_SEED := 20261010
const SEA_Y := VoxelWorld.GROUND_Y - 1
const MEADOW_BLEND := 10.0
const RIM_BLEND := 6.0
const LAKE_CENTER := Vector2(32.0, 90.0)
const LAKE_RADIUS := 15.0

## Fixed, named places. `pad` is the flattened radius around `pos`.
const LANDMARKS := [
	{"id": "ruins", "name": "Mossy Ruins", "biome": Biome.FOREST, "pos": Vector2i(32, -28), "pad": 7},
	{"id": "tower", "name": "Lookout Tower", "biome": Biome.SNOW, "pos": Vector2i(90, 30), "pad": 4},
	{"id": "lighthouse", "name": "Little Lighthouse", "biome": Biome.BEACH, "pos": Vector2i(32, 90), "pad": 4},
	{"id": "windmill", "name": "Windmill", "biome": Biome.FLOWERS, "pos": Vector2i(-28, 32), "pad": 5},
]

## Biome sector centres (radians, atan2(dz, dx)): east, south, west, north.
const _SECTORS := [
	[Biome.SNOW, 0.0], [Biome.BEACH, PI * 0.5], [Biome.FLOWERS, PI], [Biome.FOREST, -PI * 0.5],
]

var world_seed: int
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _border := FastNoiseLite.new()
var _pad_heights := {}
var _ids := {}
var _min_block: Vector2i
var _max_block: Vector2i


func _init(p_seed: int = DEFAULT_SEED, min_block := Vector2i(-48, -48), max_block := Vector2i(112, 112)) -> void:
	world_seed = p_seed
	_min_block = min_block
	_max_block = max_block
	_hills.seed = p_seed
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.035
	_hills.fractal_octaves = 3
	_detail.seed = p_seed + 1
	_detail.frequency = 0.11
	_border.seed = p_seed + 2
	_border.frequency = 0.02
	for lm in LANDMARKS:
		var p: Vector2i = lm["pos"]
		_pad_heights[lm["id"]] = _natural_height(p.x, p.y)
	_pad_heights["lighthouse"] = VoxelWorld.GROUND_Y


static func biome_name(b: int) -> String:
	match b:
		Biome.FOREST: return "Whispering Woods"
		Biome.SNOW: return "Frosty Hills"
		Biome.BEACH: return "Sunny Shore"
		Biome.FLOWERS: return "Flower Fields"
	return "Meadow"


static func in_meadow(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < VoxelWorld.MEADOW_SIZE and z < VoxelWorld.MEADOW_SIZE


static func meadow_distance(x: int, z: int) -> float:
	var m := VoxelWorld.MEADOW_SIZE - 1
	var dx := maxi(maxi(-x, x - m), 0)
	var dz := maxi(maxi(-z, z - m), 0)
	return sqrt(float(dx * dx + dz * dz))


func _angle(x: int, z: int) -> float:
	var c := float(VoxelWorld.MEADOW_SIZE) * 0.5 - 0.5
	return atan2(float(z) - c, float(x) - c) + _border.get_noise_2d(x, z) * 0.35


## Partition-of-unity weights over the four sectors so heights blend smoothly.
func _weights(x: int, z: int) -> Array:
	var a := _angle(x, z)
	var out := []
	for s in _SECTORS:
		var d := absf(wrapf(a - float(s[1]), -PI, PI))
		out.append(maxf(0.0, 1.0 - d / (PI * 0.5)))
	return out


func biome_at(x: int, z: int) -> int:
	if in_meadow(x, z):
		return Biome.MEADOW
	return _dominant(_weights(x, z))


func _dominant(w: Array) -> int:
	var best := 0
	for i in w.size():
		if w[i] > w[best]:
			best = i
	return int(_SECTORS[best][0])


func _lake_depth(x: int, z: int) -> float:
	var d := Vector2(x, z).distance_to(LAKE_CENTER) + _detail.get_noise_2d(x, z) * 2.0
	if d >= LAKE_RADIUS:
		return 0.0
	return clampf((LAKE_RADIUS - d) * 0.45, 0.0, 3.4)


func _biome_height(b: int, x: int, z: int) -> float:
	var n := (_hills.get_noise_2d(x, z) + 1.0) * 0.5
	match b:
		Biome.FOREST: return 1.0 + n * 3.5
		Biome.SNOW: return 2.0 + n * 9.0
		Biome.BEACH: return n * 0.8 - _lake_depth(x, z) * 1.6
		Biome.FLOWERS: return n * 2.0
	return 0.0


func _natural_height(x: int, z: int, w: Array = []) -> int:
	if in_meadow(x, z):
		return VoxelWorld.GROUND_Y
	if w.is_empty():
		w = _weights(x, z)
	var off := 0.0
	for i in w.size():
		if w[i] > 0.0:
			off += w[i] * _biome_height(int(_SECTORS[i][0]), x, z)
	var t := smoothstep(0.0, 1.0, meadow_distance(x, z) / MEADOW_BLEND)
	var rim := mini(mini(x - _min_block.x, _max_block.x - 1 - x), mini(z - _min_block.y, _max_block.y - 1 - z))
	t *= smoothstep(0.0, 1.0, float(rim) / RIM_BLEND)
	return maxi(1, VoxelWorld.GROUND_Y + int(round(off * t)))


## Top solid block y of the generated column (water sits above it up to SEA_Y).
func height_at(x: int, z: int, w: Array = []) -> int:
	if in_meadow(x, z):
		return VoxelWorld.GROUND_Y
	var h := _natural_height(x, z, w)
	for lm in LANDMARKS:
		var p: Vector2i = lm["pos"]
		var d := Vector2(x, z).distance_to(Vector2(p))
		var pad := float(lm["pad"])
		if d <= pad:
			return int(_pad_heights[lm["id"]])
		if d < pad + 4.0:
			var t := (d - pad) / 4.0
			h = int(round(lerpf(float(_pad_heights[lm["id"]]), float(h), t)))
	return h


func landmark_base_y(id: String) -> int:
	return int(_pad_heights.get(id, VoxelWorld.GROUND_Y)) + 1


## Column block ids from y=0 up to the top (water included).
func column(x: int, z: int, out: PackedByteArray) -> int:
	if _ids.is_empty():
		for n in ["grass", "dirt", "stone", "sand", "snow", "flower_block", "water"]:
			_ids[n] = BlockDB.get_id(n)
	var b := Biome.MEADOW
	var h := VoxelWorld.GROUND_Y
	if not in_meadow(x, z):
		var w := _weights(x, z)
		b = _dominant(w)
		h = height_at(x, z, w)
	var top: int = _ids["grass"]
	var under: int = _ids["dirt"]
	match b:
		Biome.SNOW:
			if h >= VoxelWorld.GROUND_Y + 3:
				top = _ids["snow"]
		Biome.BEACH:
			if h <= VoxelWorld.GROUND_Y + 1 and Vector2(x, z).distance_to(LAKE_CENTER) < LAKE_RADIUS + 8.0:
				top = _ids["sand"]
				under = top
		Biome.FLOWERS:
			if _detail.get_noise_2d(x * 1.7, z * 1.7) > 0.42:
				top = _ids["flower_block"]
	if h < SEA_Y:
		top = _ids["sand"]
		under = top
	var top_y := maxi(h, SEA_Y)
	out.resize(top_y + 1)
	out.fill(_ids["stone"])
	for y in range(maxi(h - 2, 0), top_y + 1):
		if y < h:
			out[y] = under
		elif y == h:
			out[y] = top
		else:
			out[y] = _ids["water"]
	return top_y


## Writes every column straight into the chunk arrays (no per-block bookkeeping).
func fill(world: VoxelWorld) -> void:
	var s := VoxelChunk.SIZE
	var col := PackedByteArray()
	var cy_count := VoxelWorld.CHUNK_MAX.y - VoxelWorld.CHUNK_MIN.y
	for cz in range(VoxelWorld.CHUNK_MIN.z, VoxelWorld.CHUNK_MAX.z):
		for cx in range(VoxelWorld.CHUNK_MIN.x, VoxelWorld.CHUNK_MAX.x):
			var arrays: Array[PackedByteArray] = []
			for cy in cy_count:
				var a := PackedByteArray()
				a.resize(s * s * s)
				arrays.append(a)
			for lz in s:
				for lx in s:
					var top := column(cx * s + lx, cz * s + lz, col)
					for y in top + 1:
						var id := col[y]
						if id != 0:
							arrays[y / s][lx + s * (lz + s * (y % s))] = id
			for cy in cy_count:
				(world.chunks[Vector3i(cx, cy, cz)] as VoxelChunk).set_raw_blocks(arrays[cy])


## Trees, boulders and landmarks outside the meadow.
func decorate(world: VoxelWorld) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var step := 4
	for gz in range(_min_block.y + 4, _max_block.y - 4, step):
		for gx in range(_min_block.x + 4, _max_block.x - 4, step):
			var x := gx + rng.randi_range(0, step - 1)
			var z := gz + rng.randi_range(0, step - 1)
			var roll := rng.randf()
			var kind_roll := rng.randf()
			if meadow_distance(x, z) < 3.0 or _near_landmark(x, z, 5.0):
				continue
			var h := height_at(x, z)
			var ground := world.get_block(x, h, z)
			if h <= SEA_Y or (ground != BlockDB.grass_id and ground != BlockDB.get_id("snow")):
				continue
			var kind := -1
			match biome_at(x, z):
				Biome.FOREST:
					if roll < 0.6:
						kind = TreeGen.Kind.OAK if kind_roll < 0.45 else (TreeGen.Kind.PINE if kind_roll < 0.75 else TreeGen.Kind.BIRCH)
					elif roll < 0.66:
						_boulder(world, x, h + 1, z, rng)
				Biome.SNOW:
					if roll < 0.16:
						kind = TreeGen.Kind.PINE
					elif roll < 0.22:
						_boulder(world, x, h + 1, z, rng)
				Biome.FLOWERS:
					if roll < 0.08:
						kind = TreeGen.Kind.BIRCH if kind_roll < 0.6 else TreeGen.Kind.OAK
				Biome.BEACH:
					if roll < 0.05 and Vector2(x, z).distance_to(LAKE_CENTER) > LAKE_RADIUS + 6.0:
						kind = TreeGen.Kind.OAK
			if kind >= 0 and TreeGen.grow(world, kind, x, h + 1, z):
				world.set_block(x, h, z, BlockDB.get_id("dirt"), false)
	Landmarks.build_all(world, self)


func _near_landmark(x: int, z: int, margin: float) -> bool:
	for lm in LANDMARKS:
		if Vector2(x, z).distance_to(Vector2(lm["pos"])) < float(lm["pad"]) + margin:
			return true
	return false


func _boulder(world: VoxelWorld, x: int, y: int, z: int, rng: RandomNumberGenerator) -> void:
	var ids := [BlockDB.get_id("stone"), BlockDB.get_id("cobble"), BlockDB.get_id("mossy_cobble")]
	for c in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 0)]:
		var p: Vector3i = Vector3i(x, y, z) + c
		if world.get_block(p.x, p.y, p.z) == 0:
			world.set_block(p.x, p.y, p.z, ids[rng.randi_range(0, 2)], false)
