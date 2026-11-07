extends Control
## A 3.5" floppy disk drawn in code (placeholder art: shapes and a label), for
## Look Busy's pieces: the new-disk pop-up (disk_popup.gd), the Dev Kit's
## drive rows and its binder (dev_kit.gd). The plastic is the piece's kind
## colour; the paper label has its kind on a dark band and its name in ink.
## A missing disk (not found yet) is a dashed outline with "???".

const FONT := preload("res://addons/hh_minigames/_shared/fonts/press_start_2p.ttf")
const KIND_COLORS := {
	"genre": Color(0.95, 0.45, 0.3), "mechanic": Color(0.35, 0.75, 1.0), "art": Color(0.75, 0.5, 1.0),
	"sound": Color(0.4, 0.9, 0.55), "character": Color(1.0, 0.8, 0.35),
}
const METAL := Color(0.79, 0.81, 0.83)
const METAL_LIT := Color(0.89, 0.91, 0.92)
const SLOT := Color(0.23, 0.25, 0.27)
const PAPER := Color(0.965, 0.945, 0.894)
const BAND := Color(0.17, 0.17, 0.2)
const INK := Color(0.12, 0.16, 0.35)

var kind := ""
var title := ""
var missing := false
## Draw the name on the label (off for tiny disks that show it underneath).
var show_name := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_piece(k: String, name: String, is_missing := false) -> void:
	kind = k
	title = name
	missing = is_missing
	queue_redraw()


static func kind_color(k: String) -> Color:
	return KIND_COLORS.get(k, Color(0.7, 0.7, 0.7))


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	if missing:
		_draw_missing(o, s)
		return
	var col := kind_color(kind)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	# Shadow, then the plastic body (notched top-right corner).
	var body := PackedVector2Array([p.call(0.04, 0.0), p.call(0.92, 0.0), p.call(1.0, 0.08), p.call(1.0, 0.96),
		p.call(0.96, 1.0), p.call(0.04, 1.0), p.call(0.0, 0.96), p.call(0.0, 0.04)])
	var shadow := PackedVector2Array()
	for v in body:
		shadow.append(v + Vector2(0.03, 0.04) * s)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	draw_colored_polygon(body, col)
	# PS1-ish facets: a lit wedge top-left, a shaded wedge bottom-right.
	draw_colored_polygon(PackedVector2Array([p.call(0.0, 0.04), p.call(0.04, 0.0), p.call(0.6, 0.0), p.call(0.0, 0.6)]), Color(1, 1, 1, 0.16))
	draw_colored_polygon(PackedVector2Array([p.call(1.0, 0.6), p.call(1.0, 0.96), p.call(0.96, 1.0), p.call(0.6, 1.0)]), Color(0.2, 0.05, 0.0, 0.16))
	# The metal shutter and its window.
	draw_rect(Rect2(p.call(0.24, 0.0), Vector2(0.52, 0.34) * s), METAL)
	draw_rect(Rect2(p.call(0.24, 0.0), Vector2(0.52, 0.05) * s), METAL_LIT)
	draw_rect(Rect2(p.call(0.53, 0.05), Vector2(0.13, 0.24) * s), SLOT)
	draw_rect(Rect2(p.call(0.31, 0.05), Vector2(0.1, 0.24) * s), METAL.darkened(0.12))
	# The paper label.
	draw_rect(Rect2(p.call(0.1, 0.44), Vector2(0.8, 0.52) * s), PAPER)
	draw_rect(Rect2(p.call(0.1, 0.44), Vector2(0.8, 0.09) * s), BAND)
	# Write-protect tab and the hole opposite.
	draw_rect(Rect2(p.call(0.04, 0.89), Vector2(0.06, 0.06) * s), BAND)
	draw_rect(Rect2(p.call(0.905, 0.89), Vector2(0.06, 0.06) * s), BAND)
	if s < 40.0:
		return
	# The band: the kind, in its own colour.
	var band_fs := int(clampf(s * 0.045, 6.0, 22.0))
	var kind_name: String = GameMaker.KIND_NAMES.get(kind, kind.to_upper())
	draw_string(FONT, p.call(0.13, 0.44) + Vector2(0, 0.065 * s + band_fs * 0.4), kind_name, HORIZONTAL_ALIGNMENT_LEFT, 0.74 * s, band_fs, col)
	# Ruled lines, then the name in ink.
	for y in [0.67, 0.79, 0.91]:
		draw_line(p.call(0.14, y), p.call(0.86, y), Color(0.85, 0.82, 0.73), maxf(1.0, s * 0.006))
	if not show_name or title == "":
		return
	var room := 0.74 * s
	var fs := int(clampf(s * 0.085, 6.0, 44.0))
	while fs > 6 and FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	draw_string(FONT, p.call(0.13, 0.65) + Vector2(0, fs * 0.5), title, HORIZONTAL_ALIGNMENT_CENTER, room, fs, INK)


func _draw_missing(o: Vector2, s: float) -> void:
	var r := Rect2(o + Vector2(0.06, 0.06) * s, Vector2(0.88, 0.88) * s)
	draw_rect(r, Color(1, 1, 1, 0.04))
	var w := maxf(2.0, s * 0.025)
	var dash := maxf(4.0, s * 0.07)
	var c := Color(0.55, 0.53, 0.6)
	draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), c, w, dash)
	draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, c, w, dash)
	draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), c, w, dash)
	draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, c, w, dash)
	var fs := int(clampf(s * 0.16, 8.0, 48.0))
	draw_string(FONT, Vector2(r.position.x, r.get_center().y + fs * 0.5), "???", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, c)
