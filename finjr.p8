pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- main
right = false
flicker = true
hit = 0

tile_2x2_stonewall = 160
tile_2x2_stonebridge = 165
tile_1x2_stonewall_rim_right = 162
tile_1x2_stonewall_rim_left = 163
tile_2x1_stonewall_rim_top = 144
tile_1x1_reet_roof_left = 130
tile_1x1_reet_roof_middle = 131
tile_1x1_reet_roof_right = 132
tile_1x1_window = 128
tile_1x1_door = 146
tile_1x1_rockblock = 133
tile_1x1_rockblock_x = 40
tile_1x1_rockblock_y = 64
tile_1x1_grass_bottom_rim = 129
tile_1x1_flat_rocks = 84
tile_1x1_flat_rocks_x = 32
tile_1x1_flat_rocks_y = 40
tile_heart = 16

srnd_offset = 0

function rndint(n)
	return flr(rnd(n) + .5)
end
function _update()
	save()
	--print "yap"
end

local function rndn(n, x) 
	return flr(rnd(n)) * x
end

local active_layer = 1
local layer_calls = {{}}
local function layer(n)
	n = flr(n)
	if not layer_calls[n] then layer_calls[n] = {} end
	active_layer = n
	if (#layer_calls[n] == 0) l_pal()
end

local function copy_layers()
	local copy = {}
	for i=-8, 300 do
		local l = layer_calls[i]
		if l then
			copy[i] = {}
			for n=1,#l do 
				copy[i][n] = l[n]
			end
		end
	end
	return copy
end

local function paste_layers(copy)
	for i=-8, 300 do
		local l = copy[i]
		if l then
			if not layer_calls[i] then layer_calls[i] = {} end
			local dst = layer_calls[i]
			for n=1,#l do 
				dst[#dst+1] = l[n]
			end
		end
	end
end

local function flush_layers()
	for i=-8, 300 do
		local l = layer_calls[i]
		if l then
			for n=1,#l do 
				l[n]() 
				l[n] = nil
			end
		else
			layer_calls[i] = {}
		end
	end
	active_layer = 1
end

local function layer_call_cache(mapped_call)
	return function (...)
		local l = layer_calls[active_layer]
		local args = {...}
		l[#l+1] = function() 
			mapped_call(unpack(args))
		end
	end
end

l_sspr, l_pal = layer_call_cache(sspr), layer_call_cache(pal)
function l_spr(s,x,y,w,h,f,i) 
	local l = layer_calls[active_layer]
	l[#l+1] = function() spr(s,x,y,w or 1, h or 1, f, i) end
end

function l_call(f)
	local l = layer_calls[active_layer]
	l[#l+1] = f
end

function slice4spr(sx, sy, range, x, y)
	l_sspr(rndn(range, 8) + sx, sy, 4, 4, x, y)
	l_sspr(rndn(range, 8) + 4 + sx, sy, 4, 4, x + 4, y)
	l_sspr(rndn(range, 8) + sx, sy + 4, 4, 4, x, y + 4)
	l_sspr(rndn(range, 8) + 4 + sx, sy + 4, 4, 4, x + 4, y + 4)
end

local function idx128(x,y) return flr(x/8)*8 + flr(y/8)*8 * 128 end
local function idx_map_screen(x,y) return (x + 64) | (y + 64) << 8 end
local function rndsym(x) return rnd(x) - x*.5 end

local function path(stepsize, x1, y1, x2, y2, scatter, placecallback)
	local function halfit(x1,y1,x2,y2, n, dstart,dend)
		local dx,dy = x2 - x1, y2 - y1
		local d = (dx * dx + dy * dy) ^ .5
		n += 1
		if (d < stepsize or n > 10) return
		local nx, ny = dx / d, dy / d
	
		local r = rndsym(scatter*d)
		local x,y = (x1 + x2) / 2 - r * ny, (y1 + y2) / 2 + r * nx
		local dh = (dstart + dend) / 2
		if n == 1 then
			placecallback(x1,y1, d, 0, nx, ny)
			placecallback(x2,y2, d, 1, nx, ny)
		end
		placecallback(x,y, d, dh, nx, ny)
		halfit(x1,y1,x,y, n, dstart, dh)
		halfit(x,y,x2,y2, n, dh, dend)
	end
	halfit(x1,y1,x2,y2, 0, 0,1)
end

function write_map(x,y,col)
	x += 31
	y += 31
	local ptr = 0x2000 + y*32 + x\2
	local v = @ptr
	if x%2 == 0 then
		v = col | (v & 0xf0)
	else
		v = col << 4 | (v & 0xf)
	end
	poke(ptr,v)
	-- for x=0,31 do
	-- 	for y = 0,63 do
	-- 		memset(0x2000 + y*32 + x,rnd()*256, 1)
	-- 	end
	-- end
end

local cached_map = {
	perlin = {},
	height = {}
}

local hscale = 10
local function ishigherthanwaterlevel(h) return h > -.085 / hscale end

local function map_get_height(hx,hy)
	local s = 0.005 / hscale
	hx,hy = hx * s - .1, hy * s - .1
	local d = (hx*hx+hy*hy)
	local h1 = perlin:noise(hx, hy,2.12)
	local h2 = perlin:noise(hx * 2, hy * 2,3.42)
	local h3 = perlin:noise(hx * 4, hy * 4,4.42)
	local h4 = perlin:noise(hx * 8, hy * 8,4.22)
	local h5 = perlin:noise(hx * 16, hy * 16,6.12)
	local h6 = perlin:noise(hx * 32, hy * 32,1.72)
	return h1 * .65 + h2 * .25 + h3 * .1 - h4 * .051 + h5 * .031 - h6 * 0.022 - d * .14 +.124
end

function save()
	dset(0, 1)
	dset(1, player_x)
	dset(2, player_y)
end

function _init()
	cls()
	print "starting game"

	cartdata("zet23t_finjr_1")
	local first_start = dget(0) == 0
	if first_start then
		player_x, player_y = 64, 64
	else
		player_x, player_y = dget(1), dget(2)
	end

	print "generating landscape"
	map_heights = {}
	local river_spawns = {}
	local possible_town_points = {}
	for x=-31,32 do
		for y=-31,32 do
			dither = (x + y) & 1
			local h = map_get_height(x * 128 + 64, y * 128 + 64)
			map_heights[idx_map_screen(x,y)] = h
			local col = (ishigherthanwaterlevel(h + (dither * .2 + .1)) and 12) or 1
			if (ishigherthanwaterlevel(h)) col = (h < .25/hscale and 10 or 11)
			if (h > .228) col = h + dither * .15 > .3 and 5 or 6
			if (h > .38) col = 5

			if h > 0.02 and h < 0.2 then
				possible_town_points[#possible_town_points + 1] = {x,y}
			--	col = 7
			end
			if h > 0.05 then river_spawns[#river_spawns + 1] = {x, y} end

			write_map(x, y, col)
		end
	end
	draw_map(32,32)


	print "river flow calculations"
	map_rivers = {}
	srand(1)
	for i=1,#river_spawns / 10 do
		local x,y = unpack(rnd(river_spawns))

		local river_points = {}
		while true do
			local idx = idx_map_screen(x,y)
			local h = map_heights[idx]
			river_points[#river_points + 1] = {x * 128 + rndsym(48) + 64,y * 128 + rndsym(48) + 64}
			local nodeinfo = {points = river_points, index = #river_points}
			if map_rivers[idx] then
				if #river_points > 1 then
					local other = map_rivers[idx]
					river_points[#river_points] = other[1].points[other[1].index]
					other[#other + 1] = nodeinfo
				end
				break
			end
			if (h < -0.05) break
			map_rivers[idx] = {nodeinfo}

			local h1,h2,h3,h4 = map_heights[idx_map_screen(x-1,y)] or 10, map_heights[idx_map_screen(x+1,y)] or 10,
				map_heights[idx_map_screen(x,y-1)] or 10, map_heights[idx_map_screen] or 10

			if h1 < h2 and h1 < h3 and h1 < h4 then
				x = x - 1
			elseif h2 < h3 and h2 < h4 then
				x = x + 1
			elseif h3 < h4 then
				y = y - 1
			else
				y = y + 1
			end 
			write_map(x, y, 12)
		end
		draw_map(32,32)
	end

	print "generating towns & roads"
	road_points = {}
	map_town_list = {}
	map_towns = {}
	map_roads = {}
	for i=1,25 do
		srand(i)
		local x,y = unpack(possible_town_points[1 + flr(rnd(#possible_town_points))])
		local town = {
			center = {x,y},
			screens = {{x,y}, {x-1,y},{x+1,y}},
			buildings = {},
			streets = {},
			connected = {}
		}
		map_towns[idx_map_screen(x,y)] = town
		
		local cx,cy = 64 + rndsym(20) + x * 128, 64 + rndsym(20) + y*128
		--town.streets[#town.streets + 1] = {x1=cx - 80, y1=cy - 20, x2=cx + 80, y2=cy + 20}
		-- local h = map_get_height(cx, cy)
		-- for i=1,50 do
			
		-- end
		
		--if #town.streets > 0 then
			for p in all(town.screens) do
				map_towns[idx_map_screen(unpack(p))] = town
			end
		--end

		local cpos = @0x5f27
		for i=1,#map_town_list do
			local other = map_town_list[i]
			local path_nodes = map_search_path(x,y, unpack(other.center))
			if path_nodes then
				--cursor(0,cpos)
				--print(" from "..x..","..y.." to "..other.center[1]..","..other.center[2])
				--print("   found")
				draw_map(32,32)
				local path = {
					nodes = path_nodes,
				}
				for p in all(path_nodes) do
					write_map(p.x, p.y, 4)
					local roads = map_roads[idx_map_screen(p.x, p.y)] or {}
					add(roads, path)
					map_roads[idx_map_screen(p.x, p.y)] = roads
				end
			end
			-- break
		end
		map_town_list[#map_town_list+1] = town
	end

	for i=1,#map_town_list do
		local x,y = unpack(map_town_list[i].center)
		write_map(x, y, 8)
	end
	-- assert()
end

function prio_queue_new()
	return {lists={},min=0,max=0,count=0}
end
function prio_queue_count(queue)
	return queue.count
end
function prio_queue_dequeue(queue)
	assert(queue.lists)
	if queue.count == 0 then
		assert()
		return end
	while not queue.lists[queue.min] or #queue.lists[queue.min] == 0 do
		queue.min += 1
	end
	queue.count -= 1
	--print(#queue.lists[queue.min])
	return deli(queue.lists[queue.min])
end
function prio_queue_enqueue(queue, prio, data)
	prio = flr(prio)
	queue.count += 1
	queue.min = min(queue.min,prio)
	queue.max = max(queue.max,prio)
	local list = queue.lists[prio] or {}
	add(list, data)
	queue.lists[prio] = list
end

function map_search_path(x1,y1,x2,y2)
	local path, queue, map = {}, prio_queue_new(), {}
	prio_queue_enqueue(queue, 1, {x1,y1, nil,nil,0})
	map[idx_map_screen(x1,y1)] = {x,y}
	
	while prio_queue_count(queue) > 0 do
		local p = prio_queue_dequeue(queue)
		local x,y,fx,fy,step, estimate = unpack(p)
		assert(step)
		local idx = idx_map_screen(x,y)
		local height = map_heights[idx]

		local function enqueue(to_x,to_y, i, step)
			step += 1
			local idx = idx_map_screen(to_x,to_y)
			if map[idx] then return end
			local function cost_info(to_x, to_y, step, next_height)
				local remaining = abs(to_x - x2) + abs(to_y - y2)
				return step,abs(next_height - height) * 100 + remaining + step
			end
			local function enqueue(to_x,to_y,x,y,idx, step)
				local idx = idx_map_screen(to_x,to_y)
				if map[idx] then return end
				local next_height = map_heights[idx]
				local p = {to_x,to_y,x,y, cost_info(to_x, to_y, step, next_height)}
				map[idx] = p
				prio_queue_enqueue(queue, p[6], p)
			end
			if map_roads[idx] then
				for path in all(map_roads[idx]) do
					local nodes = path.nodes
					for i=1,#nodes do
						local p = nodes[i]
						if p.x == to_x and p.y == to_y then 
							p = {to_x, to_y, x, y, cost_info(to_x, to_y, step, map_heights[idx_map_screen(to_x, to_y)])}
							for k=i,1,-1 do
								local q = nodes[k]
								enqueue(q.x, q.y, p.x, p.y, 1, step + i - k)
								p = q
							end
							p = nodes[i]
							for k=i+1,#nodes do
								local q = nodes[k]
								enqueue(q.x, q.y, p.x, p.y, 1, step + k - i)
								p = q
							end
							return
						end
						--enqueue(p.x, p.y, 1)
					end
				end
			else
				enqueue(to_x, to_y, x, y, idx, step + 2)
			end
		end

		assert(step)
		if x >= -31 and x <= 31 and y >= -31 and y <= 31 and height > 0 then 
			if x == x2 and y == y2 then
				while fx do
					add(path,{x=x,y=y, idx=idx}, 1)
					idx = idx_map_screen(fx,fy)
					if not map[idx] then print(x1..","..y1..">"..x2..","..y2.."@"..fx..","..fy) end
					x,y,fx,fy = unpack(map[idx])
				end
				return path
			end
			enqueue(x+1,y,nil, step)
			enqueue(x-1,y,nil, step)
			enqueue(x,y+1,nil, step)
			enqueue(x,y-1,nil, step)
		end
	end
end

function draw_stone_wall(x,y, w, h, blockindex)
	layer(y + h - 8)
	for px=2,w-2,16 do
		for py=2,h,16 do
			l_spr(tile_2x2_stonewall, x + px, y + py, min(16,w-px)/8,min(16,h-py)/8)
		end
	end
	for py=0,h,16 do
		l_spr(tile_1x2_stonewall_rim_left,x-6,y + py, 1, min(16, h-py)/8)
		l_spr(tile_1x2_stonewall_rim_right,x + w-2,y + py, 1, min(16, h-py)/8)
	end
	for px=0,w,16 do
		l_spr(tile_2x1_stonewall_rim_top,x+px,y - 6, min(16,w-px)/8)
	end
	for px=0,w,8 do
		l_spr(tile_1x1_grass_bottom_rim,x + px, y + h - 8, min(8, w-px)/8)
		blockindex(x+px, y + h - 8)
	end
	--l_call(function() rect(x,y,x+w,y+h,0) end)
	--l_spr(tile_1x1_window, x+7, y + 4)
	--l_spr(tile_1x1_window, x+1, y + 4)
end

function draw_stone_house(x,y, w, h, blockindex)
	draw_stone_wall(x,y,w,h, blockindex)
	for px=7, w - 5, 8 do
		l_spr(tile_1x1_reet_roof_middle,x + px, y - 6, min(8, w-5-px)/8)
	end
	l_spr(tile_1x1_reet_roof_left, x - 1, y - 6)
	l_spr(tile_1x1_reet_roof_right, x - 5 + w, y - 6)
	local function rowsplit(x1,y1,x2,door)
		if (x2 - x1 < 6) return
		local t = rnd()*.5 + .25
		local mx = x1 * (1 - t) + x2 * t
		l_spr(door and tile_1x1_door or tile_1x1_window, mx-4, y1)
		rowsplit(x1, y1, mx - 5)
		rowsplit(mx + 5, y1, x2)
	end
	rowsplit(x+3,y + h - 8,x+w-3, true)
	rowsplit(x+6,y-5,x+w-9)
	for py=y+3,y + h - 14, 8 do
		rowsplit(x+2,py,x+w-2)
	end
end

function dot(x1,y1,x2,y2) return x1*x2+y1*y2 end

function distance( p1x, p1y, p2x, p2y)
	if not p2x then p1x,p1y,p2x,p2y = p1x.x,p1x.y,p1y.x,p1y.y end
	return ((p1x-p2x)^2 + (p1y-p2y)^2)^.5
end

function dist_segment_point( x1,y1,x2,y2, px,py, d )
	if x1 == x2 and y1 == y2 then
		return distance(x1,y1,px,py)
	end
	d = d or distance(x1,y1,x2,y2)
	local t = ((px - x1)*(x2 - x1) + (px - y1)*(y2 - y1))/(d^2)
	if t >= 0 and t <= 1 then
		local projectionx,projectiony = x1 + t*(x2-x1), y1 + t*(y2-y1)
		return distance( projectionx, projectiony, px, py ), projectionx, projectiony, true
	else
		local x,y = t < 0 and x1 or x2, t < 0 and y1 or y2
		return distance(x,y,px,py), x,y, false
	end
end

function info(str)
	layer(220)
	l_call(function() 
		print(str, 0,20,0)
	end)
end

local function prepare_map(sectionx, sectiony)
	if cached_map.sectionx == sectionx and cached_map.sectiony == sectiony and srnd_offset == cached_map.srnd_offset then
		return cached_map
	end
	cached_map.srnd_offset = srnd_offset
	cached_map.sectionx = sectionx
	cached_map.sectiony = sectiony
	local ox, oy = sectionx * 128, sectiony * 128

	for x=0,120,8 do
		for y=0,120,8 do
			local pn = perlin:noise((ox + x) *.01,(oy + y)*.01,0)
			local pnn = perlin:noise((ox + x) *.0031,(oy + y)*.0031,1.42)
			local idx = idx128(x,y)
			cached_map.perlin[idx] = pnn * .25 + pn * .75
			cached_map.height[idx] = map_get_height((ox + x),(oy + y))
		end
	end

	
	local blocked = {}
	local function blockindex(x,y) return flr(x / 16) + flr(y/16) * 256 end
	local function block(x,y) blocked[blockindex(x,y)] = true end
	local function isblocked(x,y) return blocked[blockindex(x,y)] end
	
	local function connection(d, hcut, hoffset, x1,y1,x2,y2, ondraw)
		srand(x1-x2+y1-y2+srnd_offset)
		path(d,x1,y1,x2,y2,.5, function(x,y,d,p, nx, ny)
			local idx = idx128(x,y)
			local h = cached_map.height[idx]
			if not h or h < hcut or not ishigherthanwaterlevel(h + hoffset) then return end
			
			-- if d > 8 then
			-- 	l_spr(83 + rnd(3), x, y - 6, .5, .5)
			-- 	layer(5)
			-- end
			ondraw(x,y,d, p,nx, ny,h)
			block(x,y)
		end)
	end

	function average_line(points)
		assert(#points >= 2)
			
		local maxd,maxp,maxq = 0
		for i=1,#points-1 do
			local p = points[i]
			for j=1,#points do
				local q = points[j]
				local d = distance(p,q)
				if d > maxd then
					maxd,maxp,maxq = d,p,q
				end
			end
		end
		local dx,dy = maxp.x - maxq.x, maxp.y - maxq.y
		-- info(maxp == maxq)
		-- info(maxp.x..","..maxp.y.."  "..maxq.x..","..maxp.y)
		-- l_call(function()line(maxp.x,maxp.y,maxq.x,maxq.y,10)end)
		dx /= maxd
		dy /= maxd
		return (maxp.x + maxq.x) / 2, (maxp.y + maxq.y) / 2, dx, dy
		-- local n,sumx,sumy,sumx2,sumxy, m,x,y,dx,dy = #points,0,0,0,0
		-- for p in all(points) do
		-- 	sumx += p.x
		-- 	sumy += p.y
		-- end
		-- local cx, cy = sumx / n, sumy / n

		-- for p in all(points) do
		-- 	x,y = p.x,p.y
		-- 	-- x,y = x - cx, y - cy
		-- 	-- sumx,sumy,sumx2,sumxy += x, y, x*x, x*y
		-- 	sumx += x
		-- 	sumy += y
		-- 	sumxy += x*y
		-- 	sumx2 += x*x
		-- end
		-- local div = (n * sumx2 - sumx * sumx)
		
		
		-- if div == 0 then
		-- 	dx, dy = 0, 1
		-- else
		-- 	m = (n * sumxy - sumx * sumy) / div
		-- 	dx, dy = 1, m
		-- end
		-- layer(200)
		-- 	l_call(function() 
		-- 		-- for p in all(nearby) do 
		-- 		-- 	pset(p.x,p.y,9)
		-- 		-- end
		-- 		print(sumx2.." - "..m.." "..dx.." "..dy,1,21,0)
				
		-- 	end)
		-- m = (dx * dx + dy*dy)^.5
		-- return cx,cy,dx / m, dy / m
	end

	local river_points = {}
	local function river(x1,y1,x2,y2,rp)
		layer(3)
		l_pal(5,10)
		layer(4)
		l_pal(4,1)
		connection(4.5, -.1, 0.008, x1,y1,x2,y2, function(x,y, d, p, nx, ny, h)
			river_points[#river_points + 1]= {x=x,y=y,nx=nx,ny=ny, p=p}
			local n = 90 + rnd(2)
			--l_call(function()rectfill(x-4,y-4,x+4,y+4,12)end)
			layer(3)
			l_pal(4,rnd() > .5 and 5 or 9)
			if rnd()> .17 then
				local rspr = 70 + (rnd() > .5 and 0 or 16)
				l_spr(rspr, x + rndsym(10), y + rndsym(10),1,1, fx, fy)
			end
			if (h > 0) l_spr(n, x-3, y-4.6)
			layer(4)
			l_spr(n, x-3, y-3)
			layer(5)
			l_call(function() 
				srand(x+y)
				for i=1,4 do
					local s = 10-(- time() * (3+ (p+rp)*6) + rnd()*20)%(10 + rnd(6))
					if s <= 1 then
						local x,y = x + rndsym(4), y + rndsym(4)
						pset(x + nx * s,y + ny * s,(rnd() - time()*4)%1 < 0.5 and 7 or 12) 
						if (rnd() > .5) pset(x + nx * (s-1),y + ny * (s-1), 12) 
					end
				end
			end)
			if rnd() > .9 then
				l_sspr(tile_1x1_flat_rocks_x + rndint(1) * 4, tile_1x1_flat_rocks_y + rndint(1) * 4, 4, 4, x - 3 + rndsym(2), y - 3 + rndsym(2))
			end
		end)
	end

	local function bridge(x1,y1,x2,y2)
		local px, py = (x1+x2) * .5, (y1+y2) * .5
		l_call(function() 
			line(px,py, x1,y1,9)
			line(px,py, x2,y2,9)
			pset(px,py,8)
		end)
		if (y1 < y2) x1,y1,x2,y2 = x2,y2,x1,y1
		
		path(2.75,x1,y1,x2,y2,0, function(x,y, d, p, nx, ny)
			local ox, oy = -ny, nx
			if oy < 0 then ox, oy = -ox, -oy end
			-- l_call(function() 
			-- 	line(x,y, x+ox*5,y+oy*5,9)
			-- end)
			local px,py = x,y + sin(p*.5)*5 - 4
			layer(5)
			if d > 4 then
				l_spr(0,x,y+2)
			end
			for l=-6,6,2 do
				if l == -6 or l > -1 then
					local src_offset = l>-5 and l < 5 and 4 or 0
					local y = py+oy*l
					layer(flr(y-4 -src_offset))
					l_sspr(tile_1x1_rockblock_x + src_offset, tile_1x1_rockblock_y, 4, 
						(l < 6 and 6 or (7-cos(p))) - src_offset*.5 + rnd(3), px+ox*l+rnd(1.5), y)
				end
			end
		end)
	end
	
	local function road(x1,y1,x2,y2,split)
		local rd = distance(x1,y1,x2,y2)
		local nearby = {}
		for p in all(river_points) do
			local dist,px,py, cross = dist_segment_point(x1,y1,x2,y2, p.x, p.y, rd)
			if dist < 14 then
				layer(200)
				-- l_call(function() 
				-- 	line(p.x, p.y, p.x + p.nx*8, p.y + p.ny * 8, 9)
				-- 	pset(p.x,p.y,8)
				-- end)
				nearby[#nearby + 1] = p
			end
		end

		split = (split or 0)
		if #nearby > 1 and split < 1 then
			local px,py,nx,ny = average_line(nearby)
			nx, ny = -ny, nx
			split += 1
			if (dot(nx,ny, x2-x1,y2-y1) < 0) nx, ny = -nx, -ny
			-- layer(200)
			-- l_call(function() 
			-- 	for p in all(nearby) do 
			-- 		rectfill(p.x-1,p.y-1,p.x+1,p.y+1,9)
			-- 	end
			-- 	-- print(px.." "..py.." "..nx.." "..ny,0,20,0)
			-- 	line(px,py, px+nx*24,py+ny*24,0)
			-- 	line(px+ny*24,py-nx*24, px-ny*24,py+nx*24,7)
			-- 	pset(px,py,8)
			-- 	--line(x1,y1,x2,y2,7) 
			-- 	line(x1, y1, px - nx * 12, py - ny * 12, 10)
			-- 	line(px + nx * 12, py + ny * 12, x2, y2, 10)
			-- end)
			--if true then return end
			road(x1, y1, px - nx * 30, py - ny * 30, split)
			road(px - nx * 13, py - ny * 13, px - nx * 30, py - ny * 30, split)
			bridge(px - nx * 13, py - ny * 13, px + nx * 13, py + ny * 13)
			road(px + nx * 13, py + ny * 13, px + nx * 30, py + ny * 30, split)
			road(px + nx * 30, py + ny * 30, x2, y2, split)
			return
		end
		layer(3)
		l_pal(4,5)
		l_pal(5,10)
		layer(4)
		l_pal()
		connection(5, 0, 0,x1,y1,x2,y2, function(x,y)
			local n = 90 + rnd(2)
			layer(3)
			if rnd()> .17 then
				local rspr = 70 + (rnd() > .5 and 0 or 16)
				l_spr(rspr, x + rndsym(10), y + rndsym(10),1,1, fx, fy)
			end
			l_spr(n, x-2, y-3)
			layer(4)
			l_spr(n, x-2, y-2)
			layer(5)
			if rnd() > .9 then
				l_sspr(tile_1x1_flat_rocks_x + rndint(1) * 4, tile_1x1_flat_rocks_y + rndint(1) * 4, 4, 4, x - 3 + rndsym(2), y - 3 + rndsym(2))
			end
		end)
	end

	srand(sectionx + sectiony * 10 + srnd_offset)

	local rivers = map_rivers[idx_map_screen(sectionx, sectiony)]
	if rivers then
		for info in all(rivers) do
			local x1,y1 = unpack(info.points[info.index])
			x1 -= ox
			y1 -= oy
			local rp = info.index / #info.points
			if info.index > 1 then
				local x2, y2 = unpack(info.points[info.index - 1]) 
				x2 -= ox
				y2 -= oy
				river(x2,y2, x1, y1, rp)
			end
			if info.index < #info.points then
				local x2, y2 = unpack(info.points[info.index + 1]) 
				x2 -= ox
				y2 -= oy
				river(x1,y1, x2, y2, rp)
			end
		end
	end

	local town = map_towns[idx_map_screen(sectionx, sectiony)]
	if town then
		layer(200)
		l_call(function()print("town")end)

		for street in all(town.streets) do
			srand(sectionx + sectiony * 10)
			-- l_call(function()print("street "..flr(street.x1 - ox)..";" ..flr(street.y1 - oy)..";"..flr(street.x2-ox)..";"..flr(street.y2-oy),10,10)end)
			road(street.x1 - ox, street.y1 - oy, street.x2 - ox, street.y2 - oy)
		end
		-- road(46,49,80,50)
		draw_stone_wall(-5,30,16 + rnd(10),10+rnd(10), block)
	-- draw_stone_wall(50,25,36 + rnd(10),20+rnd(10), block)
		-- draw_stone_house(20,80,16 + rnd(10),10 + rnd(10), block)
		-- draw_stone_house(60,85,36 + rnd(10),10 + rnd(10), block)
	end


	-- road network outdated
	-- local cx,cy = 64 +rndsym(48), 64 + rndsym(48)
	-- srand(sectionx * 4 + (sectiony - .5) * 10)
	-- if rnd() > .05 then
	-- 	road(cx,cy + 5,rndsym(30)+60,-8)
	-- end
	-- srand(sectionx * 4 + (sectiony + .5) * 10)
	-- if rnd() > .05 then
	-- 	road(cx,cy - 5,rndsym(30)+60,128)
	-- end
	-- srand((sectionx-.5) * 4 + sectiony * 10)
	-- if rnd() > .05 then
	-- 	road(cx + 5,cy,-8, rndsym(30)+60)
	-- end
	-- srand((sectionx+.5) * 4 + sectiony * 10)
	-- if rnd() > .05 then
	-- 	road(cx - 5,cy,128, rndsym(30)+60)
	-- end

	srand(sectionx + sectiony * 10)
	local roads = {}
	local rims = {}
	local function add_rim(x,y)
		local idx = x + y*256
		rims[idx] = (rims[idx] or 0) + 1
	end
	local function rim_sprite(x,y)
		l_pal(5, 9 + rnd(2))
		l_spr(70 + rnd(2.1), x - 2 + rndsym(2), y - 2 + rndsym(2), .5, .5)
	end
	local function draw_rims()
		layer(0)
		l_pal()
		for idx, c in pairs(rims) do
			if c == 1 then
				local x = idx % 256
				local y = idx \ 256
				if x % 8 == 4 then
					if (y > 0 and y < 128) path(2, x-4, y, x+4, y, .35,rim_sprite)
				else
					if (x > 0 and x < 128) path(2, x, y-4, x, y+4, .35,rim_sprite)
				end
			end
		end
	end

	local sea_count = 0	
	for x=0,120,8 do
		for y=0,120,8 do
			local idx = idx128(x,y)
			local pn = cached_map.perlin[idx]
			local h = cached_map.height[idx]
			--print(flr((h*5 + 5)%1*10),x,y)
			layer(-1)
			
			if h < 0 then
				sea_count += 1
				if ishigherthanwaterlevel(h) then
				-- sand
					l_pal(3, 9)
					l_pal(11, 10)
					l_spr(64 + rnd(3), x, y)
					add_rim(x+4,y)
					add_rim(x+4,y+8)
					add_rim(x,y+4)
					add_rim(x+8,y+4)
					-- for i=1,2 do
					-- 	l_spr(70 + rnd(3.1), x - 2, y + rnd(10) - 2, .5, .5)
					-- 	l_spr(70 + rnd(3.1), x + 6, y + rnd(10) - 2, .5, .5)
					-- 	l_spr(70 + rnd(3.1), x + rnd(10) - 2, y - 2, .5, .5)
					-- 	l_spr(70 + rnd(3.1), x + rnd(10) - 2, y + 6, .5, .5)
					-- end
				else
					local rand = rnd(4)
					l_call(function()
						-- layer(-1)
						if h > -.12 / hscale then
							pal(12, 7)
						end
						-- waves
						if (sin(x*.001 + y*.001 + h*12 + pn - time() * .25) * cos(h*10 + time()*-.12 + x*.009 + y*.0027) > 0) then
							pal(12, 1)
						end
						spr(76 + (rand + time() * 4)%4, x, y)
						pal()
					end)
				end
				l_pal()
			else
				if rnd()<.2 then l_pal(3,10)
				elseif rnd()<.2 then l_pal(3,8) 
				elseif rnd()<.1 then l_pal(3,12) end
				l_spr(64 + rnd(3), x, y)
				l_pal()
				
				if abs(pn) * 4 > rnd() then
					local rspr = 70 + abs(pn) * 4 + (rnd() > .5 and 0 or 16)
					local fx, fy = rnd()>.5, rnd()>.5
					if pn < 0 then
						-- rocky ground
						l_pal(5,3)
						l_spr(rspr, x, y,1,1, fx, fy)
					else
						--l_pal(5,6)
						l_spr(rspr, x, y,1,1, fx, fy)
					end
				end
				
				local spx, spy = x + rnd(4), y + rnd(4)
				if not isblocked(spx, spy) then
					layer(spy)
					if rnd() < pn - .25 then
						--rocks
						slice4spr(24,32,3, spx,spy)
					elseif rnd() > 0.8 and pn < 0 and pn > -.15 then
						-- trees
						if rnd() > .7 then
							l_spr(97, spx, spy)
							l_spr(99, spx, spy - 4)
						else
							l_spr(115, spx, spy)
							if rnd() > .23 then
								l_spr(101, spx, spy - 8, 1, 2)
							else
								l_spr(105, spx-4, spy - 8, 2, 2)
							end
						end
						--[[l_spr(99, spx + rndsym(2), spy - 4+rndsym(2))
						if rnd() > .5 then
							l_spr(99, spx + rndsym(2), spy - 8+rndsym(2))
							l_spr(100, spx + rndsym(4), spy - 4+rndsym(2), .5, .5)
						end
						if rnd() > .5 then
							l_spr(100, spx + rndsym(4)-2, spy - 4+rndsym(2), .5, .5)
						end]]
						--slice4spr(0, 48, 3, spx, spy)
					elseif rnd() > pn + .8 then
					-- dead trees
						--slice4spr(0, 40, 3, spx, spy)
					end
				end
				layer(1)
			end
		end
	end
	draw_rims()
	cached_map.sea_count = sea_count
	cached_map.layer_copy = copy_layers()
	
	return cached_map
end

function playfoot()
	if (stat(16) == -1) sfx(5, 0, flr(rnd(3))*2,2)
end

sfx(4, 1)

function print_centered(t, x, y, c)
	print(t, x - #t * 2, y, c)
end

function draw_map(px,py)
	for y=0,63 do
		memcpy(0x6000 + flr(px/2) + flr(py + y)*128/2, 0x2000 + y * 32, 64/2)
	end
end

function menu_mode_map()
	return function()
		draw_map(32, 32)
		camera(-(sectionx + 32) - 31, -(sectiony + 32) - 31)
		line(-3,-3,-1,-1,7)
		line(3,3,1,1,7)
		line(3,-3,1,-1,7)
		line(-3,3,-1,1,7)
		camera()

		if (btnp(0)) player_x -= 128
		if (btnp(1)) player_x += 128
		if (btnp(2)) player_y -= 128
		if (btnp(3)) player_y += 128
	end
end

function menu_mode_main()
	local active = 1
	return function()
		local m = 1
		local function menu_item(t, f)
			print_centered(t, 64, 32 + m * 8,active == m and 10 or 9)
			if active == m and btnp(1) and f then
				menu_mode = f() or menu_mode
			end
			m += 1
			return menu_item
		end
		
		menu_item("mode: < interact >", nil) ("open inventory >", nil) ("open map >", menu_mode_map)
		if (btnp(3)) active = active % 3 + 1
		if (btnp(2)) active = (active+1) % 3 + 1
	end
end

function _draw()
	flicker = not flicker
	cls()
	
	sectionx = player_x \ 128
	sectiony = player_y \ 128
	local cached_map = prepare_map(sectionx, sectiony)
	local ox, oy = sectionx * 128, sectiony * 128
	paste_layers(cached_map.layer_copy)

	srand(time())
	if cached_map.sea_count == 0 then
		sfx(4, -2)
		if rnd(9.4) > 9 then
			sfx(6, 1, rnd(6), 1)
		end
	else
		sfx(4, 1)
	end

	--camera(-sectionx * 128, -sectiony * 128)
	
	if hit > 0 then
		hit = hit + 1
		if hit == 5 then hit = 0 end
	end

	local speed = btn(5) and 128 or 1
	local ampl = 0

	if not menu_mode then
		if (btn(0)) player_x -= speed right = false ampl = 2 playfoot()
		if (btn(1)) player_x += speed right = true ampl = 2 playfoot()
		if (btn(2)) player_y -= speed ampl = 2 playfoot()
		if (btn(3)) player_y += speed ampl = 2 playfoot()
		if (btnp(4)) hit = 1 sfx(3) --srnd_offset+=1
	end
	
--	layer(2)
	local ppyg = player_y - sectiony * 128
	layer(ppyg)
	local ppx = player_x - sectionx * 128
	local ppy = flr(ppyg - ampl * (abs(sin(time() * 4)) - .5 ))
	l_spr(0, ppx, ppyg + 4)
	l_spr(1, ppx, ppy, 1, 1, right)
	local weapon_spr, weapon_x, weapon_y = flr(208 - sin(hit / 10) * 2.9),ppx + (right and 3 or -3), ppy
	l_spr(weapon_spr,weapon_x,weapon_y, 1, 1, right)
	
	flush_layers()
	function spr_n_to_xy(n)
		return n%16*8,n\16*8
	end
	function draw_hidden_spr(spr, ppx, ppy, flip_x)
		spr,ppx,ppy = flr(spr),flr(ppx),flr(ppy)
		local sx,sy = spr_n_to_xy(spr)
		for x=ppx,ppx+7 do
			for y=ppy,ppy+7 do
				local sc = sget(flip_x and (sx+7-(x-ppx)) or (x-ppx+sx),y-ppy+sy)
				if sc~=0 and pget(x,y) ~= sc then
					pset(x,y,1)
					--spr(1, ppx, ppy, 1, 1, right)
				end
			end
		end
	end
	draw_hidden_spr(1,ppx,ppy,right)
	draw_hidden_spr(weapon_spr,weapon_x,weapon_y,right)

	pal()
	hearts = 4
	local x2 = hearts * 9
	rectfill(0,0,x2-1,8,0)
	line(x2,0,x2,7,0)
	line(x2+1,0,x2+1,5,0)
	for i=0,3 do
		spr(tile_heart,i * 9,0)
	end

	if btnp(5) or menu_mode then
		rect(25,25,104,104,1)
		rectfill(24,24,103,103,4)
		line(25,24,25,103,10)
		line(102,24,102,103,10)
		if not menu_mode then
			menu_mode = menu_mode_main()
			menu_mode()
		elseif btnp(5) then
			menu_mode = nil
		else
			menu_mode()
		end
		--map(0,0,32,32,)
	else
		menu_mode = nil
	end

--	map(0,0,0,0,128/8,128/8)

	rectfill(0,120,128,128,4)
	--print(stat(1),5,122,0)
	print(sectionx.." "..sectiony.." - "..stat(1).." - "..stat(0),2,122,0)
end

-->8
-- perlin

perlin = {}
perlin.p = {}

-- hash lookup table as defined by ken perlin
-- this is a randomly arranged array of all numbers from 0-255 inclusive
local permutation = {151,160,137,91,90,15,
  131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
  190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
  88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
  77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
  102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
  135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
  5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
  223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
  129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
  251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
  49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
  138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
}

-- p is used to hash unit cube coordinates to [0, 255]
for i=0,255 do
	-- convert to 0 based index table
	perlin.p[i] = permutation[i+1]
	-- repeat the array to avoid buffer overflow in hash function
	perlin.p[i+256] = permutation[i+1]
end

-- return range: [-1, 1]
function perlin:noise(x, y, z)
	y = y or 0
	z = z or 0

	-- calculate the "unit cube" that the point asked will be located in
	local xi = band(flr(x),255)
	local yi = band(flr(y),255)
	local zi = band(flr(z),255)

	-- next we calculate the location (from 0 to 1) in that cube
	x = x - flr(x)
	y = y - flr(y)
	z = z - flr(z)

	-- we also fade the location to smooth the result
	local u = self.fade(x)
	local v = self.fade(y)
	local w = self.fade(z)

	-- hash all 8 unit cube coordinates surrounding input coordinate
	local p = self.p
	local a, aa, ab, aaa, aba, aab, abb, b, ba, bb, baa, bba, bab, bbb
	a   = p[xi  ] + yi
	aa  = p[a   ] + zi
	ab  = p[a+1 ] + zi
	aaa = p[ aa ]
	aba = p[ ab ]
	aab = p[ aa+1 ]
	abb = p[ ab+1 ]

	b   = p[xi+1] + yi
	ba  = p[b   ] + zi
	bb  = p[b+1 ] + zi
	baa = p[ ba ]
	bba = p[ bb ]
	bab = p[ ba+1 ]
	bbb = p[ bb+1 ]

	-- take the weighted average between all 8 unit cube coordinates
	return self.lerp(w,
		self.lerp(v,
			self.lerp(u,
				self:grad(aaa,x,y,z),
				self:grad(baa,x-1,y,z)
			),
			self.lerp(u,
				self:grad(aba,x,y-1,z),
				self:grad(bba,x-1,y-1,z)
			)
		),
		self.lerp(v,
			self.lerp(u,
				self:grad(aab,x,y,z-1), self:grad(bab,x-1,y,z-1)
			),
			self.lerp(u,
				self:grad(abb,x,y-1,z-1), self:grad(bbb,x-1,y-1,z-1)
			)
		)
	)
end

-- gradient function finds dot product between pseudorandom gradient vector
-- and the vector from input coordinate to a unit cube vertex
perlin.dot_product = {
	[0x0]=function(x,y,z) return  x + y end,
	[0x1]=function(x,y,z) return -x + y end,
	[0x2]=function(x,y,z) return  x - y end,
	[0x3]=function(x,y,z) return -x - y end,
	[0x4]=function(x,y,z) return  x + z end,
	[0x5]=function(x,y,z) return -x + z end,
	[0x6]=function(x,y,z) return  x - z end,
	[0x7]=function(x,y,z) return -x - z end,
	[0x8]=function(x,y,z) return  y + z end,
	[0x9]=function(x,y,z) return -y + z end,
	[0xa]=function(x,y,z) return  y - z end,
	[0xb]=function(x,y,z) return -y - z end,
	[0xc]=function(x,y,z) return  y + x end,
	[0xd]=function(x,y,z) return -y + z end,
	[0xe]=function(x,y,z) return  y - x end,
	[0xf]=function(x,y,z) return -y - z end
}
function perlin:grad(hash, x, y, z)
	return self.dot_product[band(hash,0xf)](x,y,z)
end

-- fade function is used to smooth final output
function perlin.fade(t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

function perlin.lerp(t, a, b)
	return a + t * (b - a)
end
__gfx__
00000000000000000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000009999000100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010100000ff9000010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00101010000999000010001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010100004444000100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00101000004444000100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000f44f000100001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000cc0000010010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000dd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07200720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e882e882000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e8888882000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888820000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00082000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000500005005005050550555004440444000044400444404441111cc11111111111111cc1111111111
bbbbbbbbbbbbbbbbbbbbbbbb000000000006000000006600000505005055055050050555044444440404444044000044c111111c11111cc11111111111111cc1
b3bbbbbbbbbbbb3bbbbbbbbb00066600006656500066656050500000055050050055050544444040044444404000000411111111cc111111111111cc11111111
bbbbbbbbb3bbbbbbbbbbbbbb0066655006655511066655500000505000050550505055554400444444444444000000001cc11111111111111cc11111c111111c
bbbbbbbbbbbbbbbbbbbbbbbb06665510066655510666555005000005505050005555505540444440444440404000000411111cc111cc11111111111111cc1111
bbbbbbbbbbbbbbbbbbbbbbbb06555110065551110665511100050500050005050505050544440404040444400040000411111111111111cc111cc11111111111
bbbb3bbbbbbbbbbbbbbbbbbb00551100055511000005110050005050005505005055505000444044004444004400004411cc111111111111c111111c1111cc11
bbbbbbbbbbbbbbbbbbbbbbbb00000000005000000000000000050000550050055055005544044044000404004440044011111111111cc11111111111cc111111
000b0b000000000000b0400000000000066000000000000000005000050050500550505000000000000040000004000000000000000000000000000000000000
0b0bb33000a0ba30033443b006000660566600660000000005000005500505005005050500000000044440000444440400000000000000000000000000000000
bb33b3bb0aa0b0bb44340b4b65100510056500650000000000000000005000050050005000444400044444400444444400000000000000000000000000000000
33b0b3330ab0ba30bb44044b00000000000000000000000000000500000500000050500004444000044444440444444400000000000000000000000000000000
03bbb3b000bbb3000bb4440000000000000000000000000000000000050000500500055500044400444444404444444000000000000000000000000000000000
3b3b313000bb3bb00014430300006650066066500000000000050050000500005055505000444400044444404444444400000000000000000000000000000000
03b33b1000b45b000004303065006510065056650000000000000000500055000005000500040000004444000444444000000000000000000000000000000000
00144100000450000004400000000000000005550000000050000000005000055050050000000000000040000040440000000000000000000000000000000000
008040000000400000004000001b10000b3000b0000000000000000000000000000000000000001b110000000000000000000000000000000000000000000000
099440e0000440000a04400001aaab10bab30ba10001310000000000000000000000000000001baba10000000000000000000000000000000000000000000000
4494494e4404404045b5034013bab3313b110310001bb3100000000000000000000000000001baaaab0310000000000000000000000000000000000000000000
994404490044044003440450133333b10110000000ba3b100000000000000000000000000003abaaabb110000000000000000000000000000000000000000000
0e94440000444400000444301ab33b110000000001ba1b100000000000000000000000000000b1bbbb1bb0000000000000000000000000000000000000000000
001043030004400000044300311333330bb000b31bb1bb2100000000000000000000000001101b11111b00100000000000000000000000000000000000000000
000440300044500000440000133bb311bb130b103121b2130000000000000000000000000133b13333330bb10000000000000000000000000000000000000000
00045500000455000044400001111110011000001333333b00000000000000000000000011b311bbbb33bbd30000000000000000000000000000000000000000
00000000000000000000000000400000000000001bb33bb2000000000000000000000000b1bb3311133bb1310000000000000000000000000000000000000000
00000000044000000000044000440044000000003123bb100000000000000000000000003d1b3333333113310000000000000000000000000000000000000000
0000000044500000044044004444445000000000033312330000000000000000000000001131bbbbbb3313110000000000000000000000000000000000000000
00000000550000004444450000544520000000001bbb313100000000000000000000000001133111133131100000000000000000000000000000000000000000
00000000000000005554444000045200000000000123132000000000000000000000000000111133331311000000000000000000000000000000000000000000
00000000000000000005544000445200000000000331311000000000000000000000000000011111111110000000000000000000000000000000000000000000
00000000000000000000055004444520000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000524500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0055550000000000000000999a499a999a0000000dd0044000000000000000000000000000000000000000000000000000000000000000000000000000000000
05521dd0000000000000a99999999a9a99900000766d424200000000000000000000000000000000000000000000000000000000000000000000000000000000
0521216000000000000a49994a99999999a49000766d942400000000000000000000000000000000000000000000000000000000000000000000000000000000
0512126050000000049999999a4a499494994400d77d299200000000000000000000000000000000000000000000000000000000000000000000000000000000
05444460005000054a94a9499a4949499a4999405dd5212100000000000000000000000000000000000000000000000000000000000000000000000000000000
099999900b010010a94a94a949499a9499a499445555122200000000000000000000000000000000000000000000000000000000000000000000000000000000
004004001b01b00b44994a9949994a49999444445555221200000000000000000000000000000000000000000000000000000000000000000000000000000000
000000003b1b113b4444444444444444444444225555212200000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005511115600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005122221600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00770007770000005244442600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
076660766660007d5244499600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d66dddd66dd776d5242422600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55d6d555dd55d66d5244444500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
765d577557775dd51222222100000000440044400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66d5766d55766d5766d5000000000067444449440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66d5d6d775dd6d5766d50000000000672494494900000d5775700000000000000000000000000000000000000000000000000000000000000000000000000000
6d555d576d55dd566d55000000000066249444490055d576d5676500000000000000000000000000000000000000000000000000000000000000000000000000
d57765d6d56d5555d57750000000005544444449557765d55d5d5755000000000000000000000000000000000000000000000000000000000000000000000000
57666d5d566d577d576650000000077d44494449d76d52222225d666000000000000000000000000000000000000000000000000000000000000000000000000
5dd66d555dd5766d5dd500000000066d444924445d2229444242226d000000000000000000000000000000000000000000000000000000000000000000000000
555dd7765555d6d555550000000006d5494924442244949444242422000000000000000000000000000000000000000000000000000000000000000000000000
76d55766d5775d5576d0000000000d55494449444449494444424244000000000000000000000000000000000000000000000000000000000000000000000000
6d5765dd576665576d50000000000067042000004444949444242424000000000000000000000000000000000000000000000000000000000000000000000000
dd566d577566dd5ddd5000000000006649a2000044494d5775744244000000000000000000000000000000000000000000000000000000000000000000000000
5d55d576d5dd55555d5500000000005d4a9200004455d576d5676524000000000000000000000000000000000000000000000000000000000000000000000000
557775d6dd555776557750000000007694420000557765d55d5d5755000000000000000000000000000000000000000000000000000000000000000000000000
d766665d57d57666d76650000000066644220000d76d50000005d666000000000000000000000000000000000000000000000000000000000000000000000000
5dd66dd776d5d66d5dd650000000066d944200005dd5000000005d6d000000000000000000000000000000000000000000000000000000000000000000000000
555dd55d66d55d6d5555000000000d6d442200006550000000000d6d000000000000000000000000000000000000000000000000000000000000000000000000
77557775dd5765d577550000000000d5944200006d500000000005d5000000000000000000000000000000000000000000000000000000000000000000000000
00000000044554400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000041111400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00999900041aa1400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0944442004a999400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01166110011111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09455420044114400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09444420044444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111110044444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006500500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006500650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006500065090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00099990006900000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000a900009a900066669aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000a9000000a9005555999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8283838385000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a0a0a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000e00000244502405024451b405024450440522405024050244502405024050040502445024050244502405024451d4051340511405024450a40500405004050244500405024450040502445004050040500405
001600002715027150291502b15027150291502b15027150291502b1502e150291502b1502b1502e1502b1502e1502e1502e1502e150301502915029150291502b1502b1502e1502e1502e150301503315033150
01160000033220332203322033220532205322053220332207322073220732207322073220732207322073220732207322073220732207322073220732205322053220532205322073220a3220a3220a3220a322
000100000020127451234511c45117451134510e4510a4510e451182111040112401154011a401204012240100201002010020100201002010020100201002010020100201002010020100201002010020100201
00140020086210962109621096310a6310a6210a6110a6110961108611086110861108621096210a6210a631096310962109631096310a631096210862108611096110a6110a6210b6210b6210b6310b6210a621
010a00000c6440c6450e6340e63508624076250060400604006040060400604006040060400604006040060400604006040060400604006040060400604006040060400604000000000000000000000000000000
000a00003e1133f1233d5333e5133f523005030050300503005030050300503005030050300503005030050300503005030050300000000000000000000000000000000000000000000000000000000000000000
011b00202b6172c6173261731617326172a617296172e61734617366172c6172d617356173261732617296172b617336172d617316172d6172f6172d6172c61725617286172a6172c6172d6172c6172a6172c617
__music__
07 01024344
01 01024344
02 02424344

