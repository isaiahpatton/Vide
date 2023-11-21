// Copyright (c) 2019-2023 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license that can be found in the LICENSE file.
module main

import os

// Note: this program follows a similar convention to Rust: `init` makes the
// structure of the program in the _current_ directory, while `new`
// makes the program structure in a _sub_ directory. Besides that, the
// functionality is essentially the same.

// Note: here are the currently supported invokations so far:
// 1) `v init` -> create a new project in the current folder
// 2) `v new abc` -> create a new project in the new folder `abc`, by default a "hello world" project.
// 3) `v new abcd web` -> create a new project in the new folder `abcd`, using the vweb template.
// 4) `v new abcde hello_world` -> create a new project in the new folder `abcde`, using the hello_world template.

// Note: run `v cmd/tools/vcreate_test.v` after changes to this program, to avoid regressions.
struct Create {
mut:
	name        string
	description string
	version     string
	license     string
	files       []ProjectFiles
	app         &App
}

struct ProjectFiles {
	path    string
	content string
}

@[params]
struct CreateConfig {
	name        string
	description string
	version     string
	license     string
	template    string
	app         &App
}

// fn new_project(args []string) {
fn new_project(cfg CreateConfig) {
	mut c := Create{
		app: cfg.app
	}

	// project name
	c.name = check_name(cfg.name)

	if c.name == '' {
		cerror('project name cannot be empty')
		exit(1)
	}

	if c.name.contains('-') {
		cerror('"${c.name}" should not contain hyphens')
		exit(1)
	}

	if os.is_dir(c.name) {
		cerror('${c.name} folder already exists')
		exit(3)
	}

	c.description = cfg.description

	default_version := '0.0.0'

	c.version = cfg.version
	if c.version == '' {
		c.version = default_version
	}

	default_license := os.getenv_opt('VLICENSE') or { 'MIT' }

	c.license = cfg.license
	if c.license == '' {
		c.license = default_license
	}

	println('Initialising ...')

	// `v new abcde hello_world`
	templ := cfg.template

	// if args.len == 2 {
	if templ.len > 0 {
		// match os.args.last() {
		match templ {
			'web' {
				c.set_web_project_files()
			}
			'hello_world' {
				c.set_hello_world_project_files()
			}
			'basic_window' {
				c.set_basic_window_files()
			}
			'border_layout' {
				c.set_border_layout_files()
			}
			else {
				eprintln('${templ} model not exist')
				exit(1)
			}
		}
	} else {
		// `v new abc`
		c.set_hello_world_project_files()
	}

	// gen project based in the `Create.files` info
	c.create_files_and_directories()

	c.write_vmod(true)
	c.write_gitattributes(true)
	c.write_editorconfig(true)

	mut gdir := os.join_path(c.app.confg.workspace_dir, c.name)

	c.create_git_repo(gdir)
}

@[deprecated: 'Not used in Vide']
fn init_project() {
}

fn cerror(e string) {
	eprintln('\nerror: ${e}')
}

fn check_name(name string) string {
	if name.trim_space().len == 0 {
		cerror('project name cannot be empty')
		exit(1)
	}
	if name.is_title() {
		mut cname := name.to_lower()
		if cname.contains(' ') {
			cname = cname.replace(' ', '_')
		}
		eprintln('warning: the project name cannot be capitalized, the name will be changed to `${cname}`')
		return cname
	}
	if name.contains(' ') {
		cname := name.replace(' ', '_')
		eprintln('warning: the project name cannot contain spaces, the name will be changed to `${cname}`')
		return cname
	}
	return name
}

fn vmod_content(c Create) string {
	return "Module {
	name: '${c.name}'
	description: '${c.description}'
	version: '${c.version}'
	license: '${c.license}'
	dependencies: []
}
"
}

fn hello_world_content() string {
	return "module main

fn main() {
	println('Hello World!')
}
"
}

fn basic_window_content() string {
	return "module main

import iui as ui // // v install https://github.com/pisaiah/ui

fn main() {
	// Create Window
	mut window := ui.Window.new(
		title: 'My Window'
		width: 520
		height: 400
		theme: ui.theme_default()
	)
	
	// A content pane
	mut p := ui.Panel.new()
	
	window.add_child(p)

	// Run window
	window.run()
}
"
}

fn border_layout_content() string {
	return "module main

import iui as ui // v install https://github.com/pisaiah/ui

struct App {
mut:
	p &ui.Panel
}

fn main() {
	mut win := ui.Window.new(
		title: 'BorderLayoutDemo'
		width: 450
		height: 295
	)

	mut pan := ui.Panel.new(layout: ui.BorderLayout.new())

	mut app := &App{
		p: pan
	}

	app.make_button('1 (NORTH)', ui.borderlayout_north)
	app.make_button('2 (WEST)', ui.borderlayout_west)
	app.make_button('3 (EAST)', ui.borderlayout_east)
	app.make_button('4 (SOUTH)', ui.borderlayout_south)
	app.make_button('5 (CENTER)', ui.borderlayout_center)

	win.add_child(pan)
	win.gg.run()
}

fn (mut app App) make_button(id string, constrain int) &ui.Button {
	mut btn := ui.Button.new(
		text: 'Button ' + id
	)
	app.p.add_child_with_flag(btn, constrain)
	return btn
}
"
}

fn gen_gitignore(name string) string {
	return '# Binaries for programs and plugins
main
${name}
*.exe
*.exe~
*.so
*.dylib
*.dll

# Ignore binary output folders
bin/

# Ignore common editor/system specific metadata
.DS_Store
.idea/
.vscode/
*.iml

# ENV
.env

# vweb and database
*.db
*.js
'
}

fn gitattributes_content() string {
	return '* text=auto eol=lf
*.bat eol=crlf

**/*.v linguist-language=V
**/*.vv linguist-language=V
**/*.vsh linguist-language=V
**/v.mod linguist-language=V
'
}

fn editorconfig_content() string {
	return '[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.v]
indent_style = tab
indent_size = 4
'
}

fn (c &Create) write_vmod(new bool) {
	mut vmod_path := if new { '${c.name}/v.mod' } else { 'v.mod' }
	vmod_path = os.join_path(c.app.confg.workspace_dir, vmod_path)
	write_file(vmod_path, vmod_content(c)) or { panic(err) }
}

fn (c &Create) write_gitattributes(new bool) {
	mut gitattributes_path := if new { '${c.name}/.gitattributes' } else { '.gitattributes' }
	gitattributes_path = os.join_path(c.app.confg.workspace_dir, gitattributes_path)
	if !new && os.exists(gitattributes_path) {
		return
	}
	write_file(gitattributes_path, gitattributes_content()) or { panic(err) }
}

fn (c &Create) write_editorconfig(new bool) {
	mut editorconfig_path := if new { '${c.name}/.editorconfig' } else { '.editorconfig' }
	editorconfig_path = os.join_path(c.app.confg.workspace_dir, editorconfig_path)
	if !new && os.exists(editorconfig_path) {
		return
	}
	write_file(editorconfig_path, editorconfig_content()) or { panic(err) }
}

fn (c &Create) create_git_repo(dir string) {
	// Create Git Repo and .gitignore file	
	if !os.is_dir('${dir}/.git') {
		res := os.execute('git init ${dir}')
		if res.exit_code != 0 {
			$if emscripten ? {
				println('Unable to run "git init"')
			} $else {
				cerror('Unable to create git repo')
				exit(4)
			}
		}
	}
	gitignore_path := '${dir}/.gitignore'
	if !os.exists(gitignore_path) {
		write_file(gitignore_path, gen_gitignore(c.name)) or {}
	}
}

fn (mut c Create) create_files_and_directories() {
	for file in c.files {
		// get dir and convert path separator
		mut dir := file.path.split('/')#[..-1].join(os.path_separator)

		dir = os.join_path(c.app.confg.workspace_dir, dir)

		// create all directories, if not exist
		os.mkdir_all(dir) or { panic(err) }

		fp := os.join_path(c.app.confg.workspace_dir, file.path)

		write_file(fp, file.content) or { panic(err) }
	}
}

// ####################################### PROJECTS CONTENT AND PATH #######################################
fn (mut c Create) set_hello_world_project_files() {
	c.files << ProjectFiles{
		path: '${c.name}/src/main.v'
		content: hello_world_content()
	}
}

fn (mut c Create) set_basic_window_files() {
	c.files << ProjectFiles{
		path: '${c.name}/src/main.v'
		content: basic_window_content()
	}
}

fn (mut c Create) set_border_layout_files() {
	c.files << ProjectFiles{
		path: '${c.name}/src/main.v'
		content: border_layout_content()
	}
}

fn (mut c Create) set_web_project_files() {
	c.files << ProjectFiles{
		path: '${c.name}/src/databases/config_databases_sqlite.v'
		content: "module databases

import db.sqlite // can change to 'db.mysql', 'db.pg'

pub fn create_db_connection() !sqlite.DB {
	mut db := sqlite.connect('app.db')!
	return db
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/templates/header_component.html'
		content: "<nav>
  <div class='nav-wrapper'>
    <a href='javascript:window.history.back();' class='left'>
      <i class='material-icons'>arrow_back_ios_new</i>
    </a>
    <a href='/'>
      <img src='src/assets/veasel.png' alt='logo' style='max-height: 100%' />
    </a>
    <ul id='nav-mobile' class='right'>
      <li><a href='https://github.com/vlang/v'>github</a></li>
      <li><a href='https://vlang.io/'>website</a></li>
      <li><a href='https://github.com/sponsors/medvednikov'>support</a></li>
    </ul>
  </div>
</nav>
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/templates/products.css'
		content: 'h1.title {
    font-family: Arial, Helvetica, sans-serif;
    color: #3b7bbf;
}

div.products-table {
    border: 1px solid; 
    max-width: 720px;
    padding: 10px;
    margin: 10px;
}'
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/templates/products.html'
		content: "<!DOCTYPE html>
<head>
    <!--Let browser know website is optimized for mobile-->
    <meta charset='UTF-8' name='viewport' content='width=device-width, initial-scale=1.0'>
    
    <!-- Compiled and minified CSS -->
    <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/css/materialize.min.css'>

    <!-- Compiled and minified JavaScript -->
    <script src='https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/js/materialize.min.js'></script>
    
    <!-- Material UI icons -->
    <link href='https://fonts.googleapis.com/icon?family=Material+Icons' rel='stylesheet'>

    <title>Login</title>
    @css 'src/templates/products.css'
</head>
<body>
    <div>@include 'header_component.html'</div>
    <h1 class='title'>Hi, \${user.username}! you are online</h1>
    <!-- <button onclick='document.location.reload(true)'>Lala</button> -->
      <form id='product_form' method='post' action=''>
        <div class='row'>
            <div class='input-field col s2'>
              <input id='product_name' name='product_name'  type='text' class='validate'>
              <label class='active' for='product_name'>product name</label>
            </div>
            <div style='margin-top: 10px;'>
               <input class='waves-effect waves-light btn-small' type='submit' onclick='addProduct()' formaction='javascript:void(0);' value='Register' required autofocus>
            </div>
          </div>
         <!-- <div style='width: 20; height: 300;'>
            <input type='text' name='product_name' placeholder='product name' required autofocus>
         </div> -->
      </form>
      <script type='text/javascript'>
        function getCookie(cookieName) {
            let cookie = {};
            document.cookie.split(';').forEach(function(el) {
                let [key,value] = el.split('=');
                cookie[key.trim()] = value;
            })
            return cookie[cookieName];
        }
         async function addProduct() {
            const form = document.querySelector('#product_form');
            const formData = new FormData(form);
            console.log(getCookie('token'));
            await fetch('/controller/product/create', {
                 method: 'POST',
                 body: formData,
                 headers :{
                    token: getCookie('token')
                 }
             })                
             .then( async (response) => {
                 if (response.status != 201) {
                     throw await response.text()
                 }
                 return await response.text()
             })
             .then((data) => {
                //  alert('User created successfully')
                 document.location.reload(true)
             })
             .catch((error) => {
                 alert(error);
             });
         }
      </script>
    <div class='products-table card-panel'>
        <table class='highlight striped responsive-table'>
            <thead>
            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Created date</th>
            </tr>
            </thead>

            <tbody>
                @for product in user.products
                <tr>
                    <td>\${product.id}</td>
                    <td>\${product.name}</td>
                    <td>\${product.created_at}</td>
                </tr>
                @end
            </tbody>
        </table>
    </div>
</body>
</html>"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/auth_controllers.v'
		content: "module main

import vweb

['/controller/auth'; post]
pub fn (mut app App) controller_auth(username string, password string) vweb.Result {
	response := app.service_auth(username, password) or {
		app.set_status(400, '')
		return app.text('error: \${err}')
	}

	return app.json(response)
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/auth_dto.v'
		content: 'module main

struct AuthRequestDto {
	username string [required]
	password string [required]
}
'
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/auth_services.v'
		content: "module main

import crypto.hmac
import crypto.sha256
import crypto.bcrypt
import encoding.base64
import json
import databases
import time

struct JwtHeader {
	alg string
	typ string
}

struct JwtPayload {
	sub         string    // (subject) = Entity to whom the token belongs, usually the user ID;
	iss         string    // (issuer) = Token issuer;
	exp         string    // (expiration) = Timestamp of when the token will expire;
	iat         time.Time // (issued at) = Timestamp of when the token was created;
	aud         string    // (audience) = Token recipient, represents the application that will use it.
	name        string
	roles       string
	permissions string
}

fn (mut app App) service_auth(username string, password string) !string {
	mut db := databases.create_db_connection() or {
		eprintln(err)
		panic(err)
	}

	defer {
		db.close() or { panic(err) }
	}

	user := sql db {
		select from User where username == username limit 1
	}
	if user.username != username {
		return error('user not found')
	}

	if !user.active {
		return error('user is not active')
	}

	bcrypt.compare_hash_and_password(password.bytes(), user.password.bytes()) or {
		return error('Failed to auth user, \${err}')
	}

	token := make_token(user)
	return token
}

fn make_token(user User) string {
	secret := 'SECRET_KEY' // os.getenv('SECRET_KEY')

	jwt_header := JwtHeader{'HS256', 'JWT'}
	jwt_payload := JwtPayload{
		sub: '\${user.id}'
		name: '\${user.username}'
		iat: time.now()
	}

	header := base64.url_encode(json.encode(jwt_header).bytes())
	payload := base64.url_encode(json.encode(jwt_payload).bytes())
	signature := base64.url_encode(hmac.new(secret.bytes(), '\${header}.\${payload}'.bytes(),
		sha256.sum, sha256.block_size).bytestr().bytes())

	jwt := '\${header}.\${payload}.\${signature}'

	return jwt
}

fn auth_verify(token string) bool {
	if token == '' {
		return false
	}
	secret := 'SECRET_KEY' // os.getenv('SECRET_KEY')
	token_split := token.split('.')

	signature_mirror := hmac.new(secret.bytes(), '\${token_split[0]}.\${token_split[1]}'.bytes(),
		sha256.sum, sha256.block_size).bytestr().bytes()

	signature_from_token := base64.url_decode(token_split[2])

	return hmac.equal(signature_from_token, signature_mirror)
	// return true
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/index.html'
		content: "<!DOCTYPE html>
<head>
   <!--Let browser know website is optimized for mobile-->
   <meta charset='UTF-8' name='viewport' content='width=device-width, initial-scale=1.0'>
   <!-- Compiled and minified CSS -->
   <link rel='stylesheet' href='https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/css/materialize.min.css'>
   <!-- Compiled and minified JavaScript -->
   <script src='https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/js/materialize.min.js'></script>
   <!-- Material UI icons -->
   <link href='https://fonts.googleapis.com/icon?family=Material+Icons' rel='stylesheet'>
   <title>\${title}</title>
</head>
<body>
   <div>@include 'templates/header_component.html'</div>
   <div  class='card-panel center-align' style='max-width: 240px; padding: 10px; margin: 10px; border-radius: 5px;'>
      <form id='index_form' method='post' action=''>
         <div style='display:flex; flex-direction: column;'>
            <input type='text' name='username' placeholder='Username' required autofocus>
            <input type='password' name='password' placeholder='Password' required>
         </div>
         <div style='margin-top: 10px;'>
            <input class='waves-effect waves-light btn-small' type='submit' onclick='login()' formaction='javascript:void(0);' value='Login'>
            <input class='waves-effect waves-light btn-small' type='submit' onclick='addUser()' formaction='javascript:void(0);' value='Register'>
         </div>
      </form>
      <script type='text/javascript'>
         async function addUser() {
         const form = document.querySelector('#index_form');
         const formData = new FormData(form);
            await fetch('/controller/user/create', {
                 method: 'POST',
                 body: formData
             })                
             .then( async (response) => {
                 if (response.status != 201) {
                     throw await response.text()
                 }
                 return await response.text()
             })
             .then((data) => {
                 alert('User created successfully')
             })
             .catch((error) => {
                 alert(error);
             });
         }
         async function login() {
            const form = document.querySelector('#index_form');
            const formData = new FormData(form);
             await fetch('/controller/auth', {
                 method: 'POST',
                 body: formData
             })  
             .then( async (response) => {
                 if (response.status != 200) {
                     throw await response.text()
                 }
                 return response.json()
             })
             .then((data) => {
                document.cookie = 'token='+data+';';
                window.location.href = '/products'
             })
             .catch((error) => {
                 alert(error);
             });
         }
      </script>
   </div>
</body>
</html>"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/main.v'
		content: "module main

import vweb
import databases
import os

const (
	port = 8082
)

struct App {
	vweb.Context
}

pub fn (app App) before_request() {
	println('[web] before_request: \${app.req.method} \${app.req.url}')
}

fn main() {
	mut db := databases.create_db_connection() or { panic(err) }

	sql db {
		create table User
	} or { panic('error on create table: \${err}') }

	db.close() or { panic(err) }

	mut app := &App{}
	app.serve_static('/favicon.ico', 'src/assets/favicon.ico')
	// makes all static files available.
	app.mount_static_folder_at(os.resource_abs_path('.'), '/')

	vweb.run(app, port)
}

pub fn (mut app App) index() vweb.Result {
	title := 'vweb app'

	return \$vweb.html()
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/product_controller.v'
		content: "module main

import vweb
import encoding.base64
import json

['/controller/products'; get]
pub fn (mut app App) controller_get_all_products() vweb.Result {
	token := app.req.header.get_custom('token') or { '' }

	if !auth_verify(token) {
		app.set_status(401, '')
		return app.text('Not valid token')
	}

	jwt_payload_stringify := base64.url_decode_str(token.split('.')[1])

	jwt_payload := json.decode(JwtPayload, jwt_payload_stringify) or {
		app.set_status(501, '')
		return app.text('jwt decode error')
	}

	user_id := jwt_payload.sub

	response := app.service_get_all_products_from(user_id.int()) or {
		app.set_status(400, '')
		return app.text('\${err}')
	}
	return app.json(response)
	// return app.text('response')
}

['/controller/product/create'; post]
pub fn (mut app App) controller_create_product(product_name string) vweb.Result {
	if product_name == '' {
		app.set_status(400, '')
		return app.text('product name cannot be empty')
	}

	token := app.req.header.get_custom('token') or { '' }

	if !auth_verify(token) {
		app.set_status(401, '')
		return app.text('Not valid token')
	}

	jwt_payload_stringify := base64.url_decode_str(token.split('.')[1])

	jwt_payload := json.decode(JwtPayload, jwt_payload_stringify) or {
		app.set_status(501, '')
		return app.text('jwt decode error')
	}

	user_id := jwt_payload.sub

	app.service_add_product(product_name, user_id.int()) or {
		app.set_status(400, '')
		return app.text('error: \${err}')
	}
	app.set_status(201, '')
	return app.text('product created successfully')
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/product_entities.v'
		content: "module main

[table: 'products']
struct Product {
	id         int    [primary; sql: serial]
	user_id    int
	name       string [required; sql_type: 'TEXT']
	created_at string [default: 'CURRENT_TIMESTAMP']
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/product_service.v'
		content: "module main

import databases

fn (mut app App) service_add_product(product_name string, user_id int) ! {
	mut db := databases.create_db_connection()!

	defer {
		db.close() or { panic(err) }
	}

	product_model := Product{
		name: product_name
		user_id: user_id
	}

	mut insert_error := ''

	sql db {
		insert product_model into Product
	} or { insert_error = err.msg() }

	if insert_error != '' {
		return error(insert_error)
	}
}

fn (mut app App) service_get_all_products_from(user_id int) ?[]Product {
	mut db := databases.create_db_connection() or {
		println(err)
		return err
	}

	defer {
		db.close() or { panic(err) }
	}

	results := sql db {
		select from Product where user_id == user_id
	}

	return results
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/product_view_api.v'
		content: "module main

import json
import net.http

pub fn get_products(token string) ![]Product {
	mut header := http.new_header()
	header.add_custom('token', token)!
	url := 'http://localhost:8082/controller/products'

	mut config := http.FetchConfig{
		header: header
	}

	resp := http.fetch(http.FetchConfig{ ...config, url: url })!
	products := json.decode([]Product, resp.body)!

	return products
}

pub fn get_product(token string) ![]User {
	mut header := http.new_header()
	header.add_custom('token', token)!

	url := 'http://localhost:8082/controller/product'

	mut config := http.FetchConfig{
		header: header
	}

	resp := http.fetch(http.FetchConfig{ ...config, url: url })!
	products := json.decode([]User, resp.body)!

	return products
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/product_view.v'
		content: "module main

import vweb

['/products'; get]
pub fn (mut app App) products() !vweb.Result {
	token := app.get_cookie('token') or {
		app.set_status(400, '')
		return app.text('\${err}')
	}

	user := get_user(token) or {
		app.set_status(400, '')
		return app.text('Failed to fetch data from the server. Error: \${err}')
	}

	return \$vweb.html()
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/user_controllers.v'
		content: "module main

import vweb
import encoding.base64
import json

['/controller/users'; get]
pub fn (mut app App) controller_get_all_user() vweb.Result {
	token := app.req.header.get_custom('token') or { '' }

	if !auth_verify(token) {
		app.set_status(401, '')
		return app.text('Not valid token')
	}

	response := app.service_get_all_user() or {
		app.set_status(400, '')
		return app.text('\${err}')
	}
	return app.json(response)
}

['/controller/user'; get]
pub fn (mut app App) controller_get_user() vweb.Result {
	token := app.req.header.get_custom('token') or { '' }

	if !auth_verify(token) {
		app.set_status(401, '')
		return app.text('Not valid token')
	}

	jwt_payload_stringify := base64.url_decode_str(token.split('.')[1])

	jwt_payload := json.decode(JwtPayload, jwt_payload_stringify) or {
		app.set_status(501, '')
		return app.text('jwt decode error')
	}

	user_id := jwt_payload.sub

	response := app.service_get_user(user_id.int()) or {
		app.set_status(400, '')
		return app.text('\${err}')
	}
	return app.json(response)
}

['/controller/user/create'; post]
pub fn (mut app App) controller_create_user(username string, password string) vweb.Result {
	if username == '' {
		app.set_status(400, '')
		return app.text('username cannot be empty')
	}
	if password == '' {
		app.set_status(400, '')
		return app.text('password cannot be empty')
	}
	app.service_add_user(username, password) or {
		app.set_status(400, '')
		return app.text('error: \${err}')
	}
	app.set_status(201, '')
	return app.text('User created successfully')
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/user_entities.v'
		content: "module main

[table: 'users']
pub struct User {
mut:
	id       int       [primary; sql: serial]
	username string    [required; sql_type: 'TEXT'; unique]
	password string    [required; sql_type: 'TEXT']
	active   bool
	products []Product [fkey: 'user_id']
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/user_services.v'
		content: "module main

import crypto.bcrypt
import databases

fn (mut app App) service_add_user(username string, password string) ! {
	mut db := databases.create_db_connection()!

	defer {
		db.close() or { panic(err) }
	}

	hashed_password := bcrypt.generate_from_password(password.bytes(), bcrypt.min_cost) or {
		eprintln(err)
		return err
	}

	user_model := User{
		username: username
		password: hashed_password
		active: true
	}

	mut insert_error := ''
	sql db {
		insert user_model into User
	} or { insert_error = err.msg() }
	if insert_error != '' {
		return error(insert_error)
	}
}

fn (mut app App) service_get_all_user() ?[]User {
	mut db := databases.create_db_connection() or {
		println(err)
		return err
	}

	defer {
		db.close() or { panic(err) }
	}

	results := sql db {
		select from User
	}

	return results
}

fn (mut app App) service_get_user(id int) ?User {
	mut db := databases.create_db_connection() or {
		println(err)
		return err
	}

	defer {
		db.close() or { panic(err) }
	}

	results := sql db {
		select from User where id == id
	}

	return results
}
"
	}
	c.files << ProjectFiles{
		path: '${c.name}/src/user_view_api.v'
		content: "module main

import json
import net.http

pub fn get_users(token string) ![]User {
	mut header := http.new_header()
	header.add_custom('token', token)!

	url := 'http://localhost:8082/controller/users'

	mut config := http.FetchConfig{
		header: header
	}

	resp := http.fetch(http.FetchConfig{ ...config, url: url })!
	users := json.decode([]User, resp.body)!

	return users
}

pub fn get_user(token string) !User {
	mut header := http.new_header()
	header.add_custom('token', token)!

	url := 'http://localhost:8082/controller/user'

	mut config := http.FetchConfig{
		header: header
	}

	resp := http.fetch(http.FetchConfig{ ...config, url: url })!
	users := json.decode(User, resp.body)!

	return users
}
"
	}
}
