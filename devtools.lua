
-- Manifest
local GARRYSMOD = true


--[[
	Options
		describe
			select         = <number>   Select one of the returned values
			keys           = <flag>     Only print keys of returned value

			limit          = <number>   Limit the amount of entries printed in each table
			escape_newline = <flag>     Escape newline characters in output

		grep_stream
			grep     = <string>   Text to hilight in output text
			grepline = <string>   Hilight lines that contain matched text
			nocase   = <flag>     Ignore upper-lowercase when searching

		lineno_stream
			lineno   = <bool>     Show line numbers next to output
--]]


--[[
	To make this code as generic as possible, stdout is abstracted as 'out'
	Following member functions are expected from all implementations

	:init(options)
	:printc(color, string)
	:newl()

	Colors are tables:
		{ r = 255, g = 255, b = 255 }
]]--

--[[
	Some environments may have different implementation of these

	This is a declaration, not localization. DO NOT REMOVE
]]--
local iterate    = pairs
local loadstring = loadstring


-- Config
local COLOR_GENERIC = { r = 255, g = 255, b = 255 }
local COLOR_COMMENT = { r = 165, g = 225, b = 45  }

local COLOR_KEY     = { r = 250, g = 150, b = 30  }
local COLOR_REF     = { r = 165, g = 225, b = 45  }

local COLOR_BOOLEAN = { r = 175, g = 130, b = 255 }
local COLOR_NUMBER  = { r = 175, g = 130, b = 255 }
local COLOR_STRING  = { r = 230, g = 220, b = 115 }


-- This object can be used to force the describer to describe nil values
local NIL_INSTANCE = {}

-- Function to resolve typenames
local function typename(obj)
	return type(obj)
end

--
-- Just code from here
--
function ipairs_ex(t, from)
	local idx = from or 1

	return function()
		local value = t[idx]

		if value == nil then
			return
		end

		idx = idx +1
		return idx -1, value
	end
end

local function expand_path(path, key)
	if path == "" then
		return key
	end

	return string.format(isstring(key) and "%s.%s" or "%s[%s]", path, key)
end


function describe(value, out, options)

	local DECOR_FIRST  = "┳ "
	local DECOR_MEMBER = "┣ "
	local DECOR_LAST   = "┗ "

	-- These are cross referenced, this is a pseudo declaration
	local describe_value
	local describe_member
	local describe_table

	-- Context for this describe job
	local paths = {}
	local depth = 1


	function describe_table(prefix, path, tbl, key)

		-- Add this table to the paths, for ref. resolving
		path       = expand_path(path, key)
		paths[tbl] = path

		-- Collect keys, calculate value inset
		local keys    = {}	
		local key_wide = 0

		local count   = 0

		for key in iterate(tbl) do
			table.insert(keys, key)

			-- Find max length to accomodate for
			key_wide = math.max(key_wide, tostring(key):len())
			count   = count +1
		end

		-- No keys? Print empty table value
		if count == 0 then
			out:printc(COLOR_GENERIC, prefix)
			out:printc(COLOR_GENERIC, "{}")
			out:newl()

			return
		end

		-- Enforce some breathing room
		key_wide = key_wide +2

		-- Sort table keys
		table.sort(keys, function(A, B)
		
			-- Respect numeric values when sorting
			if isnumber(A) and isnumber(B) then
				return A < B
			end
		
			-- Otherwise fall back to string representation
			return tostring(A) < tostring(B)
		end )

		-- Limit number of values described
		local limit = tonumber(options.limit) or 100

		for idx, key in ipairs(keys) do

			-- Keep track of # printed objects
			if idx > limit then
				out:printc(COLOR_GENERIC, prefix)

				out:printc(COLOR_COMMENT, "... (")
				out:printc(COLOR_COMMENT, tostring(count - idx +1))
				out:printc(COLOR_COMMENT, " entries hidden)")
				out:newl()
				break
			end

			-- Fancy
			local decor = DECOR_MEMBER

			if idx == 1     then decor = DECOR_FIRST end
			if idx == count then decor = DECOR_LAST  end

			describe_member(prefix, decor, path, tbl[key], key, key_wide)
		end
	end

	function describe_member(prefix, decor, path, value, key, key_wide)
		local ref_path

		-- Prefix
		out:printc(COLOR_GENERIC, prefix)

		-- Stringify key, calculate padding
		local key_str = tostring(key)
		local padding = key_wide - key_str:len()

		if padding < 0 then
			key_str = key_str:sub(1, padding -3) .. " .."
		end

		-- Add guideline to prefix
		prefix = string.format("%s┃ %s", prefix, string.rep(" ", key_wide +2))

		-- Delegate early on tables, also watch for NIL_INSTANCE, as it is implemented as a table
		if istable(value) and value ~= NIL_INSTANCE then
			ref_path = paths[value]

			-- Only print unvisited tables
			if not ref_path then

				-- Overly fancy: Peek to see if there will be any more values
				if decor == DECOR_LAST and next(value) then
					decor = DECOR_MEMBER
				end

				out:printc(COLOR_GENERIC, decor)
				out:printc(COLOR_KEY,     key_str)
				out:printc(COLOR_GENERIC, ": ")
				out:newl()

				-- Enumerate members
				describe_table(prefix, path, value, key)
				return
			end
		end

		-- Print value key prefix
		out:printc(COLOR_GENERIC, decor)
		out:printc(COLOR_KEY,     key_str)
		out:printc(nil,           string.rep(" ", padding))
		out:printc(COLOR_GENERIC, "= ")

		-- Reference				
		if ref_path then
			out:printc(COLOR_REF, "ref: ")
			out:printc(COLOR_REF, ref_path)
			out:newl()
			return
		end

		-- Delegate
		describe_value(prefix, value)
	end


	function describe_value(prefix, value)

		-- Special nil instance
		if value == NIL_INSTANCE then
			out:printc(COLOR_NUMBER, "nil")
			out:newl()
			return
		end

		-- Booleans
		if isbool(value) then
			out:printc(COLOR_BOOLEAN, tostring(value))
			out:newl()
			return
		end

		-- Numbers (optionally as hex)
		if isnumber(value) then
			out:printc(COLOR_NUMBER, tostring(value))
			out:newl()
			return
		end

		-- Strings (escape + multiline handling)
		if isstring(value) then
			local len = value:len()

			-- Print single characters with simple quotes
			if len == 1 then
				out:printc(COLOR_STRING, "'")
				out:printc(COLOR_STRING, value)
				out:printc(COLOR_STRING, "'")
				
				out:newl()
				return
			end

			-- Check if string is multiline
			local newl, to = string.find(value, "\r?\n")

			-- Optinally escape newline characters
			if newl and options.escape_newline then
				value = value:gsub("\r?\n", "\\n")
				newl  = nil
			end

			-- No newline, print inline
			if not newl then
				out:printc(COLOR_STRING, "\"")
				out:printc(COLOR_STRING, value)
				out:printc(COLOR_STRING, "\"")
				
				out:newl()
				return
			end

			-- Print each line separately
			local pos = to +1

			out:printc(COLOR_STRING, '[[')
			out:printc(COLOR_STRING, value:sub(1, newl))

			while true do
				out:printc(COLOR_GENERIC, prefix)

				newl, to = string.find(value, "\r?\n", pos)

				if newl then
					out:printc(COLOR_STRING, value:sub(pos, newl -1))
					out:newl()

					pos = to +1
				else
					out:printc(COLOR_STRING, value:sub(pos))
					break
				end
			end

			out:printc(COLOR_STRING, ']]')
			out:newl()
			return
		end

		-- Functions
		if isfunction(value) then

		end

		-- Generic fallback, print typename and address


		-- Fallback
		out:printc(nil, tostring(value))
		out:newl()
	end

	-- Start job
	if istable(value) and value ~= NIL_INSTANCE then
		describe_table("", "", value, "root")
	else
		describe_value("", value)
	end
end




local function opt_bool(value)
	if value == true or value == false then
		return value
	end
end

local function error_format(msg, ...)
	error( string.format(msg, ...), 2 )
end

function parse_command_options(input, fenv)
	local raw_options = string.match(input, "|(.*)$")
	local options     = {}

	-- No pipe, no options
	if not raw_options then
		return input, options
	end

	-- Parse options
	string.gsub(raw_options, "[^|]+", function(part)
		local key, value = part:match("^([^=]+)=?(.*)$")

		-- Trim pair of unwanted spaces
		key   = key:match("^%s*(.-)%s*$")
		value = value:match("^%s*(.-)%s*$")

		if value == "" then
			-- Flag like behavior
			value = true
		else
			-- Try converting the value to a literal
			local literal = tonumber(value) or opt_bool(value)

			if literal ~= nil then
				value = literal
			else
				-- Automatically parse quoted strings
				local parse = value:sub(1, 1) == '"' or value:sub(1, 1) == "'"

				-- Parsing can be forced with a '!' prefix
				if value:sub(1, 1) == '!' then
					value = value:sub(2)
					parse = true
				end

				if parse then
					local func, syntax_err = loadstring("return " .. value, "parse_lua_value", "text", fenv)

					if syntax_err then
						error_format("Cannot parse option '%s' due to syntax error: %s", key, syntax_err)
					end

					local succ, ret = pcall(func)

					if not succ then
						error_format("Cannot parse option '%s' due to runtime error: %s", key, ret)
					end

					value = ret
				end
			end

			-- Done converting
		end

		-- Opt-out check for nil parameters
		if value == nil and not options['ignore-nil'] then
			error_format("Option '%s' evaluated to nil! [Override with 'ignore-nil' key]", key)
		end

		-- Check if option would overwrite something
		if options[key] ~= nil then
			error_format("Redefinition of '%s' option!", key)
		end

		options[key] = value
	end)

	OPT = options

	-- Cut options from input
	input = input:sub(0, -raw_options:len() -2)

	return input, options
end

function lua_command(input, out, fenv)
	local input         = string.match(input or "", "^%s*(.-)%s*$")
	local code, options = parse_command_options(input, fenv)

	-- Initialize output stream
	out:init(options)

	if code == "" then
		error("No code provided")
	end

	-- TODO: From context?
	local chunkname = "lua_command"

	-- Compile expression to code
	local simple_expr      = true
	local func, syntax_err = loadstring("return " .. code, chunkname, nil, fenv)

	-- Code may have explicit return/advanced control flow
	if syntax_err then
		simple_expr      = false
		func, syntax_err = loadstring(code, chunkname, nil, fenv)
	end

	if syntax_err then
		error_format("Syntax error: %s", syntax_err)
	end

	-- Run code, capture return values
	local res = { pcall(func) }

	-- Prompt
	local prefix = res[2] ~= nil and "= " or "<< "

	out:printc(COLOR_COMMENT, prefix)
	out:printc(COLOR_COMMENT, code)
	out:newl()

	-- Report results
	if not res[1] then
		error_format("Runtime error: %s", res[2])
	else
		--[[
			Note: Due to the nature of { pcall() }, the first value is the success, but if the expressions
			returns multiple 'nil's before the first actual value, indexes may be skewed!

			Therefore manual location of the highest index is required. The skipped indexes will be filled
			with NIL_INSTANCE, a special value to represent 'nil'
		--]]
		local num_returns = 1

		for idx in pairs(res) do
			num_returns = math.max(num_returns, idx)
		end

		for idx = 1, num_returns do
			if res[idx] == nil then
				res[idx] = NIL_INSTANCE
			end
		end

		-- 'succ' from pcall is still in the list, remove
		num_returns = num_returns -1
		table.remove(res, 1)

		-- Nothing to print
		if num_returns == 0 then
			return
		end

		-- User should be informed, otherwise table returns can be confused for multret
		if num_returns > 1 then
			out:printc(COLOR_COMMENT, "[Multiple values returned]")
			out:newl()
		end

		-- Optionally limit printing to a single value
		if options.select then
			local idx = options.select

			out:printc(COLOR_COMMENT, "[Selecting return value #" .. idx .. "]")
			out:newl()

			if idx > num_returns then
				out:printc(COLOR_COMMENT, "[No value]")
				out:newl()
				return
			else
				num_returns = 1
				res = { res[idx] }
			end
		end

		-- Unwrap single return values
		if num_returns == 1 then
			res = res[1]
		end

		-- Describe results
		describe(res, out, options)
	end
end

-- Stream to render line numbers
function lineno_stream(out)
	local stream = {}

	-- State/settings
	local enabled

	local lineno
	local isdone

	function stream:init(options)
		enabled = options.lineno
		lineno  = 0

		out:init(options)
	end

	function stream:printc(color, str)
		if enabled and not isdone then
			isdone = true
			lineno = lineno +1

			out:printc(COLOR_COMMENT, string.format("%04d: ", lineno))
		end

		out:printc(color, str)
	end

	function stream:newl()
		isdone = false

		out:newl()
	end

	return stream
end


-- Special stream supporting grep functionality
local COLOR_GREP     = {r = 255, g = 50,  b = 50 }
local COLOR_GREPLINE = {r = 255, g = 150, b = 150}

function grep_stream(out, pattern)
	local stream = {}

	-- Settings
	local pattern
	local ignorecase

	local line_color
	local match_color

	-- Internal state
	local idx     = 0
	local strings = {}
	local colors  = {}

	function stream:init(options)
		
		-- Reset settings
		pattern    = nil
		ignorecase = false

		line_color  = nil
		match_color = COLOR_GREP

		-- Parse options
		ignorecase = options.nocase

		if isstring(options.grep) then
			pattern = options.grep
		end

		if isstring(options.grepline) then
			pattern    = options.grepline
			line_color = COLOR_GREPLINE
		end

		-- Validate pattern (if any)
		if pattern then
			string.find("", pattern)

			if ignorecase then
				pattern = pattern:lower()
			end
		end

		-- Initialize base stream
		out:init(options)
	end

	function stream:printc(color, str)
		if not pattern then
			out:printc(color, str)
			return
		end

		idx = idx +1

		colors[idx]  = color
		strings[idx] = str
	end

	function stream:newl()
		if not pattern then
			out:newl()
			return
		end

		-- Newline means we have to match against our grep, merge line
		local merge     = table.concat(strings)
		local overrides = {}

		if ignorecase then
			merge = merge:lower()
		end

		-- Match the grep against our line as long as it does
		local from = 1

		while true do
			local start, finish, A, B = string.find(merge, pattern, from, false)

			if not start then
				break
			end

			table.insert(overrides, { start = start, finish = finish, color = match_color })

			-- TODO: Find capture groups?

			from = finish +1
		end

		if not overrides[1] then
			-- No match, just render as normal values
			for part, text in ipairs(strings) do
				out:printc(colors[part], text)
			end
		else
			-- Render output, while watching overrides
			local part = 1
			local off  = 1

			local pos = 0

			for _, override in ipairs(overrides) do
				for idx, text in ipairs_ex(strings, part) do
					part = idx

					-- Text has part before override start, print normally
					local start = override.start - pos -1
					local len   = text:len()

					if start > 0 then
						local chars = math.min(len - off +1, start)

						out:printc(line_color or colors[part], text:sub(off, off + chars -1))

						pos = pos + chars
						off = off + chars
					end

					-- Remaining part is partially inside override
					if off <= len then
						local chars = math.min(len - off +1, override.finish - pos)

						out:printc(override.color, text:sub(off, off + chars -1))

						pos = pos + chars
						off = off + chars
					end

					-- Text still has remaining part? Restart with new override
					if off <= len then
						break
					end

					-- Erase offset for new text (if any)
					if strings[part +1] then
						off = 1
					end
				end
			end

			-- No more overrides, finish active string
			out:printc(line_color or colors[part], strings[part]:sub(off))

			-- Render remaining parts as normal
			for part, text in ipairs_ex(strings, part +1) do
				out:printc(line_color or colors[part], text)
			end
		end

		-- Clear state
		idx = 0

		colors  = {}
		strings = {}

		-- Finished!
		out:newl()
	end

	return stream
end


--[[ Garry's Mod ]]--
if GARRYSMOD then 

	function loadstring(source, chunk, mode, fenv)
		local res = CompileString(source, chunk, false)

		if isstring(res) then
			return nil, res
		end

		-- TODO: setfenv
		return res
	end

	console_stream = {}

	function console_stream:init(options)
	end

	function console_stream:printc(color, str)
		if color == nil then
			MsgC(str)
		else
			MsgC(color, str)
		end
	end

	function console_stream:newl()
		MsgN()
	end

	-- Add fancy capabilities with decorators
	console_stream = lineno_stream(console_stream)
	console_stream = grep_stream(console_stream)

	concommand.Add("lua", function(ply, cmd, args, raw)
		lua_command(raw, console_stream, _G)
	end)
end


--[[ Factorio ]]--
if FACTORIO then

	local function setupContext( context )
		ctx = context

		me      = game.players[ ctx.player_index ]
		here    = me.position
		surface = game.surfaces["nauvis"]

		around = function( r )
			local r = r or 4

			return {{here.x -r, here.y -r}, {here.x +r, here.y +r}}
		end
	end

	local function lua2(ctx, out)
		local player = game.players[ctx.player_index]

		-- Check permissions
		if not player.admin then
			error("Access denied")
			return
		end

		-- TODO: This is a hack
		setupContext(ctx)

		lua_command(ctx.parameter, out, _G)
	end

	commands.add_command("lua", "mem.lua", function(ctx)
		local out = {}

		-- Factorio does not allow newlines, so cache all values to print, then newline
		local line_raw = {}

		function out:printc(color, str)
			table.insert(line_raw, str)
		end
		function out:newl()
			game.print(table.concat(line_raw, " "))

			-- gc does wonders
			line_raw = {}
		end

		local succ, err = pcall(lua2, ctx, out)

		if not succ then
			print("Command error: ", err)
		end
	end)
end
