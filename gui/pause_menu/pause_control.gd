class_name PauseControl extends Control
## Class for swapping pause sub-menus and unpausing the game

@export var is_main_menu: bool = false
@export var starting_menu: Control

## Stores the order we visit menus in so we can properly handle navigating out.
var menu_stack: Array[Control] = []
var visible_menu: Control


func _ready() -> void:
    Globals.pause.connect(pause)
    Globals.unpause.connect(unpause)
    Globals.close_menu.connect(close_menu)

    # for child in get_children():
    # 	child.hide()
    # get_child(0).show()
    # visible_menu = get_child(1)
    visible_menu = starting_menu
    visible_menu.show()

    if is_main_menu:
        pause()
    else:
        unpause()


func _unhandled_input(event) -> void:
    if event is InputEventKey:
        if event.is_action_pressed("ui_cancel"):
            close_menu()
            get_tree().get_root().set_input_as_handled()


## Store currently open menu, hide it, and open `to_show`
func open_menu(to_show: Control) -> void:
    visible_menu.hide()
    menu_stack.push_front(visible_menu)

    visible_menu = to_show
    visible_menu.show()
    visible_menu.get_child(0).grab_focus()


## Close currently open menu, show previous menu
func close_menu() -> void:
    if len(menu_stack) == 0:
        if not is_main_menu:
            unpause()
        return

    visible_menu.hide()
    visible_menu = menu_stack.pop_front()

    visible_menu.show()
    visible_menu.get_child(0).grab_focus()


## Starts a pause state: shows base menu and frees mouse
func pause() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    show()
    visible_menu.get_child(0).grab_focus()


## Terminates the pause state: emits a global unpause and captures mouse
func unpause() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    hide()
    get_tree().paused = false
