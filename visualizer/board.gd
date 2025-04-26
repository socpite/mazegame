extends ColorRect

var window_width = ProjectSettings.get_setting("display/window/size/viewport_width")
var window_height = ProjectSettings.get_setting("display/window/size/viewport_height")

var max_width = window_width*3/4
var max_height = window_height*3/4

var game_history
var original_board
var maze_width
var maze_height
var current_turn
var current_board
var observer_mode = false

var wall_id = {"BorderWall": 1, "VisibleWall": 0, "NoWall": 2, "NotVisible": 2}
var item_id = {"Chest": 0, "Bomb": 1}
const TILE_SIZE = 64

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	check_next_turn()
	check_prev_turn()

func resize() -> void:
	set_size(Vector2(maze_width*TILE_SIZE, maze_height*TILE_SIZE))
	scale = Vector2.ONE * min(max_width / size.x, max_height / size.y)
	
	position = Vector2(window_width/2, window_height/2) - size*scale/2

func load_file(file_path: String):
	game_history = JSON.parse_string(FileAccess.open(file_path, FileAccess.READ).get_as_text())
	original_board = JSON.parse_string(game_history.original_game_json)
	maze_width = original_board.board.width
	maze_height = original_board.board.height
	resize()
	set_turn(0)

func set_turn(num: int) -> void:
	current_turn = num
	print(num)
	current_board = JSON.parse_string(game_history.turn_info_list[current_turn].maze_sent_json)
	render_all()

func render_all():
	render_walls()
	render_background()
	render_player()
	render_items()

func render_walls():
	var hwalls = original_board.board.horizontal_walls if observer_mode else current_board.board.horizontal_walls
	for i in len(hwalls):
		for j in len(hwalls[i]):
			$HorizontalWalls.set_cell(Vector2i(j, i), 1, Vector2i(wall_id[hwalls[i][j]], 1))
	
	var vwalls = original_board.board.vertical_walls if observer_mode else current_board.board.vertical_walls
	for i in len(vwalls):
		for j in len(vwalls[i]):
			$VerticalWalls.set_cell(Vector2i(j, i), 1, Vector2i(wall_id[vwalls[i][j]], 0))
			
func render_background():
	var vision = current_board.board.luminated_tiles
	for i in len(vision):
		for j in len(vision[i]):
			$Background.set_cell(Vector2(j, i), 4, Vector2i(0, 0), !vision[i][j])

func render_player():
	$Player.clear()
	var player_position = current_board.position
	$Player.set_cell(Vector2i(player_position[1], player_position[0]), 3, Vector2i(0, 0), 0)

func check_next_turn():
	if Input.is_action_just_pressed("next turn"):
		if current_turn + 1 >= len(game_history.turn_info_list):
			return
		set_turn(current_turn + 1)

func render_items():
	$Items.clear()
	var end_position = current_board.end_position
	var items = original_board.board.item_board if observer_mode else current_board.board.item_board
	for i in len(items):
		for j in len(items[i]):
			if !items[i][j]:
				continue
			$Items.set_cell(Vector2i(j, i), 5, Vector2i(0, item_id[items[i][j]]))
	$Items.set_cell(Vector2i(end_position[1], end_position[0]), 5, Vector2i(0, item_id.Chest))
	

func check_prev_turn():
	if Input.is_action_just_pressed("last turn"):
		if current_turn == 0:
			return
		set_turn(current_turn - 1)


func _on_check_button_toggled(toggled_on: bool) -> void:
	observer_mode = toggled_on
	render_all() # Replace with function body.
