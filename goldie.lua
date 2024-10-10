pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- linear interpolation function
function lerp(v0, v1, t)
  return v0 + t * (v1 - v0)
end

function _init()
  sfx(3)
  death_timer = 0
  death_delay = 80
  high_score = 0
  pellet_spawn_timer = 10
  bubbles = {}
  pellets = {}
  yellow_pellet_count = 0
  tilesize = 8
  bubble_cooldown = 0  -- Cooldown timer for bubbles
  bubble_cooldown_max = 20
  player = { x = 3, y = 13, is_dead = false, state = "idle"}
  player.speed = { x = 0, y = 0 }
  player.collision = {
    size = {
      horizontal = {
        width = 10 / tilesize,
        height = 9 / tilesize
      },
      vertical = {
        width = 6 / tilesize,
        height = 13 / tilesize
      }
    }
  }
  player.anims = {
    standing = { 12 },
    eating_yellow = {40, 42},
    eating_green = {44, 46},
    walking = { 12, 34, 32},
    dying = {131, 131}
  }
  updatecollisionbox(player)
  screensize = {
    width = 128,
    height = 128
  }
  mapsize = {
    width = 53,
    height = 32
  }
  
  -- pixels of downward speed applied each frame
  grav = 0 / tilesize
  
  -- horizontal movement speed
  h_speed = 2 / tilesize

  -- vertical movement speed
  v_speed = 2 / tilesize
  
  -- jump speed
  --jumpspeed = 10.5 / tilesize
  
  -- jump buffering
  --jumpbuffer = 3 -- number of frames allowed to buffer jumps
  --jumpframes = jumpbuffer + 1
  --wasjumppressed = false
  
  -- jump grace period
  --jumpgrace = 3 -- number of frames allowed after being on the ground to still jump
  --fallingframes = jumpgrace + 1
  
  -- screen bounding box beyond which the camera will snap back to the player
  camerasnap = { left = 40, top = 16, right = screensize.width - 40, bottom = screensize.height - 48 }
  cam = { x = 0, y = 0 }
end

function _update()
  player.speed.x = 0
  player.speed.y = 0

  if player.state == "dying" then
    -- Floating upward while dying
    if player.y > 11 then  -- Continue floating upwards until y = 11 (or any value)
      player.y -= (1 / tilesize)
    end

    animate(player)  -- Only handle the dying animation

    -- Center the camera on the player while they are dying
    cam.x = player.x * tilesize - screensize.width / 2
    cam.y = player.y * tilesize - screensize.height / 2
    return  -- Skip other updates if the player is dead
    end

  -- decrementing bubble cooldown
  if bubble_cooldown > 0 then
    bubble_cooldown -= 1
  end
  -- updating horizontal speed
  if btn(0) then
    player.speed.x -= h_speed
  end
  if btn(1) then
    player.speed.x += h_speed
  end

  --updating vertical speed
  if btn(2) then
    player.speed.y -= v_speed
  end
  if btn(3) then
    player.speed.y += v_speed
  end

  if btn(4) and bubble_cooldown == 0 then
    spawn_bubble(player.x * tilesize, player.y * tilesize - 8) -- Spawn bubbles
    bubble_cooldown = bubble_cooldown_max
  end
  

  update_pellets() 
  update_bubbles()
  applyphysics(player)
  animate(player)



  pellet_spawn_timer -= 1
  if pellet_spawn_timer <= 0 then
    spawn_pellet()  -- Spawn a new pellet
    pellet_spawn_timer = 10  -- Reset timer
  end

 -- Update pellet positions


  -- update camera position
  local screenx, screeny = player.x * tilesize - cam.x, player.y * tilesize - cam.y
  
  if screenx < camerasnap.left then
    cam.x += screenx - camerasnap.left
  elseif screenx > camerasnap.right then
    cam.x += screenx - camerasnap.right
  else
    local center = player.x * tilesize - screensize.width / 2
    cam.x += (center - cam.x) / 6
  end
  
  if screeny < camerasnap.top then
    cam.y += screeny - camerasnap.top
  elseif screeny > camerasnap.bottom then
    cam.y += screeny - camerasnap.bottom
  elseif player.onground then
    local center = player.y * tilesize - screensize.height / 2
    cam.y += (center - cam.y) / 6
  end

  local maxcamx, maxcamy = 
    max(0, mapsize.width * tilesize - screensize.width), 
    max(0, mapsize.height * tilesize - screensize.height)
    
  cam.x = mid(0, cam.x, maxcamx)
  cam.y = mid(0, cam.y, maxcamy)
end

function animate(entity)

  if player.state == "dying" then
    -- Play the dying animation (repeat if necessary)
    entity.animframes += 1
    entity.frame = (flr(entity.animframes / 10) % #entity.anims["dying"]) + 1

    -- After the dying animation finishes (based on the number of frames)
    if entity.animframes >= 100 then
      player.state = "dead"  -- Transition to a "dead" state (or restart the game)
      restart_game()
      -- You can choose to reset the game here or stop the game until restart
    end
    return  -- Skip other animations while dying
  end

  if player.state == "eating_yellow" then
    -- Play the eating animation for the yellow pellet
    entity.animframes += 1
    entity.frame = (flr(entity.animframes / 10) % #entity.anims["eating_yellow"]) + 1

    -- If the animation has played through both frames, go back to idle
    if entity.animframes >= 20 then
      player.state = "idle"  -- Reset to idle after eating animation
      setanim(entity, "standing")
    end
    return  -- Do not execute any other animation while eating
  end

  if entity.speed.x ~= 0 then
    setanim(entity, "walking")
  elseif entity.speed.y ~= 0 then
    setanim(entity, "walking")
  else  
    setanim(entity, "standing")
  end
  
  if entity.animframes % 3 == 0 then
    entity.frame = (flr(entity.animframes / 3) % #entity.anim) + 1
  end
  entity.animframes += 1
  
  if entity.speed.x < 0 then
    entity.mirror = false
  elseif entity.speed.x > 0 then
    entity.mirror = true
  end
end

function setanim(entity, name)
  if entity.anim ~= entity.anims[name] then
    entity.anim = entity.anims[name]
    entity.animframes = 0
  end
end


function spawn_bubble(x, y)
    -- Create a bubble at the player's position
    local bubble = {
      x = x + rnd(4) - 2,  -- Random horizontal offset for variety
      y = y,
      speed = -0.5 + rnd(0.1), -- Random upward speed (slightly random for variety)
      size = 0.5 + rnd(0,1),        -- Random size for bubble
      sprite = 6
    }
    
    -- Add the bubble to the bubbles list
    add(bubbles, bubble)
  end

  function update_bubbles()
    -- Loop through each bubble and update its position
    for bubble in all(bubbles) do
      bubble.y += bubble.speed  -- Move the bubble upward
      
      -- eating a pellet bubble
      if bubble.sprite == 8 then
        -- Check for a collision between the player and the bubble with the pellet
        if check_collision(bubble, player) then
            -- Trigger eating animation for the player (you can use either yellow or green depending on your setup)
            player.state = "eating_yellow"
            setanim(player, "eating_yellow")
            yellow_pellet_count += 2
            sfx(5)
            h_speed += (0.2 / tilesize)
            v_speed += (0.2 / tilesize)
            del(bubbles, bubble)  -- Remove the bubble once eaten
        end
    end


      for pellet in all(pellets) do
        if check_bubble_pellet_collision(bubble, pellet) then
            -- If a collision is detected, change bubble sprite to 8
            if pellet.color == 10 then
              bubble.sprite = 8
            else
              bubble.sprite = 24
            end
            -- Optionally, you can delete the pellet after collision
            del(pellets, pellet)
            break  -- No need to check more pellets after a collision
        end
    end
      -- Remove the bubble if it moves off the screen
      if bubble.y < 0 then
        del(bubbles, bubble)  -- Remove bubble from the list
      end
    end
  end
  

function applyphysics(entity)
  local speed = entity.speed

  local wasonground = entity.onground -- we need to know if the entity started on the ground for slopes
  entity.onground = false
  
  -- increase precision by applying physics in smaller steps
  -- the more steps, the faster things can go without going through terrain
  local steps = 1
  local highestspeed = max(abs(speed.x), abs(speed.y))
  
  if highestspeed >= 0.25 then
    steps = ceil(highestspeed / 0.25)
  end
  
  for i = 1, steps do
    entity.x += speed.x / steps
    entity.y += speed.y / steps
    
    updatecollisionbox(entity)
    
    -- slope collisions
    for tile in gettiles(entity, "floor") do
      if tile.sprite > 0 then
        local tiletop = tile.y
      
        if tile.slope then
          local slope = tile.slope
          local xoffset = entity.x - tile.x
          
          if xoffset < 0 or xoffset > 1 then
            -- only do slopes if the entity's center x coordinate is inside the tile space
            -- otherwise ignore this tile
            tiletop = nil
          else
            local alpha
            if slope.reversed then
              alpha = 1 - xoffset
            else
              alpha = xoffset
            end
            
            local slopeheight = lerp(slope.offset, slope.offset + slope.height, alpha)
            tiletop = tile.y + 1 - slopeheight
            
            -- only snap the entity down to the slope's height if it wasn't jumping or on the ground
            if entity.y >= tiletop and not (btn(2)) then
                -- Snap to the slope's surface
                speed.y = 0
                entity.y = tiletop
                entity.onground = true
                fallingframes = 0
              end
            end
          else
            tiletop = nil
          end
        end
      end
    
    updatecollisionbox(entity)
    
    -- wall collisions
    for tile in gettiles(entity, "horizontal") do
      if tile.sprite > 0 and not tile.slope then
        if entity.x < tile.x + 0.5 then
          -- push out to the left
          entity.x = tile.x - entity.collision.size.horizontal.width / 2
        else
          -- push out to the right
          entity.x = tile.x + 1 + entity.collision.size.horizontal.width / 2
        end
      end
    end
    
    updatecollisionbox(entity)
    
    -- floor collisions
    for tile in gettiles(entity, "floor") do
      if tile.sprite > 0 and not tile.slope then
        speed.y = 0
        entity.y = tile.y
        entity.onground = true
        fallingframes = 0
      end
    end
    
    updatecollisionbox(entity)
    
    -- ceiling collisions
    for tile in gettiles(entity, "ceiling") do
      if tile.sprite > 0 and not tile.slope then
        speed.y = 0
        entity.y = tile.y + 1 + entity.collision.size.vertical.height
      end
    end
  end
end

-- gets all tiles that might be intersecting entity's collision box
function gettiles(entity, boxtype)
  local box = entity.collision.box[boxtype]
  local left, top, right, bottom =
    flr(box.left), flr(box.top), flr(box.right), flr(box.bottom)
    
  local x, y = left, top
    
  -- iterator function
  return function()
    if y > bottom then
      return nil
    end
    
    local sprite = mget(x, y)
    local ret = { sprite = sprite, x = x, y = y }

    local flags = fget(sprite)

    if band(flags, 128) == 128 then
      -- this is a slope if flag 7 is set
      ret.slope = {
        reversed = band(flags, 64) == 64, -- reversed if flag 6 is set,
        height = (band(flags, 7) + 1) / tilesize, -- the first 3 bits/flags set the slope height from 1-8
        offset = band(lshr(flags, 3), 7) / tilesize -- bits/flags 4 through 6 set the offset from the bottom of the tile between 0 and 7
      }
    end

    x += 1
    if x > right then
      x = left
      y += 1
    end
    
    return ret
  end
end

function updatecollisionbox(entity)
  local size = entity.collision.size

  entity.collision.box = {
    horizontal = {
      left = entity.x - size.horizontal.width / 2,
      top = entity.y - size.vertical.height + (size.vertical.height - size.horizontal.height) / 2,
      right = entity.x + size.horizontal.width / 2,
      bottom = entity.y - (size.vertical.height - size.horizontal.height) / 2
    },
    floor = {
      left = entity.x - size.vertical.width / 2,
      top = entity.y - size.vertical.height / 2,
      right = entity.x + size.vertical.width / 2,
      bottom = entity.y
    },
    ceiling = {
      left = entity.x - size.vertical.width / 2,
      top = entity.y - size.vertical.height,
      right = entity.x + size.vertical.width / 2,
      bottom = entity.y - size.vertical.height / 2
    }
  }
end

function update_pellets()
  to_remove = {}
  -- Loop through each pellet and update its position
  for pellet in all(pellets) do
      pellet.y += pellet.speed  -- Move the pellet downward
      rand_num = rnd(1)
      if rand_num < 0.5 then
          pellet.x += 1
      else
          pellet.x -=1
      end

      -- Check if the pellet collides with the player
      if check_collision(pellet, player) then
          -- Check the color of the pellet
          if pellet.color == 10 then  -- Yellow pellet
              player.state = "eating_yellow"
              setanim(player, "eating_yellow")  -- Trigger eating yellow animation
              sfx(4)
              yellow_pellet_count += 1
              h_speed += (0.1 / tilesize)
              v_speed += (0.1 / tilesize)
          elseif pellet.color == 8 then  -- Red pellet
              player.is_dead = true
              --setanim(player, "eating_green")  -- Trigger eating green animation
              player.state = "dying"
              setanim(player, "dying")
              sfx(-1)
              sfx(1)
          end
          add(to_remove, pellet)
      end

      local tile_x = flr(pellet.x / tilesize)  -- Convert pellet x to map tile
      local tile_y = flr(pellet.y / tilesize)  -- Convert pellet y to map tile
      local tile = mget(tile_x, tile_y)  -- Get the tile at this position

      -- If the tile is solid (non-zero) and not empty, remove the pellet
      if fget(tile,0) and tile_y > 9 then -- tile y position is greater than 9 (in the water)
        add(to_remove, pellet)  -- Remove pellet upon collision with any object
      end
  end
  -- Remove the pellets
  for pellet in all(to_remove) do
    del(pellets, pellet)
  end
end

function _draw()
  camera(cam.x, cam.y)

  pal()
  palt(0, false)
  palt(2, true)

  cls(12)
  map(0, 0, 0, 0)
  
  spr(player.anim[player.frame], player.x * tilesize - 8, player.y * tilesize - 16, 2, 2, player.mirror)

  draw_bubbles()
  draw_pellets()
  print("Score: "..yellow_pellet_count, cam.x + 1, cam.y + 10, 0)  -- The number 7 is the color (white)
  print("High Score: "..high_score, cam.x + 1, cam.y + 17, 0)
end

function draw_bubbles()
    for bubble in all(bubbles) do
        spr(bubble.sprite, bubble.x, bubble.y, 1, 1)
    end
  end

function spawn_pellet()
    -- Random color generation: 70% yellow, 30% green
    local color = 10 -- yellow by default
    if rnd(1) < 0.3 then
        color = 8 -- green
    end

    local pellet = {
        x = rnd(408),  -- Random horizontal position
        y = 0,                      -- Start from the top of the screen
        speed = 1 + rnd(1),         -- Random downward speed for variety
        size = 1,         
        color = color               -- Set the color
    }

    add(pellets, pellet)
end



function draw_pellets()
    for pellet in all(pellets) do
        circfill(pellet.x, pellet.y, pellet.size, pellet.color) -- Draw the pellet as a single pixel
    end
end

function check_collision(pellet, player)
  -- Simple box collision detection
  local pellet_left = pellet.x -1
  local pellet_right = pellet.x + pellet.size +1
  local pellet_top = pellet.y -1
  local pellet_bottom = pellet.y + pellet.size +1

  local player_left = player.x * tilesize -4
  local player_right = player.x * tilesize  +4
  local player_top = player.y * tilesize -4
  local player_bottom = player.y * tilesize +4

  return not (pellet_right < player_left or
              pellet_left > player_right or
              pellet_bottom < player_top or
              pellet_top > player_bottom)
end

function check_bubble_pellet_collision(bubble, pellet)
  local bubble_left = bubble.x
  local bubble_right = bubble.x + 4
  local bubble_top = bubble.y
  local bubble_bottom = bubble.y + 4

  -- Pellet's collision box (assuming it's 2x2 pixels)
  local pellet_left = pellet.x
  local pellet_right = pellet.x + pellet.size
  local pellet_top = pellet.y
  local pellet_bottom = pellet.y + pellet.size

  -- Check for overlap between bubble and pellet
  return not (bubble_right < pellet_left or
              bubble_left > pellet_right or
              bubble_bottom < pellet_top or
              bubble_top > pellet_bottom)
end

function check_collision(bubble, player)
  -- Adjust the collision box for the bubble (assuming 4x4 pixels)
  local bubble_left = bubble.x
  local bubble_right = bubble.x + 4  -- Adjust based on the size of the bubble
  local bubble_top = bubble.y
  local bubble_bottom = bubble.y + 4

  -- Player bounds (8x8 pixels)
  local player_left = player.x * tilesize - 4
  local player_right = player.x * tilesize + 4
  local player_top = player.y * tilesize - 4
  local player_bottom = player.y * tilesize + 4

  -- Return true if there's an overlap between the bubble and the player
  return not (bubble_right < player_left or
              bubble_left > player_right or
              bubble_bottom < player_top or
              bubble_top > player_bottom)
end

function restart_game()
  -- Reset the game variables
  if yellow_pellet_count > high_score then
    high_score = yellow_pellet_count
  end
  sfx(3)
  player.x = 3
  player.y = 13
  player.is_dead = false
  player.speed = { x = 0, y = 0 }
  h_speed = 2 / tilesize
  v_speed = 2 / tilesize
  yellow_pellet_count = 0
  pellets = {}
  bubbles = {}
  pellet_spawn_timer = 10
  cam.x, cam.y = 0, 0
end

