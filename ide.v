module main

import gg
import iui as ui
import os
import iui.hc

const (
	version = '0.0.8-dev'
)

[console]
fn main() {
	// Hide Console
	hc.hide_console_win()

	// Create Window
	mut window := ui.window(ui.get_system_theme(), 'Vide', 800, 520)

	// our custom config
	mut conf := config(mut window)
	get_v_exe(mut window)

	// Set Saved Theme
	set_theme_from_save(mut window)

	// Setup Menubar and items
	window.bar = ui.menubar(window, window.theme)

	file_img := $embed_file('assets/icons8-file-48.png')
	edit_img := $embed_file('assets/icons8-edit-24.png')
	help_img := $embed_file('assets/icons8-help-24.png')
	save_img := $embed_file('assets/icons8-save-48.png')
	theme_img := $embed_file('assets/icons8-themes-48.png')

	file_icon := ui.image_from_bytes(mut window, file_img.to_bytes(), 24, 24)
	edit_icon := ui.image_from_bytes(mut window, edit_img.to_bytes(), 24, 24)
	help_icon := ui.image_from_bytes(mut window, help_img.to_bytes(), 24, 24)
	save_icon := ui.image_from_bytes(mut window, save_img.to_bytes(), 24, 24)
	theme_icon := ui.image_from_bytes(mut window, theme_img.to_bytes(), 24, 24)

	file_menu := ui.menu_item(
		text: 'File'
		icon: file_icon
		children: [
			ui.menu_item(
				text: 'New Project..'
				click_event_fn: new_project_click
			),
			ui.menu_item(
				text: 'New File...'
				click_event_fn: new_file_click
			),
			ui.menu_item(
				text: 'Save'
				click_event_fn: save_click
			),
			ui.menu_item(
				text: 'Run'
				click_event_fn: run_click
			),
			ui.menu_item(
				text: 'Vpm UI'
				click_event_fn: vpm_click
			),
			ui.menu_item(
				text: 'Settings'
				click_event_fn: settings_click
			),
		]
	)

	edit_menu := ui.menu_item(
		text: 'Edit'
		icon: edit_icon
	)

	help_menu := ui.menu_item(
		text: 'Help'
		icon: help_icon
		children: [
			ui.menu_item(
				text: 'About Vide'
				click_event_fn: about_click
			),
			ui.menu_item(
				text: 'About iUI'
			),
		]
	)

	mut theme_menu := ui.menuitem('Themes')
	theme_menu.icon = theme_icon

	themes := ui.get_all_themes()
	for theme2 in themes {
		item := ui.menu_item(text: theme2.name, click_event_fn: on_theme_click)
		theme_menu.add_child(item)
	}

	save_menu := ui.menu_item(
		text: 'Save'
		icon: save_icon
		click_event_fn: save_click
	)

	window.bar.add_child(file_menu)
	window.bar.add_child(edit_menu)
	window.bar.add_child(help_menu)
	window.bar.add_child(theme_menu)

	window.bar.add_child(save_menu)

	workd := conf.get_or_default('workspace_dir').replace('{user_home}', '~').replace('\\',
		'/') // '
	folder := os.expand_tilde_to_home(workd).replace('~', os.home_dir())

	window.extra_map['workspace'] = folder
	os.mkdir_all(folder) or {}

	mut tree := ui.tree(window, 'Projects')
	tree.is_selected = true
	tree.set_bounds(0, 22, 170, 200)
	tree.draw_event_fn = fn (mut win ui.Window, mut tree ui.Component) {
		tree.height = gg.window_size().height
	}

	tree.set_id(mut window, 'proj-tree')
	make_tree(mut window, folder, mut tree)

	window.add_child(tree)

	mut tb := ui.tabbox(window)
	tb.set_id(mut window, 'main-tabs')
	tb.set_bounds(200, 35, 200, 80)

	tb.draw_event_fn = on_draw
	window.add_child(tb)

	welcome_tab(mut window, mut tb, folder)

	mut console_box := create_box(window)
	console_box.z_index = 2
	console_box.set_id(mut window, 'consolebox')
	window.add_child(console_box)

	// basic plugin system
	plugin_dir := os.real_path(os.home_dir() + '/vide/plugins/')
	os.mkdir_all(plugin_dir) or {}
	load_plugins(plugin_dir, mut window) or {}

	window.gg.run()
}

fn welcome_tab(mut window ui.Window, mut tb ui.Tabbox, folder string) {
	mut info_lbl := ui.label(window,
		'Welcome to Vide! A simple IDE for V made in V.\n
Note: Currently alpha software!\n\nVersion: ' +
		version + ', UI version: ' + ui.version)

	info_lbl.set_pos(10, 90)
	info_lbl.pack()

	mut logo := window.gg.create_image_from_byte_array(vide_png.to_bytes())
	mut logo_im := ui.image(window, logo)
	logo_im.set_bounds(1, 8, 188, 75)

	mut gh := ui.button(window, 'Github')
	gh.set_pos(190, 53)
	gh.set_click(fn (mut win ui.Window, com ui.Button) {
		ui.open_url('https://github.com/isaiahpatton/vide')
	})
	gh.pack()

	mut ad := ui.button(window, 'Addons')
	ad.set_pos(255, 53)
	ad.set_click(fn (mut win ui.Window, com ui.Button) {
		ui.open_url('https://github.com/topics/vide-addon')
	})
	ad.pack()

	tb.add_child('Welcome', info_lbl)
	tb.add_child('Welcome', logo_im)
	tb.add_child('Welcome', gh)
	tb.add_child('Welcome', ad)
}

fn new_tab(mut window ui.Window, file string, mut tb ui.Tabbox) {
	mut lines := os.read_lines(file) or { ['ERROR while reading file contents'] }

	mut code_box := ui.textedit_from_array(window, lines)

	code_box.text_change_event_fn = codebox_text_change
	code_box.after_draw_event_fn = on_runebox_draw
	code_box.line_draw_event_fn = draw_code_suggest
	code_box.set_bounds(2, 2, 620, 250)

	tb.add_child(file, code_box)
	tb.active_tab = file
}

fn set_console_text(mut win ui.Window, out string) {
	for mut comm in win.components {
		if mut comm is ui.TextEdit {
			for line in comm.text.split_into_lines() {
				comm.lines << line
			}
			add_new_input_line(mut comm)
			return
		}
	}
}

fn run_v(dir string, mut win ui.Window) {
	mut vexe := 'v'
	if 'VEXE' in os.environ() {
		vexe = os.environ()['VEXE']
	} else {
		vexe = get_v_exe(mut win)
	}

	out := os.execute(vexe + ' run ' + dir)
	set_console_text(mut win, out.output)
}
