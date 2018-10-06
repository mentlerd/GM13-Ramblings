-- Special hook dispatcher implementation. (Do not touch unless you absolutely know what you are doing!)
do
	local index  -- Shared upvalue between the safe (chainDispatcher) and protected (chainExecutor) context
	             -- used to communicate the 'to be called' hooks index.

	             -- This upvalue is used for two way communication:
	             --    The safe context tells the next hook index to be called in the protected context
	             --    The protected context tells the safe context what hook index caused the error that
	             --    resulted in the context change

	local function hookExecutor( hooks, ... )
		local a, b, c, d, e, f

		while index ~= nil do
			local func      = hooks[index]
			local nextIndex = next(hooks, index)

			do
				if isstring( index ) then
					a, b, c, d, e, f = func( ... )
				elseif IsValid( index ) then
					a, b, c, d, e, f = func( index, ... )
				else
					hooks[index] = nil
				end

				if a ~= nil then
					return a, b, c, d, e, f
				end
			end

			index = nextIndex
		end
	end

	local function hookDispatcher( hooks, ... )
		local context = index          -- The caller context is saved here, so nested calls to hookDispatcher can work
		local succ, a, b, f, c, e, f

		index = nil                    -- It is crucial that however this method exists, it must restore the 'index'
		                               -- upvalue to its original value, or nested calls of 'hookDispatcher' may misbehave,
		                               -- therefore no errors must happen beyond this point!

		while true do
			index = next(hooks, index)

			succ, a, b, c, d, e, f = pcall(hookExecutor, hooks, ...)

			if succ then
				index = context

				return a, b, c, d, e, f
			else
				print("Hook failure: ", index, " - Err: ", a )
			end
		end
	end

end
