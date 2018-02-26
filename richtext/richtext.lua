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
		font = settings.font
	end
	return font
end

function M.create(text, font, settings)
	assert(text)
	assert(font)
	settings = settings or {}
	settings.font = font
	settings.fonts = settings.fonts or {}
	if not settings.fonts[font] then
		settings.fonts[font] = {
			regular = hash(font)
		}
	end
	settings.color = settings.color or vmath.vector4(1)
	settings.position = settings.position or vmath.vector3()

	-- cache length of a single space, per font
	local space_widths = {}

	local position = vmath.vector3(settings.position)
	
	local words = parser.parse(text)
	local highest_word = 0
	local nodes = {}
	for _,word in pairs(words) do
		-- assign defaults if needed
		word.color = word.color or settings.color
		word.font = word.font or settings.font
		word.size = word.size or 1

		-- get font to use based on word tags
		local font = get_font(word, settings)

		-- create and configure text node
		local node = gui.new_text_node(vmath.vector3(0), word.text)
		nodes[#nodes + 1] = node
		if settings.parent then
			gui.set_parent(node, settings.parent)
		end
		gui.set_font(node, font)
		gui.set_pivot(node, gui.PIVOT_NW)
		gui.set_color(node, word.color)
		gui.set_scale(node, vmath.vector3(1) * (word.size or 1))

		-- measure width of a single space for current font
		if not space_widths[font] then
			space_widths[font] = gui.get_text_metrics(font, " _").width - gui.get_text_metrics(font, "_").width
		end

		-- get metrics of node
		word.metrics = gui.get_text_metrics_from_node(node)
		word.metrics.total_width = (word.metrics.width + #get_trailing_whitespace(word.text) * space_widths[font]) * word.size
		word.metrics.width = word.metrics.width * word.size
		word.metrics.height = word.metrics.height * word.size
		highest_word = math.max(highest_word, word.metrics.height)

		-- adjust position and position node
		if settings.width and position.x + word.metrics.width > settings.width then
			position.y = position.y - highest_word
			position.x = settings.position.x
			highest_word = 0
		end
		gui.set_position(node, position)
		position.x = position.x + word.metrics.total_width
	end

	return nodes
end



return M