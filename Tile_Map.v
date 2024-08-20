/* Miranda Scully 
 * August 14, 2024 
 * Implementing a tile-based map for COSC 77 final project 
 */ 

module main
import os
import math
import math.complex
import gfx
import json


//map character commands to textures 
type CommandTextureMap = map[string][]Texture 

//taken from P00 Image
type Compositor = fn(c_top Color4, c_bot Color4) Color4

pub struct Tile_Map {
	pub mut: 
	width int //number of tiles on x axis
	height int  //number of tiles on y axis 
	map_tiles [][]int //string coding which tile goes where
}

// convenience type aliases
type Image   = gfx.Image
type Image4  = gfx.Image4
type Point2i = gfx.Point2i
type Size2i  = gfx.Size2i
type Color   = gfx.Color
type Color4  = gfx.Color4

//structure for texture 
pub struct Texture {
	start_coord Point2i //upper left corner of a tile in the sprite sheet 
	size Size2i @[required] //tile width and height
    origin Image4
    u f64
    v f64
}

//structure for tile 
pub struct Tile {
	size Size2i @[required]
	start_x int 
	start_y int 
}
//structure for tile map Sheet 
pub struct Tile_Sheet {
    img Image4
    tile_width int 
    tile_height int 
}

pub struct Character {
	name string
	states CommandTextureMap
	pos Point2i //represents top left corner of character texture 
}

//alternative approach when handling a specific sprite sheet 
//currently using kenney_pixel-platformer 2/Tilemap/tilemap.png
//width and height of tiles are given from the website I downloaded it from
fn define_spritesheet (tile_sheet Tile_Sheet, tile_width int, tile_height int) []Texture {
	mut int_texture_map := []Texture{}

   num_tile_x := int(tile_sheet.img.size.width/tile_width)
   num_tile_y := int(tile_sheet.img.size.height/tile_height)
  
    //textures are stored in row major order 
    //ex. 1234
    //    5678
    //mut current_texture:= 0
    //define texture for grass 
    for i in 0 .. num_tile_y {
        for j in 0 .. num_tile_x {
            // Define the coordinates and size for the texture
            start_coord := Point2i{x: j * tile_width, y: i * tile_height}
            size := Size2i{width: tile_width, height: tile_height}
            u := f64(start_coord.x) / f64(tile_sheet.img.size.width)
            v := 1.0 - (f64(start_coord.y + tile_height) / f64(tile_sheet.img.size.height))

            t := Texture{start_coord: start_coord, size: size, origin: tile_sheet.img, u: u, v: v}
            int_texture_map << t
            
        }
    }

    return int_texture_map
}


// Render the game map from character-texture map
fn create_game_map(texture_map []Texture, mapped Tile_Map, tile_sheet Tile_Sheet) Image4 {
    size := Size2i{width: 480, height: 480}
    mut game_map := gfx.Image4.new(size)

    tile_sheet_img := tile_sheet.img
    for i in 0 .. mapped.map_tiles.len {
		for j in 0 .. mapped.map_tiles[i].len {
			ch := mapped.map_tiles[i][j]
			texture := texture_map[ch]

			tile_x := j * texture.size.width
			tile_y := i * texture.size.height

			for y in 0 .. texture.size.height {
				for x in 0 .. texture.size.width {
					src_x := texture.start_coord.x + x
					src_y := texture.start_coord.y + y
					c := tile_sheet_img.get_xy(src_x, src_y)
					game_map.set_xy(tile_x + x, tile_y + y, c)
				}
			}
		}
	}
    print('generated game map!')
    
    return game_map
}
// Took these functions from P00 Image to use for my character generation on top of a map 
// color_over computes color of c_top over c_bottom
fn color_over(c_top Color4, c_bottom Color4) Color4 {
    mut c := Color4{ 0, 0, 0, 0 }

    //define individual values for rgb 
    mut r := 0.0 
    mut g := 0.0
    mut b := 0.0 
    mut alpha := 0.0

    //create variables for current color values and multiply them
    mut alpha_top := c_top.a
    mut r_top := c_top.r * alpha_top
    mut g_top := c_top.g * alpha_top
    mut b_top := c_top.b * alpha_top

    mut alpha_bottom := c_bottom.a 
    mut r_bottom := c_bottom.r * alpha_bottom
    mut g_bottom := c_bottom.g * alpha_bottom
    mut b_bottom := c_bottom.b * alpha_bottom
   
    //apply formula 
    r = (r_top + (1.0 - alpha_top) * r_bottom)
    g = (g_top + (1.0 - alpha_top) * g_bottom)
    b = (b_top + (1.0 - alpha_top) * b_bottom)
    alpha = (alpha_top + (1.0 - alpha_top) * alpha_bottom)

    //store color as non pre multiplied
    //watch out for dividing by 0 
    if alpha != 0 {
        r = r/alpha 
        g= g/alpha 
        b= b/alpha
    }
    else {
        r= 0.0
        g= 0.0 
        b =0.0
    }
    

    c = Color4{r, g, b, alpha}


    return c
}
//this function is taken from the function provided for us in P00Image but I modified it to adjust for images of differnt sizes
fn render_composite(img_top Image4, img_bot Image4, pos Point2i, fn_composite Compositor) Image4 {

    //top image must be smaller than bottom
    assert img_top.size.width < img_bot.size.width && img_top.size.height < img_bot.size.height 

    //create a new image the size of the game_map (bottom image)
    mut image := gfx.Image4.new(img_bot.size)

    //calculate portion of game map to be composited with 
    start_x := pos.x
    start_y := pos.y
    end_x := start_x + img_top.size.width -1
    end_y := start_y + img_top.size.height -1
    for y in 0 .. img_bot.size.width {
        for x in 0 .. img_bot.size.height {

            //if the top image should be considered
            if x >= start_x && x <= end_x && y >= start_y && y <= end_y {
                c_top := img_top.get_xy(x - start_x, y - start_y)
                c_bot := img_bot.get_xy(x, y)
                c_comp := fn_composite(c_top, c_bot)
                image.set_xy(x, y, c_comp)
            }
            //otherwise just set it to the bottom image
            else {
                c_bot := img_bot.get_xy(x, y)
                image.set_xy(x,y, c_bot)
            }
        }
    }
    return image  

}
//create player state map 
//this function is not generalizable, its specific to the sprite sheet I am using, which has one state per row, and each state has 6 steps
///Users/mirandascully/Desktop/cosc77_final/Woodcutter_attack1.png
fn handle_player_sheet (player_sprites Image4, num_state_steps int, num_states int) CommandTextureMap{
   tile_width := int(player_sprites.size.width/num_state_steps)
   tile_height := int(player_sprites.size.height/num_states)
   mut action_map := CommandTextureMap(map[string][]Texture{})

    //define texture for grass 
    for i in 0 .. num_states {
        mut action := ""
        if i == 0 {
                action = "attack"
            }
            else if i == 1 {
                action = "climb"
            }
            else if i == 2 {
                action = "die"
            }
            else if i == 3 {
                action = "jump"
            }
            else if i == 4 {
                action = "run"
            }
            else if i == 5 {
                action = "walk"
            }
            mut steps := []Texture{}
        for j in 0 .. num_state_steps {
            start_coord := Point2i{x: j * tile_width, y: i * tile_height}
            size := Size2i{width: tile_width, height: tile_height}
            u := f64(start_coord.x) / f64(player_sprites.size.width)
            v := 1.0 - (f64(start_coord.y + tile_height) / f64(player_sprites.size.height))
 
            t := Texture{start_coord: start_coord, size: size, origin: player_sprites, u: u, v: v}
            steps << t
        }
        action_map[action] = steps 

    }

    return action_map
}

//generates an image from a texture, used in character 
fn generate_tile_image (texture Texture) Image4 {
    //create image to store tile
    mut tile_image := gfx.Image4.new(texture.size)

    //iterate through tile image
    for y in 0 .. tile_image.size.height {
        for x in 0 .. tile_image.size.width {
            //get the x and y values on the origin image 
            src_x := texture.start_coord.x + x 
            src_y := texture.start_coord.y + y 

            //get color from origin image 
            c := texture.origin.get_xy(src_x, src_y)

            //set the color on the tile image 
            tile_image.set_xy(x, y, c)
        }
    }

    //return the tile image
    return tile_image
}

//function to create an array of images depicting a character moves based on images in a sprite sheet
//does this by rendering the composite of the character sprite and the game map 
pub fn player_move (player Character, command string, game_map Image4, move_type string, iterations int){
    //define the textures for the player's move 
    textures := player.states[command]
    
    //create an array for the images depicting the movement 
    mut move_array := []Image4

    //character sheet 
    char_sprite_sheet := textures[0].origin

    mut dx := 0 
    mut dy := 0
    // Calculate the step increments
    if move_type == "horizontal" {
         dx = 10
         dy = 0
    }
    else if move_type == "vertical" {
        dx = 0
        dy = 10
    }
    //create images for all the textures in a movement
    mut curr_x := player.pos.x
    mut curr_y := player.pos.y
    for itr in 0 .. iterations {
        for i in 0 .. textures.len {
            sprite_img := generate_tile_image(textures[i])
            curr_pos := Point2i{curr_x, curr_y}
            curr_img := render_composite(sprite_img, game_map, curr_pos, color_over)

            move_array << curr_img
            // Update the player's position
            curr_x+= dx
            curr_y+=dy
        }
    }
    
    mut curr_img := 0
    for move_img in move_array {
        img_name := "move"+curr_img.str()
        move_img.save_png('/Users/mirandascully/Desktop/cosc77_final/playermove1/'+img_name+'.png')
        println("saved image!")
        curr_img+=1
    }
}

//essentially copied this from scene.v and adjusted for my needs 
pub fn tm_from_file(path string) !Tile_Map {
    // load and decode scene from JSON file
    data := os.read_file(path)!
    tile_map := json.decode(Tile_Map, data)!
    return tile_map
}

fn main () {
	//create a string for the tilemap 
   
   tm := tm_from_file('map.json')!

	//define filepath for spritesheet 
	sprite_path := 'tilemap_packed.png'
	// Load the sprite sheet image
    img := gfx.load_png(sprite_path)
    tile_sheet := Tile_Sheet{img: img, tile_width: 16, tile_height: 16}
	
	// //create array of textures from sprite sheet 
	// textures := load_sprite_sheet(sprite_sheet, tm.width, tm.height)

    textures := define_spritesheet(tile_sheet, 16, 16)

	game := create_game_map(textures, tm, tile_sheet)


	   if !os.exists('output') {
        os.mkdir('output') or { panic(err) }
    }

	game.save_png('game_map.png')

    character_sheet := gfx.load_png('Woodcutter_attack1.png')

    player_actions := handle_player_sheet(character_sheet, 6, 6)


    character1 := Character{name: "Miranda", states: player_actions, pos: Point2i{250,250}}

    game_map := gfx.load_png('game_map.png')


    player_move(character1, "run", game_map, "horizontal", 4)

}