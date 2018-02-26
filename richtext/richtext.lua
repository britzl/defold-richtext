local parser = require "richtext.parse"

local M = {}


local function get_trailing_whitespace(text)
	return text:match("^.-(%s*)$") or ""
end

local function get_font(word, settings)
	local font_name = word.font or settings.font
	local font_settings = settings.fonts[font_name]
	local font = nil
	if font_settings then
		if word.bold and word.italic then
			font = font_settings.bold_italic
		end
		if not font and word.bold then
			font = font_settings.bold
		end
		if not font and word.italic then
			font = font_settings.italic
		end
		if not font then
			font = font_settings.regular
		end
	end
	if not font then
		font = font_name
	end
	return hash(font)
end

function M.create(text, parent, width, settings)
	assert(text)
	assert(parent)
	assert(width)
	assert(settings)
	assert(settings.font)
	settings.color = settings.color or vmath.vector4(1)

	

	local initial_position = vmath.vector3()
	local position = vmath.vector3()
	
	local words = parser.parse(text)
	local highest_word = 0
	for _,word in pairs(words) do
		word.color = word.color or settings.color
		word.font = word.font or settings.font
		word.size = word.size or 1


		
		local node = gui.new_text_node(vmath.vector3(0), word.text)
		local font = get_font(word, settings)
		gui.set_parent(node, parent)
		gui.set_font(node, font)
		gui.set_pivot(node, gui.PIVOT_NW)
		gui.set_color(node, word.color)
		gui.set_scale(node, vmath.vector3(1) * (word.size or 1))

		local space_width = gui.get_text_metrics(font, "_").width

		word.metrics = gui.get_text_metrics_from_node(node)
		word.metrics.total_width = (word.metrics.width + #get_trailing_whitespace(word.text) * space_width) * word.size
		word.metrics.width = word.metrics.width * word.size
		word.metrics.height = word.metrics.height * word.size
		word.node = node

		highest_word = math.max(highest_word, word.metrics.height)

		if position.x + word.metrics.width > width then
			position.y = position.y - highest_word
			position.x = initial_position.x
		end
		gui.set_position(node, position)
		position.x = position.x + word.metrics.total_width
	end
end



return M