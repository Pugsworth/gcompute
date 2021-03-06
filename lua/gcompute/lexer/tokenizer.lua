local self = {}
GCompute.Tokenizer = GCompute.MakeConstructor (self)

local SymbolMatchType = GCompute.SymbolMatchType

function self:ctor (language)
	self.Language = language
	self.SymbolMatchers = {}
	
	self.NativeCode = nil
end

function self:AddCustomSymbol (tokenType, prefix, matchingFunction)
	self.SymbolMatchers [#self.SymbolMatchers + 1] =
	{
		String    = prefix,
		MatchType = SymbolMatchType.Custom,
		TokenType = tokenType,
		Matcher   = matchingFunction
	}
	
	return self
end

function self:AddCustomSymbols (tokenType, prefixes, matchingFunction)
	for _, prefix in ipairs (prefixes) do
		self:AddCustomSymbol (tokenType, prefix, matchingFunction)
	end
	
	return self
end

function self:AddPatternSymbol (tokenType, pattern)
	self.SymbolMatchers [#self.SymbolMatchers + 1] =
	{
		String    = "^" .. pattern,
		MatchType = SymbolMatchType.Pattern,
		TokenType = tokenType
	}
	
	return self
end

function self:AddPatternSymbols (tokenType, patterns)
	for _, pattern in ipairs (patterns) do
		self:AddPatternSymbol (tokenType, pattern)
	end
	
	return self
end

function self:AddPlainSymbol (tokenType, symbol)
	if symbol:len () == 0 then GCompute.Error ("Tokenizer:AddPlainSymbol : Symbol cannot be zero-length.") return end
	
	local lookup = nil
	if symbol:len () <= 3 then
		local previousSymbolMatcher = self.SymbolMatchers [#self.SymbolMatchers]
		if not previousSymbolMatcher or previousSymbolMatcher.MatchType ~= SymbolMatchType.Lookup then
			lookup = {}
			self.SymbolMatchers [#self.SymbolMatchers + 1] =
			{
				MatchType = SymbolMatchType.Lookup,
				Lookup   = lookup
			}
		else
			lookup = previousSymbolMatcher.Lookup
		end
	end
	if not lookup then
		self.SymbolMatchers [#self.SymbolMatchers + 1] =
		{
			String    = symbol,
			MatchType = SymbolMatchType.Plain,
			TokenType = tokenType
		}
	else
		if lookup [string.sub (symbol, 1, 1)] then
			GCompute.Error ("Tokenizer:AddPlainSymbol : \"" .. GLib.String.Escape (symbol) .. "\" is longer and has a lower precedence than \"" .. GLib.String.Escape (string.sub (symbol, 1, 1)) .. "\" and will never be reached.")
			return self
		end
		if lookup [string.sub (symbol, 1, 2)] then
			GCompute.Error ("Tokenizer:AddPlainSymbol : \"" .. GLib.String.Escape (symbol) .. "\" is longer and has a lower precedence than \"" .. GLib.String.Escape (string.sub (symbol, 1, 2)) .. "\" and will never be reached.")
			return self
		end
		if lookup [string.sub (symbol, 1, 3)] then
			GCompute.Error ("Tokenizer:AddPlainSymbol : \"" .. GLib.String.Escape (symbol) .. "\" is longer and has a lower precedence than \"" .. GLib.String.Escape (string.sub (symbol, 1, 3)) .. "\" and will never be reached.")
			return self
		end
		lookup [symbol] = tokenType
	end
	
	return self
end

function self:AddPlainSymbols (tokenType, symbols)
	for _, symbol in ipairs (symbols) do
		self:AddPlainSymbol (tokenType, symbol)
	end
	
	return self
end

function self:Compile ()
	-- Solid organic waste reification is about to occur.
	
	local upvalueTable = {}
	local nextCustomMatcherId = 1
	local nextLookupId = 1
	
	local lookupLocalCreated = false
	
	upvalueTable ["string_match"] = string.match
	upvalueTable ["string_sub"]   = string.sub
	
	local code = "return function (self, code, offset)\n"
	code = code .. "\tlocal match\n"
	code = code .. "\tlocal matchLength\n"
	for _, symbolMatcher in ipairs (self.SymbolMatchers) do
		local symbolMatchType = symbolMatcher.MatchType
		local tokenType = symbolMatcher.TokenType
		
		if symbolMatchType == SymbolMatchType.Plain then
			code = code .. "\tif string_sub (code, offset, offset + " .. tostring (string.len (symbolMatcher.String) - 1) .. ") == \"" .. GLib.String.Escape (symbolMatcher.String) .. "\" then\n"
			code = code .. "\t\treturn \"" .. GLib.String.Escape (symbolMatcher.String) .. "\", " .. string.len (symbolMatcher.String) .. "\n"
			code = code .. "\tend\n"
			code = code .. "\t\n"
		elseif symbolMatchType == SymbolMatchType.Lookup then
			upvalueTable ["lookup" .. tostring (nextLookupId)] = symbolMatcher.Lookup
			
			if not lookupLocalCreated then
				code = code .. "\tlocal lookup\n"
				code = code .. "\tlocal lookupSymbol\n"
				lookupLocalCreated = true
			end
			code = code .. "\tlookup = lookup" .. tostring (nextLookupId) .. "\n"
			code = code .. "\t\n"
			code = code .. "\tlookupSymbol = string_sub (code, offset, offset + 2)\n"
			code = code .. "\tif lookup [lookupSymbol] then return lookupSymbol, 3, lookup [lookupSymbol] end\n"
			code = code .. "\t\n"
			code = code .. "\tlookupSymbol = string_sub (lookupSymbol, 1, 2)\n"
			code = code .. "\tif lookup [lookupSymbol] then return lookupSymbol, 2, lookup [lookupSymbol] end\n"
			code = code .. "\t\n"
			code = code .. "\tlookupSymbol = string_sub (lookupSymbol, 1, 1)\n"
			code = code .. "\tif lookup [lookupSymbol] then return lookupSymbol, 1, lookup [lookupSymbol] end\n"
			code = code .. "\t\n"
			
			nextLookupId = nextLookupId + 1
		elseif symbolMatchType == SymbolMatchType.Pattern then
			code = code .. "\tmatch = string_match (code, \"" .. GLib.String.Escape (symbolMatcher.String) .. "\", offset)\n"
			code = code .. "\tif match then return match, #match, " .. tostring (symbolMatcher.TokenType) .. " end\n"
			code = code .. "\t\n"
		else
			upvalueTable ["customMatcher" .. tostring (nextCustomMatcherId)] = symbolMatcher.Matcher
			
			code = code .. "\tif string_sub (code, offset, offset + " .. tostring (string.len (symbolMatcher.String) - 1) .. ") == \"" .. GLib.String.Escape (symbolMatcher.String) .. "\" then\n"
			code = code .. "\t\tmatch, matchLength = customMatcher" .. tostring (nextCustomMatcherId) .. " (code, offset)\n"
			code = code .. "\t\tif match then return match, matchLength, " .. tostring (symbolMatcher.TokenType) .. " end\n"
			code = code .. "\tend\n"
			code = code .. "\t\n"
			
			nextCustomMatcherId = nextCustomMatcherId + 1
		end
	end
	code = code .. "\tmatch = GLib.UTF8.NextChar (code, offset)\n"
	code = code .. "\treturn match, #match, GCompute.TokenType.Unknown\n"
	code = code .. "end\n"
	
	local upvalues = ""
	local upvalueBackup = {}
	
	for upvalueName, value in pairs (upvalueTable) do
		upvalueBackup [upvalueName] = _G [upvalueName]
		_G [upvalueName] = value
		
		upvalues = upvalues .. "local " .. upvalueName .. " = " .. upvalueName .. "\n"
	end
	
	self.NativeCode = upvalues .. code
	local nativeFunctionFactory = CompileString (self.NativeCode, self.Language:GetName () .. ".Tokenizer")
	local nativeFunction = nativeFunctionFactory ()
	if not nativeFunction then
		GCompute.Error ("Failed to create a native function for " .. self.Language:GetName () .. "'s tokenizer.")
	end
	self.MatchSymbol = nativeFunction or self.MatchSymbolSlow
	
	for upvalueName, _ in pairs (upvalueTable) do
		_G [upvalueName] = upvalueBackup [upvalueName]
	end
end

function self:MatchSymbol (code, offset)
	self:Compile ()
	return self:MatchSymbol (code, offset)
end

function self:MatchSymbolSlow (code, offset)
	for i = 1, #self.SymbolMatchers do
		local symbolMatcher = self.SymbolMatchers [i]
		local symbolMatchType = symbolMatcher.MatchType
		local match = nil
		local matchLength = 0
		local tokenType = symbolMatcher.TokenType
		if symbolMatchType == SymbolMatchType.Plain then
			if string.sub (code, offset, offset + #symbolMatcher.String - 1) == symbolMatcher.String then
				match = symbolMatcher.String
				matchLength = #match
			end
		elseif symbolMatchType == SymbolMatchType.Lookup then
			local lookup = symbolMatcher.Lookup
			
			local lookupSymbol = string.sub (code, offset, offset + 2)
			if lookup [lookupSymbol] then return lookupSymbol, 3, lookup [lookupSymbol] end
			
			lookupSymbol = string.sub (lookupSymbol, 1, 2)
			if lookup [lookupSymbol] then return lookupSymbol, 2, lookup [lookupSymbol] end
			
			lookupSymbol = string.sub (lookupSymbol, 1, 1)
			if lookup [lookupSymbol] then return lookupSymbol, 1, lookup [lookupSymbol] end
		elseif symbolMatchType == SymbolMatchType.Pattern then
			match = string.match (code, symbolMatcher.String, offset)
			if match then matchLength = #match end
		else
			if string.sub (code, offset, offset + #symbolMatcher.String - 1) == symbolMatcher.String then
				match, matchLength = symbolMatcher.Matcher (code, offset)
			end
		end
		if match then
			return match, matchLength, tokenType
		end
	end
	
	local match = GLib.UTF8.NextChar (code, offset)
	return match, #match, GCompute.TokenType.Unknown
end