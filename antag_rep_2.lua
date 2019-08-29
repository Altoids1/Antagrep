math.randomseed(os.time())
--[[
Antag Rep Simulation Tool
Does some analysis on how often people get antag, given a particular setup of gamemodes and antag reps and all that
--]]

--Configuration options
local def_rep = 100 -- How many tickets you get no matter what
local max_used_rep = 100 -- How much of your bonus pool you can use at once
local max_rep = 200 -- the maximum amount of tickets you can have in your pool
local round_rep = 0 -- the amount of tickets gained per round

local num_player_pool = 160 -- Number of active players in the community
local lowpop = 20 -- Amount of players at the dead of night
local highpop = 80 -- Amount of players at highest tide
local player_halflife = 0.34 -- What % of players leave per round

local low_round_time = 40 -- Lowest amount of time a round can take
local high_round_time = 115 -- Highest amount of time a round can take

local max_rounds = 1000 -- Number of rounds to simulate

--Globals
local player_pool = {}; -- How many tickets these players have at the moment
local player_antag_count = {};-- How many times these players got antag
local player_rounds_played = {};  -- Holds on what round the player was last antag, for the below
local player_wait_sum = 0  -- Holds how many total rounds the player waited before getting antag
local seat_sum = 0 -- Holds how many total antag positions were given out over the course of this
local player_playing = {};
local time = 0 -- Minutes past the start, used to determine serverpop
function init_globals()
	player_pool = {}; for i=1,num_player_pool do player_pool[i] = 0 end
	player_antag_count = {}; for i=1,num_player_pool do player_antag_count[i] = 0 end 
	player_rounds_played = {};for i=1,num_player_pool do player_rounds_played[i] = 0 end
	player_wait_sum = 0
	seat_sum = 0
	player_playing = {}; for i=1,lowpop do player_playing[i] = true end
	time = 0
end
init_globals()
local gamemodes = {
	{
		name = "traitor",
		req = 0,
		min_seats = 1,
		max_seats = 4,
		coeff = 6,
		prob = 6
	},
	{
		name = "traitor+bro",
		req = 8,
		min_seats = 2,
		max_seats = 4,
		coeff = 6,
		prob = 6
	},
	{
		name = "traitor+chan",
		req = 25,
		min_seats = 1,
		max_seats = 3,
		coeff = 6,
		prob = 6
	},
	{
		name = "changeling",
		req = 15,
		min_seats = 1,
		max_seats = 4,
		prob = 3
	},
	{
		name = "iaa",
		req = 25,
		min_seats = 5,
		max_seats = 8,
		prob = 6
	},
	
	{
		name = "revolution",
		req = 30,
		min_seats = 2,
		max_seats = 3,
		prob = 6
	},
	{
		name = "cult",
		req = 29,
		min_seats = 4,
		max_seats = 4,
		prob = 9
	},
	
	{
		name = "wizard",
		req = 20,
		min_seats = 1,
		max_seats = 1,
		prob = 7
	},
	{
		name = "nukeops",
		req = 30,
		min_seats = 5,
		max_seats = 8,
		prob = 9
	}
}
--Functions
function getnewpop()
	local a,c,x,pi = highpop,lowpop,time,math.pi
	return math.floor((a-c)/2 * math.cos(x/1440 * 2*pi + pi) + (a-c)/2 +c ) -- https://www.desmos.com/calculator/tdri65g084
end
function copy(arr) -- Copies a table shallowly
	t = {}
	for i=1,#arr do
		t[i] = arr[i]
	end
	return t
end
function pick(arr)
	return arr[math.random(1,#arr)]
end
function pick_weights(arr) -- Key is what to return, value is raffle tickets
	local sum = 0
	for guy,tickets in pairs(arr) do
		sum = sum + tickets
	end
	for guy,tickets in pairs(arr) do
		local ticket = math.random(1,sum)
		if ticket <= tickets then
			return guy
		end
		sum = sum - tickets
	end
end
function debug_testpickweights()
	local arr = {200,100,100}
	local arr2 = {0,0,0}
	for i=1,10000 do
		local index = pick_weights(arr)
		arr2[index] = arr2[index] + 1
	end
	for k,v in pairs(arr2) do print(k,v) end
end

local archive = {}
local archive2 = {}
local archive3 = {}
local maxbouts = 1000
for bouts=1,maxbouts do
	local pop = 20
	for roundnum=1,max_rounds do
		--Pick gamemode
		local pickarg = {} -- Key is gamemode, value is gamemode weight
		--print(pop)
		for k,gamemode in pairs(gamemodes) do
			if gamemode.req <= pop then 
				pickarg[k] = gamemode.prob
			end
		end
		local gamemode = gamemodes[pick_weights(pickarg)]
		local avail = {};for player,bool in pairs(player_playing) do -- Grabs all the people actually playing the video game
			avail[player] = player_pool[player] 
		end
		for player,rep in pairs(avail) do
			rep = rep + def_rep
			if rep > (def_rep + max_used_rep) then
				rep = def_rep + max_used_rep
			end
			avail[player] = rep -- Doesn't do this implicitly, unfortunately
		end
		local seats;
		if gamemode.coeff then 
			seats = math.floor(pop / gamemode.coeff)
			if seats < gamemode.min_seats then
				seats = min_seats
			end
		else
			seats = gamemode.max_seats
		end
		for i=1,seats do
			local antag = pick_weights(avail)
			--print(antag)
			player_antag_count[antag] = player_antag_count[antag] + 1
			seat_sum = seat_sum + 1
			avail[antag] = nil;
			player_pool[antag] = player_pool[antag] - max_used_rep
			if player_pool[antag] < 0 then
				player_pool[antag] = 0
			end
		end
		--io.write("Picked ",gamemode.max_seats," antags! ")
		--Now give the 10 rep to everyone who didn't get antag
		for player,rep in pairs(avail) do
			if rep then
				player_pool[player] = player_pool[player] + round_rep
				if player_pool[player] > max_rep then
					player_pool[player] = max_rep
				end
			end
		end
		--io.write("Had a ",gamemode.name," round!\n")
		
		--Now pass time
		time = time + math.random(low_round_time,high_round_time)
		--First take a third of the players and have them leave
		for player,bool in pairs(player_playing) do
			if math.random() < player_halflife then
				player_playing[player] = nil
				pop = pop - 1
			end
		end
		local newpop = getnewpop()
		for i=1, (newpop - pop) do
			local newguy = math.random(1,num_player_pool)
			if not player_playing[newguy] then -- If this random guy is not already playing
				player_playing[newguy] = true
				pop = pop + 1
			end
		end
		for k,v in pairs(player_playing) do
			player_rounds_played[k] = player_rounds_played[k] + 1
		end
	end
	local avgsum = 0
	for k,v in pairs(player_antag_count) do
		avgsum = avgsum + v
		if archive3[v] then
			archive3[v] = archive3[v] + 1
		else
			archive3[v] = 1
		end
	end
	local waitavg = 0
	local stddev = 0
	for k,v in pairs(player_antag_count) do
		waitavg = waitavg + (player_rounds_played[k] - v) / v
		--print((player_rounds_played[k] - v) / v )
	end
	waitavg = waitavg/num_player_pool
	for k,v in pairs(player_antag_count) do
		stddev = stddev + ((player_rounds_played[k] - v) / v - waitavg)^2
	end
	archive[#archive+1] = waitavg
	archive2[#archive2+1] = math.sqrt(stddev/(num_player_pool-1))
	--print(math.sqrt(stddev/(num_player_pool-1)))
	init_globals()
end
local avg = 0
for i=1,#archive do
	avg = avg + archive[i]
end
print(#archive)
print(avg/#archive)
avg = 0
for i=1,#archive2 do
	avg = avg + archive2[i]
end
print(#archive2)
print(avg/#archive2)
for rnds,boutsum in pairs(archive3) do
	print(boutsum/maxbouts)
end
io.write("-------------\n")
for rnds,boutsum in pairs(archive3) do
	print(rnds)
end
