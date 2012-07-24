local Expression2 = GCompute.GlobalNamespace:AddNamespace ("Expression2")
local Number = Expression2:AddType ("number")

Number:AddFunction ("toHex")
	:SetReturnType ("string")
	:SetNativeFunction (
		function (n)
			return string.format ("%x", n)
		end
	)

local function addOperator (symbol, f)
	Number:AddFunction ("operator" .. symbol, { { "number", "b" } })
		:SetReturnType ("number")
		:SetNativeString ("(%self% " .. symbol .. "%arb:b%)")
		:SetNativeFunction (f)
end

addOperator ("+", function (a, b) return a + b end)
addOperator ("-", function (a, b) return a - b end)
addOperator ("*", function (a, b) return a * b end)
addOperator ("/", function (a, b) return a / b end)
addOperator ("%", function (a, b) return a % b end)
addOperator ("^", function (a, b) return a ^ b end)
addOperator ("&", function (a, b) return a & b end)
addOperator ("|", function (a, b) return a | b end)
	
Number:AddExplicitCast ("bool", function (n) return n ~= 0 end)
Number:AddExplicitCast ("string", function (n) return tostring (n) end)