
local function lookupify(...)
	local hash = {}

	local function entry(key, ...)
		if key == nil then return end

		hash[key] = true

		return entry(...)
	end

	entry(...)
	return hash
end

local type_blacklist = lookupify(
	'function', 'thread', 'userdata', 'cdata'
)

local key_blacklist = lookupify(
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if',
  'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while'
)

-- Teeny-tiny speedup
local type   = type
local assert = assert
local pairs  = pairs

local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat

local string_format = string.format

local math_floor = math.floor

local function serialize_primitive(value, value_type)
	if type_blacklist[value_type] then -- Check if something slipped trough
		return 'nil'
	end

	if value_type == 'number' then
		return string_format('%g', value)
	else
		return string_format('%q', value)
	end
end

local function serialize_complex(value, value_type, ref_index)
	if ref_index then
		return string_format('R[%q]', ref_index)
	else
		return serialize_primitive(value, value_type)
	end
end

local function serialize_index_pair(want_dot, key, key_type, ref_key, value, value_type, ref_value)
	if key_type == 'string' and not key_blacklist[key] then
		local format = want_dot and '.%s=%s' or '%s=%s'

		return string_format(format, key, serialize_complex(value, value_type, ref_value))
	end

	return string_format('[%s]=%s',
		serialize_complex(key,   key_type,   ref_key),
		serialize_complex(value, value_type, ref_value)
	)
end

function serialize(table)
	local ioA    = {}
	local ioAptr = 0

	local ioB    = {}
	local ioBptr = 0

	local queue = {}

	local registry     = registry or {}
	local registry_idx = 1

	local function should_directly_serialize(value, value_type) 
		if value_type == 'table' then
			if registry[value] == nil then
				registry[value] = true

				return table_insert(queue, value)
			end

			return nil
		end

		return true
	end

	-- Write preamble for local variables
	ioAptr      = ioAptr +1
	ioA[ioAptr] = 'local R,N,A={'

	-- Phase 1: Process queue, discover new recursive tables
	local obj = table

	while obj do
		ioAptr      = ioAptr +1
		ioA[ioAptr] = '{'

		-- Reset previous buffer
		ioBptr = 0

		-- Initialize array like tables in a more compact way
		local array_init_end = 0
	
		do
			local index       = 1 
			local nil_backlog = 0

			while true do
				local value      = obj[index]
				local value_type = type(value)

				if value == nil or not should_directly_serialize(value, value_type) then
					nil_backlog = nil_backlog +1
				
					if nil_backlog > 5 then
						break	-- Too many nils to call this a minor hiccup
					end
				else
					-- Flush backlog
					for i = 1, nil_backlog do
						ioBptr      = ioBptr +1
						ioB[ioBptr] = 'N'
					end

					nil_backlog = 0

					-- Serialize primitive
					ioBptr      = ioBptr +1
					ioB[ioBptr] = serialize_primitive(value, value_type)
				end
			
				-- Try next value
				index = index +1	
			end

			-- Array initializer done, do sparse init
			array_init_end = index
		end

		-- Sparse initializer
		do
			for key, value in pairs(obj) do
				local type_key   = type(key)
				local type_value = type(value)

				if type_key == 'number' and 1 <= key and key <= array_init_end and math_floor(key) == key then
					-- Previously handled during array initializer
				else
					-- Check if we can serialize this key-value pair
					local enq_key   = should_directly_serialize(key,   type_key)
					local enq_value = should_directly_serialize(value, type_value)

					if enq_key and enq_value then
						ioBptr      = ioBptr +1
						ioB[ioBptr] = serialize_index_pair(false, key, type_key, nil, value, type_value, nil)
					end
				end
			end
		end

		-- All done, commit to primary buffer
		ioAptr      = ioAptr +1
		ioA[ioAptr] = table_concat(ioB, ',', 1, ioBptr)

		ioAptr      = ioAptr +1
		ioA[ioAptr] = '},'

		-- Assign unique index to this registry entry
		local uid = registry[obj]

		if uid == nil or uid == true then
			registry[obj] = registry_idx

			registry_idx = registry_idx +1
		end

		-- Pick next table to dissect
		obj = table_remove(queue)
	end

	ioAptr      = ioAptr +1
	ioA[ioAptr] = '}'

	-- Phase 2: Process registry, restore cross-reference fields
	
	for complex, ref_self in pairs(registry) do

		-- Reset secondary buffer
		ioBptr = 0

		for key, value in pairs(complex) do
			local ref_key   = registry[key]
			local ref_value = registry[value]

			-- Check if either key/value is a reference
			if ref_key or ref_value then
				ioBptr      = ioBptr +1
				ioB[ioBptr] = serialize_index_pair(true, key, type(key), ref_key, value, type(value), ref_value)
			end
		end

		-- Flush index restoring expressions
		if ioBptr ~= 0 then
			if ioBptr == 1 then
				ioAptr      = ioAptr +1
				ioA[ioAptr] = serialize_complex(complex, nil, ref_self)

				ioAptr      = ioAptr +1
				ioA[ioAptr] = ioB[1]				
			else
				ioAptr      = ioAptr +1
				ioA[ioAptr] = 'A='

				ioAptr      = ioAptr +1
				ioA[ioAptr] = serialize_complex(complex, nil, ref_self)

				ioAptr      = ioAptr +1
				ioA[ioAptr] = 'A'

				ioAptr      = ioAptr +1
				ioA[ioAptr] = table_concat(ioB, 'A', 1, ioBptr)
			end
		end
	end

	return table_concat(ioA)
end


local A = { name = 'do' }
local B = { name = 'break' }

local tbl = {0}

for i=1,10 do
	tbl = {tbl,nil,i,nil,nil,20,nil,nil,nil,nil,nil,nil,[20]=20}
end

A[B] = B
A.tbl = tbl
A['if'] = true

B[A] = A
B.tbl = tbl
B['function'] = false

print( serialize( _G ) )
