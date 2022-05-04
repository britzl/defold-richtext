local color = require "richtext.color"

local M = {}

local tags = {}


function M.apply(tag, params, settings)
	local fn = tags[tag]
	if not fn then
		return false
	end
	
	fn(params, settings)
	return true
end

function M.register(tag, fn)
	assert(tag, "You must provide a tag")
	assert(fn, "You must provide a tag function")
	tags[tag] = fn
end



M.register("color", function(params, settings)
	settings.color = color.parse(params)
end)

M.register("shadow", function(params, settings)
	settings.shadow = color.parse(params)
end)

M.register("outline", function(params, settings)
	settings.outline = color.parse(params)
end)

M.register("font", function(params, settings)
	settings.font = params
end)

M.register("size", function(params, settings)
	settings.size = tonumber(params)
end)

M.register("b", function(params, settings)
	settings.bold = true
end)

M.register("i", function(params, settings)
	settings.italic = true
end)

M.register("a", function(params, settings)
	settings.anchor = true
end)

M.register("br", function(params, settings)
	settings.linebreak = true
end)

M.register("nobr", function(params, settings)
	settings.nobr = true
end)

M.register("img", function(params, settings)
	local texture, anim = params:match("(.-):(.*)")
	settings.image = {
		texture = texture,
		anim = anim
	}
end)

M.register("spine", function(params, settings)
	local scene, anim = params:match("(.-):(.*)")
	settings.spine = {
		scene = scene,
		anim = anim
	}
end)

M.register("p", function(params, settings)
	settings.paragraph = tonumber(params) or true
end)


return M