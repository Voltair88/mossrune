class_name SpatialGrid
extends RefCounted
## Buckets points into square cells, so a neighbour query looks at a few cells
## instead of every point. Rebuilt each physics frame with clear() and insert().
## The arrays are reused, so once they have grown a rebuild allocates nothing.

## Indices of the points found by the last query; only the first found_count count.
var found: PackedInt32Array = []
var found_count: int = 0
var _origin: Vector2
var _cell: float
var _cols: int
var _rows: int
## First point in each cell, -1 if empty.
var _head: PackedInt32Array = []
## Next point in the same cell, -1 at the end.
var _next: PackedInt32Array = []
var _pos: PackedVector2Array = []
var _count: int = 0


func _init(bounds: Rect2, cell_size: float) -> void:
	_origin = bounds.position
	_cell = cell_size
	_cols = maxi(ceili(bounds.size.x / cell_size), 1)
	_rows = maxi(ceili(bounds.size.y / cell_size), 1)
	_head.resize(_cols * _rows)
	_head.fill(-1)


func size() -> int:
	return _count


func clear() -> void:
	_head.fill(-1)
	_count = 0


## Adds a point and returns its index (0, 1, 2... in insertion order).
func insert(pos: Vector2) -> int:
	if _count == _pos.size():
		var grown := maxi(_count * 2, 1)
		_pos.resize(grown)
		_next.resize(grown)
		found.resize(grown)
	var cell := _cell_index(_col(pos.x), _row(pos.y))
	_pos[_count] = pos
	_next[_count] = _head[cell]
	_head[cell] = _count
	_count += 1
	return _count - 1


## Fills found with the points within radius of center and returns how many.
func query(center: Vector2, radius: float) -> int:
	found_count = 0
	var r2 := radius * radius
	for row in range(_row(center.y - radius), _row(center.y + radius) + 1):
		for col in range(_col(center.x - radius), _col(center.x + radius) + 1):
			var i := _head[_cell_index(col, row)]
			while i >= 0:
				if _pos[i].distance_squared_to(center) <= r2:
					found[found_count] = i
					found_count += 1
				i = _next[i]
	return found_count


func _col(x: float) -> int:
	return clampi(floori((x - _origin.x) / _cell), 0, _cols - 1)


func _row(y: float) -> int:
	return clampi(floori((y - _origin.y) / _cell), 0, _rows - 1)


func _cell_index(col: int, row: int) -> int:
	return row * _cols + col
