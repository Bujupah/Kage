class_name PauseMenu
extends UiScreen
## MENU-01. Pauses the local sandbox only; online the world keeps running and the panel says so
## (a menu is never a hiding place).


func _ready() -> void:
	var col := UiKit.centered_panel(self, 420)
	col.add_child(UiKit.label("Paused" if not shell.online else "Menu", "H1"))
	if shell.online:
		var warn := UiKit.label("Online: the world keeps running while this menu is open.", "Muted", true)
		warn.add_theme_color_override("font_color", UiTokens.VERMILION.lightened(0.3))
		col.add_child(warn)
	col.add_child(UiKit.button("Resume", func() -> void: shell.pop()))
	col.add_child(UiKit.button("Settings", func() -> void: shell.push(SettingsScreen.new())))
	col.add_child(UiKit.button("Controls", func() -> void: shell.push(SettingsScreen.new("Controls"))))
	col.add_child(UiKit.button("Leave to Main Menu", func() -> void: shell.show_main_menu(), "DangerButton"))
	col.add_child(UiKit.button("Quit to Desktop", func() -> void: shell.quit(), "DangerButton"))
