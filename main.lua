--------------------------
--                      --
--     Five Seconds     --
--                      --
--------------------------

-- Level 1, only clocks
level1 =
   {base_loot = {clock = 3,
                 super_clock = 1,
                 bullet = 0,
                 enemy = 0,
                 box = 1},
    enemy_loot = {clock = 2,
                  super_clock = 2},
    box_size = 3,
    box_loot = {clock = 3,
                super_clock = 1,
                bullet = 0},
    speed = 700,
    timeout_f = function() return math.random()/10 end,
    e_speed_min = 100,
    e_speed_max = 500
   }

-- Level 2, a little bit of everything
level2 =
   {base_loot = {clock = 3,
                 super_clock = 2,
                 bullet = 4,
                 enemy = 4,
                 box = 3},
    enemy_loot = {clock = 1,
                  super_clock = 3},
    box_size = 3,
    box_loot = {clock = 3,
                super_clock = 1,
                bullet = 8},
    speed = 700,
    timeout_f = function() return math.random()/10 end,
    e_speed_min = 100,
    e_speed_max = 300
   }

-- Level 3, a little bit of everything but with very fast enemies
level3 =
   {base_loot = {clock = 3,
                 super_clock = 2,
                 bullet = 2,
                 enemy = 4,
                 box = 4},
    enemy_loot = {clock = 0,
                  super_clock = 1},
    box_size = 3,
    box_loot = {clock = 3,
                super_clock = 2,
                bullet = 4},
    speed = 700,
    timeout_f = function() return 3 end,
    e_speed_min = 500,
    e_speed_max = 800
   }

function copy(t)
   if type(t) ~= "table" then return t
   else
      local res = {}
      for k, v in pairs(t) do
         res[k] = copy(v)
      end
      return res
   end
end

-- Level 4, a little bit of everything but the enemies are following you
level4 = copy(level3)
level4.smart = true
function level4.timeout_f()
   return math.random()
end

-- Level 5, only enemies
level5 =
   {base_loot = {clock = 0,
                 super_clock = 0,
                 bullet = 1,
                 enemy = 3,
                 box = 1},
    enemy_loot = {clock = 0,
                  super_clock = 1},
    box_size = 3,
    box_loot = {clock = 0,
                super_clock = 0,
                bullet = 1},
    speed = 700,
    timeout_f = function() return math.random()/10 + 0.6 end,
    e_speed_min = 30,
    e_speed_max = 50
   }

levels = {level1, level2, level3, level4, level5}

--if love.web then
function love.graphics.setColorMode(str)
   if str == "replace" then
      love.graphics.setColor(255, 255, 255, 255)
   end
end
--end


space_to_continue = false
wait_timer = 0
b_speed = 1000
ft_speed = 500
fi_speed = 3
level = 0
splash = 1
flying_texts = {}
flying_items = {}
fired_bullets = {}

function init(x, y, width, height, pos_x, pos_y)
   game_time = 0
   last_bonus_time = -1
   current_time = 5

   field = {x, y, width, height,
            left = x, top = y, right = x + width, bot = y + height}
   pos = {x = pos_x, y = pos_y}
   objects = {}
   enemies = {}
   fired_bullets = {}
   flying_texts = {}
   flying_items = {}
   bullets = 0
   game_over = false
end

function needed()
   local there_are_bullets = (bullets > 0)
   local there_are_boxes = false
   for i = 1, #objects do
      o = objects[i]
      if o.type == "clock" or o.type == "super_clock"
         or o.type == "box" and levels[level].box_loot.bullet == 0
      then
         return "nothing"
      end
      if o.type == "bullet" then there_are_bullets = true end
      if o.type == "box" then there_are_boxes = true end
   end
   if #enemies > 0 and there_are_bullets
   then
      return "nothing"
   end
   if #enemies > 0
   then
      return "bullets"
   end
   if there_are_bullets
   then
      return "enemies"
   end
   return "clocks"
end

prev_k = ""
-- Takes a table whose values are non-negative integers and return a random key,
-- the corresponding value being the coefficient
function proportionate(table)
   local sum = 0
   for _, v in pairs(table) do
      sum = sum + v
   end
   function find_key()
      local rand = math.random(sum)
      for k, v in pairs(table) do
         if rand <= v then return k
         else rand = rand - v end
      end
   end
   local k = find_key()
   if k == prev_k and math.random() >= 1/3 then k = find_key() end
   prev_k = k
   return k
end

function create_object(type, x, y)
   table.insert(objects, {x = math.floor(x), y = math.floor(y),
                          type = type, ttl = 5})
end

function generate_thing(prop, safe)
   local thing_needed = needed()
   local type
   if thing_needed == "nothing" or not safe
   then
      type = proportionate(prop)
   else
      if ((prop.clock and prop.clock > 0)
          or (prop.super_clock and prop.super_clock > 0))
      then
         thing_needed = "clocks"
      end
      local i = 0
      repeat
         i = i + 1
         type = proportionate(prop)
      until (i > 20
             or (thing_needed == "clocks" and
             (type == "clock" or type == "super_clock"))
             or (thing_needed == "bullets" and type == "bullet")
             or (thing_needed == "enemies" and type == "enemy"))
   end
   local x, y
   repeat
      x = math.random(field.left + 16, field.right - 16)
      y = math.random(field.top  + 16, field.bot - 16)
   until (math.abs(x - pos.x) > 128 and math.abs(y - pos.y) > 128)
   if type == "enemy" then
      create_enemy(x, y)
   else
      create_object(type, x, y)
   end
end

function generate_flying_thing(prop, xo, yo, xd, yd, do_not_add)
   local type = proportionate(prop)
   if not xd or not yd then
      repeat
         xd = math.random(field.left + 16, field.right - 16)
         yd = math.random(field.top  + 16, field.bot - 16)
      until (math.abs(xd - pos.x) > 128 and math.abs(yd - pos.y) > 128)
   end
   local flying = {x = xd, y = yd, xo = xo, yo = yo, time = 0, type = type,
                   do_not_add = not not do_not_add}
   function flying:move(dt)
      self.time = self.time + dt * fi_speed
   end
   table.insert(flying_items, flying)
end

function create_enemy(x, y)
   local enemy = {}
   enemy.speed = math.random(levels[level].e_speed_min, levels[level].e_speed_max)
   enemy.timeout = 0
   enemy.x = x
   enemy.y = y
   function enemy:move(dt)
      if not self.angle then self.angle = 0 end
      local new_x = self.x + dt * self.speed * math.cos(self.angle)
      local new_y = self.y + dt * self.speed * math.sin(self.angle)
      local new_timeout = levels[level].timeout_f()
      local boing = false
      if new_x < field.left + 16 then
         self.timeout = new_timeout
         self.angle = math.random() * math.pi - (math.pi / 2)
         boing = true
      end
      if new_x > field.right - 16 then
         self.timeout = new_timeout
         self.angle = math.random() * math.pi + (math.pi / 2)
         boing = true
      end
      if new_y < field.top + 16 then
         self.timeout = new_timeout
         self.angle = math.random() * math.pi
         boing = true
      end
      if new_y > field.bot - 16 then
         self.timeout = new_timeout
         self.angle = - math.random() * math.pi
         boing = true
      end
      if self.timeout <= 0 then
         self.timeout = new_timeout
         if levels[level].smart then
            self.angle = (math.random() - 0.5) * math.pi / 2
               + math.atan2(pos.y - new_y, pos.x - new_x)
         else
            self.angle = math.random() * 2 * math.pi
         end
      end
      if not boing then
         self.x = new_x
         self.y = new_y
      end
      self.timeout = self.timeout - dt
   end

   table.insert(enemies, enemy)
end

function create_flying_text(text, x, y, angle, r, g, b)
   local flying_text = {text = text, x = x, y = y, angle = angle,
                        r = r, g = g, b = b, a = 255, s = 1}
   function flying_text:move(dt)
      self.x = self.x + dt * ft_speed * math.cos(self.angle)
      self.y = self.y + dt * ft_speed * math.sin(self.angle)
      self.a = self.a - dt * 255 / 2
      self.s = 5 - self.a * 4 / 255
   end
   table.insert(flying_texts, flying_text)
end

function create_flying_10s()
   flying_10s = {x = 750, y = 50,
                 r = 255, g = 196, b = 0, a = 255, s = 1}
   function flying_10s:move(dt)
      self.x = self.x - dt * ft_speed / 2
      self.y = self.y + dt * ft_speed * 0.6 / 2
      self.a = self.a - dt * 255 / 2
      self.s = (5 - self.a * 4 / 255) * 3 / 15
      if self.a < 0 then flying_10s = nil end
   end
end

function love.load()
   splash_img = {}
   splash_img[1] = love.graphics.newImage("Images/splash0.png")
   loading_img = love.graphics.newImage("Images/loading.png")
   love.graphics.draw(splash_img[1], 0, 0)
   love.graphics.draw(loading_img, 50, 550)
   love.graphics.present()

   background_img = love.graphics.newImage("Images/background.png")
   player_img = love.graphics.newImage("Images/player.png")
   clock_img = love.graphics.newImage("Images/clock.png")
   super_clock_img = love.graphics.newImage("Images/super_clock.png")
   bullet_img = love.graphics.newImage("Images/bullet.png")
   fired_bullet_img = love.graphics.newImage("Images/fired_bullet.png")
   box_img = love.graphics.newImage("Images/box.png")
   enemy_img = love.graphics.newImage("Images/enemy.png")
   splash_img[2] = love.graphics.newImage("Images/splash1.png")
   splash_img[3] = love.graphics.newImage("Images/splash2.png")
   splash_img[4] = love.graphics.newImage("Images/splash3.png")
   splash_img[5] = love.graphics.newImage("Images/splash4.png")
   splash_img[6] = love.graphics.newImage("Images/splash5.png")
   timeout_img = love.graphics.newImage("Images/timeout.png")
   killed_img = love.graphics.newImage("Images/killed.png")
   won_img = love.graphics.newImage("Images/won.png")
   mega_won_img = love.graphics.newImage("Images/mega_won.png")
   space_img = love.graphics.newImage("Images/space.png")
   full_gauge_img = love.graphics.newImage("Images/full_gauge.png")
   empty_gauge_img = love.graphics.newImage("Images/empty_gauge.png")
   limit_gauge_img = love.graphics.newImage("Images/limit_gauge.png")
   flying_10s_img = love.graphics.newImage("Images/10s.png")

   function love.audio.newMultipleSource(file, n)
      n = n or 2

      local t = {}

      for i = 1, n do
         t[i] = love.audio.newSource(file)
      end

      function t:play()
         for i = 1, #t + 1 do
            if t[i] then
               if t[i]:isStopped() then
                  t[i]:play()
                  break
               end
            else
               t[i] = love.audio.newSource(file)
               t[i]:play()
            end
         end
      end
      return t
   end

   tac_snd = love.audio.newMultipleSource("Sounds/tac.ogg")
   tactac_snd = love.audio.newMultipleSource("Sounds/tactac.ogg")
   ding_snd = love.audio.newMultipleSource("Sounds/ding.ogg")
   prout_snd = love.audio.newMultipleSource("Sounds/prout.ogg")
   piou_snd = love.audio.newMultipleSource("Sounds/piou.ogg")
   touc_snd = love.audio.newMultipleSource("Sounds/touc.ogg")
   boum_snd = love.audio.newMultipleSource("Sounds/boum.ogg")
   timeout_snd = love.audio.newMultipleSource("Sounds/timeout.ogg")
   victory_snd = love.audio.newMultipleSource("Sounds/victory.ogg")

   if not love.web then
      font = love.graphics.newFont(36)
   else
      font = love.graphics.newImageFont("imgfont.png", "Level 12345+s")
   end
   love.graphics.setFont(font)

   love.graphics.setBackgroundColor(236,237,181)
   love.graphics.setColorMode("replace")
   love.event.clear()
end

function dist(pos1, pos2)
   return math.sqrt((pos1.x - pos2.x) ^ 2 + (pos1.y - pos2.y) ^ 2)
end

-- function play_sound(s)
--    for i = 1, 10 do
--       if s[i]:isStopped() then
--          s[i]:play()
--          return
--       end
--    end
-- end

-- function play_ding()
--    play_sound(dings_snd)
-- end

-- function play_prout()
--    play_sound(prout_snd)
-- end

-- function play_piou()
--    play_sound(piou_snd)
-- end

-- function play_touc()
--    play_sound(touc_snd)
-- end

function love.update(dt)
   if wait_timer > 0 then wait_timer = wait_timer - dt end
   if wait_timer < 0 then wait_timer = 0 end
   if level > 0 and not game_over then

      -- Updating timers
      current_time = current_time - dt
      game_time = game_time + dt

      -- Movements

      local x = 0
      local y = 0
      -- if love.joystick.isOpen(1) then
      --    x, y = love.joystick.getAxes(1)
      --    if math.abs(x) < 0.15 then x = 0 end
      --    if math.abs(y) < 0.15 then y = 0 end
      -- end

      if x ~= 0 or y ~= 0 then
         local speed = levels[level].speed
         if x * x + y * y > 1 then
            local coeff = math.sqrt(x * x + y * y)
            speed = speed / coeff
         end
         pos.x = pos.x + dt * x * speed
         pos.y = pos.y + dt * y * speed
      else
         local speed = levels[level].speed
         if (love.keyboard.isDown("left") or love.keyboard.isDown("right"))
            and (love.keyboard.isDown("up") or love.keyboard.isDown("down"))
         then
            speed = speed * math.sqrt(0.5)
         end
         if love.keyboard.isDown("left") then
            pos.x = pos.x - dt * speed
         end
         if love.keyboard.isDown("right") then
            pos.x = pos.x + dt * speed
         end
         if love.keyboard.isDown("up") then
            pos.y = pos.y - dt * speed
         end
         if love.keyboard.isDown("down") then
            pos.y = pos.y + dt * speed
         end
      end

      pos.x = math.min(pos.x, field.right - 16)
      pos.x = math.max(pos.x, field.left + 16)
      pos.y = math.min(pos.y, field.bot - 16)
      pos.y = math.max(pos.y, field.top + 16)

      function obj_size(o)
         if o.type == "bullet" then return 4 else return 16 end
      end

      -- Picking up items
      for i = 1, #objects do
         local o = objects[i]
         if o and dist(pos, o) < 16 + obj_size(o) then
            if o.type == "clock" then
               table.remove(objects, i)
               current_time = current_time + 1
               create_flying_text("+1s", o.x, o.y,
                                  math.pi + math.atan2(o.y - (50 + 50 * (10 - current_time)), o.x - 700)
                                  , 0, 0, 255)
               ding_snd:play()
            elseif o.type == "super_clock" then
               table.remove(objects, i)
               current_time = current_time + 2
               create_flying_text("+2s", o.x, o.y,
                                  math.pi + math.atan2(o.y - (50 + 50 * (10 - current_time)), o.x - 700)
                                  , 0, 255, 0)
               ding_snd:play()
            elseif o.type == "bullet" then
               if bullets < 6 then
                  table.remove(objects, i)
                  bullets = bullets + 1
                  touc_snd:play()
                  generate_flying_thing({bullet = 1}, o.x, o.y, 668, bullets * 20 + 50, true)
               end
            elseif o.type == "box" then
               for j = 1, levels[level].box_size do
                  generate_flying_thing(levels[level].box_loot,
                                        o.x, o.y)
               end
               table.remove(objects, i)
            end
         end
      end

      -- Creating new things
      if game_time > last_bonus_time + 1 then
         last_bonus_time = last_bonus_time + 1
         generate_thing(levels[level].base_loot, current_time < 2.5)
         if current_time < 2.5 then tactac_snd:play() else tac_snd:play() end
      end

      -- Removing old things
      for i = 1, #objects do
         o = objects[i]
         if o then
            o.ttl = o.ttl - dt
            if o.ttl < 0 then
               table.remove(objects, i)
            end
         end
      end

      -- Killing enemies
      for i = 1, #enemies do
         for j = 1, #fired_bullets do
            if enemies[i] and fired_bullets[j]
               and dist(enemies[i], fired_bullets[j]) < 16 + 8 then
            create_object(proportionate(levels[level].enemy_loot),
                          enemies[i].x, enemies[i].y)
            table.remove(enemies, i)
            prout_snd:play()
            end
         end
      end

      -- Getting killed
      for i = 1, #enemies do
         if dist(pos, enemies[i]) < 16 + 16
         then
            lose_killed()
         end
      end

      -- Moving enemies
      for i = 1, #enemies do
         enemies[i]:move(dt)
      end

      -- Moving bullets
      for i = 1, #fired_bullets do
         fired_bullets[i]:move(dt)
      end

      if current_time <= 0 then lose_timeout() end
      if current_time > 10 then win() end
   end

   -- Moving flying texts
   for i = 1, #flying_texts do
      flying_texts[i]:move(dt)
   end

   -- Moving flying 10s
   if flying_10s
   then
      flying_10s:move(dt)
   end

   -- Moving flying items
   for i = 1, #flying_items do
      local f = flying_items[i]
      if f then
         f:move(dt)
         if f.time > 1 then
            if not f.do_not_add then
               create_object(f.type, f.x, f.y)
            end
            table.remove(flying_items, i)
         end
      end
   end
end

function draw_space_to_continue()
   if space_to_continue then return end
   wait_timer = .5
   space_to_continue = true
end

function draw_img(img, x, y, ttl, ...)
   local alpha = math.max(0, math.min(ttl, 1))

   love.graphics.setColorMode("modulate")
   love.graphics.setColor(128, 128, 128, 200 * alpha)
   love.graphics.draw(img, x + 2, y + 2, ...)
   love.graphics.setColor(255, 255, 255, 255 * alpha)
   love.graphics.draw(img, x, y, ...)
   love.graphics.setColorMode("replace")
end

function love.draw()
   if level == 0 and not space_to_continue then
      draw_space_to_continue()
   end

   if level == 0 then
      love.graphics.draw(splash_img[splash])
   end

   if level > 0 then

   -- Draw time bar
   local q = love.graphics.newQuad(0, 50 * (10 - current_time),
                                   50, 500 - 50 * (10 - current_time),
                                   50, 500)
   love.graphics.draw(empty_gauge_img, 700, 50)
   love.graphics.drawq(full_gauge_img, q, 700, 50 + 50 * (10 - current_time))
   love.graphics.draw(limit_gauge_img, 700, 45 + 50 * (10 - current_time))
   -- love.graphics.setColor(255, 0, 0)
   -- love.graphics.rectangle("fill", 700, 50, 50, 500)
   -- love.graphics.setColor(0, 255, 0)
   -- love.graphics.rectangle("fill", 700, 50 + 50 * (10 - current_time),
   --                         50, 500 - 50 * (10 - current_time))

   -- Draw background
   love.graphics.draw(background_img, 0, 0)

   -- Draw bullets
   for i = 1, 6 do
      if i <= bullets then
         love.graphics.draw(bullet_img, 668, i * 20 + 50)
      end
   end

   -- Draw items
   for i = 1, #objects do
      local o = objects[i]
      if o.type == "clock" then
         draw_img(clock_img, o.x - 16, o.y - 16, o.ttl)
      elseif o.type == "super_clock" then
         draw_img(super_clock_img, o.x - 16, o.y - 16, o.ttl)
      elseif o.type == "bullet" then
         draw_img(bullet_img, o.x - 8, o.y - 8, o.ttl)
      elseif o.type == "box" then
         draw_img(box_img, o.x - 16, o.y - 16, o.ttl)
      end
   end

   -- Draw enemies
   for i = 1, #enemies do
      draw_img(enemy_img, enemies[i].x - 16, enemies[i].y - 16, 1)
   end

   love.graphics.setColorMode("replace")
   -- Draw fired bullets
   for i = 1, #fired_bullets do
      love.graphics.draw(fired_bullet_img, fired_bullets[i].x,
                         fired_bullets[i].y, fired_bullets[i].angle + math.pi/2)
   end

   -- Draw flying items
   love.graphics.setColorMode("modulate")
   for i = 1, #flying_items do
      if flying_items[i] then
         local f = flying_items[i]
         local x = f.x * f.time + f.xo * (1 - f.time)
         local y = f.y * f.time + f.yo * (1 - f.time)
         love.graphics.setColor(255, 255, 255, f.time * 255)
         if f.type == "clock" then
            draw_img(clock_img, x - 16, y - 16, 1)
         elseif f.type == "super_clock" then
            draw_img(super_clock_img, x - 16, y - 16, 1)
         elseif f.type == "bullet" then
            draw_img(bullet_img, x - 8, y - 8, 1)
         elseif f.type == "box" then
            draw_img(box_img, x - 16, y - 16, 1)
      end
      end
   end

   -- Draw flying texts
   for i = 1, #flying_texts do
      if flying_texts[i] then
         if flying_texts[i].a < 0 then
            table.remove(flying_texts, i)
         else
            local f = flying_texts[i]
            love.graphics.setColor(f.r, f.g, f.b, 255)
            love.graphics.print(f.text, f.x, f.y, 0, f.s / 3)
         end
      end
   end
   love.graphics.setColorMode("replace")

   -- Draw player
   draw_img(player_img, pos.x - 16, pos.y - 16, 1)

   love.graphics.print("Level " .. level, 5, 2, 0)
   if game_over then
      local img
      if won == 2  then img = mega_won_img end
      if won == 1  then img = won_img end
      if won == 0  then img = timeout_img end
      if won == -1 then img = killed_img end
      love.graphics.draw(img,-50,0)
      if won ~= 2 then draw_space_to_continue() end
   end
   end

   if space_to_continue and (wait_timer == 0 or level == 0) then
      love.graphics.setColorMode("modulate")
      if level == 0 and splash > 3 then
         love.graphics.setColor(0, 0, 255)
      elseif level == 0 and splash <= 3 then
         love.graphics.setColor(255, 255, 0)
      else
         love.graphics.setColor(255, 255, 255)
      end
      local x = 450
      if level == 0 then x = 500 end
      love.graphics.draw(space_img, x, 522)
      love.graphics.setColorMode("replace")
   end

   -- Draw flying 10s
   if flying_10s
   then
      love.graphics.setColorMode("modulate")
      love.graphics.setColor(255, 255, 255, flying_10s.a)
      love.graphics.draw(flying_10s_img, flying_10s.x, flying_10s.y, 0,
                         flying_10s.s, flying_10s.s)
      love.graphics.setColorMode("replace")
   end
end

function fire()
   table.sort(enemies,
              function (a, b)
                 return dist(a, pos) < dist(b, pos)
              end)
   local angle =
      (enemies[1] and math.atan2(enemies[1].y - pos.y, enemies[1].x - pos.x)
       or math.random() * 2 * math.pi)
   local bullet = {angle = angle, x = pos.x, y = pos.y}
   function bullet:move(dt)
      self.x = self.x + dt * b_speed * math.cos(self.angle)
      self.y = self.y + dt * b_speed * math.sin(self.angle)
   end
   table.insert(fired_bullets, bullet)
   piou_snd:play()
end

function love.keypressed(key, unicode)
   if key == " " and (not space_to_continue or wait_timer == 0 or level == 0)
   then
      if level == 0 then
         if splash == 6 then
            level = 1
            init(50, 50, 600, 500, 300, 250)
         else
            splash = splash + 1
         end
         space_to_continue = false
      else
         if game_over then
            if won == 2 then
            elseif won == 1 then
               if level == #levels then
                  mega_win()
               else
                  level = level + 1
                  flying_10s = nil
                  game_over = false
                  init(50, 50, 600, 500, 300, 250)
               end
            else
               game_over = false
               init(50, 50, 600, 500, 300, 250)
            end
            space_to_continue = false
         elseif bullets and bullets >= 1 then
            bullets = bullets - 1
            fire()
         end
      end
   end
end

function love.joystickpressed()
   love.keypressed(" ")
end

function win()
   game_over = true
   won = 1
   create_flying_10s(750, 50, math.atan2(800, -600), 255, 196, 0, 3)
   victory_snd:play()
end

function mega_win()
   game_over = true
   won = 2
end

function lose_timeout()
   game_over = true
   won = 0
   timeout_snd:play()
end

function lose_killed()
   game_over = true
   won = -1
   boum_snd:play()
end