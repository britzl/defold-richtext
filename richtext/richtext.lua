local parser = require "richtext.parse"

local M = {}

local V3_ZERO = vmath.vector3(0)
local V3_ONE = vmath.vector3(1)

local function get_trailing_whitespace(text)
	return text:match("^.-(%s*)$") or ""
end


local function get_font(word, fonts)
	local font_settings = fonts[word.font]
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
		font = word.font
	end
	return font
end

--- Create rich text gui nodes from text
-- @param text The text to create rich text nodes from
-- @param font The default font
-- @param settings Optional settings table (refer to documentation for details)
-- @return words
-- @return metrics
function M.create(text, font, settings)
	assert(text)
	assert(font)
	settings = settings or {}
	settings.fonts = settings.fonts or {}
	settings.fonts[font] = settings.fonts[font] or { regular = hash(font) }
	settings.color = settings.color or vmath.vector4(1)
	settings.position = settings.position or vmath.vector3()

	-- cache length of a single space, per font
	local font_sizes = {}

	local word_settings = {
		color = settings.color,
		font = font,
		size = 1
	}
	local words = parser.parse(text, word_settings)
	local highest_word = 0
	local text_metrics = {
		width = 0,
		height = 0,
	}
	local position = vmath.vector3(settings.position)
	for _,word in pairs(words) do
		--print("word: [" .. word.text .. "]")

		-- get font to use based on word tags
		local font = get_font(word, settings.fonts)
		-- cache some font measurements for the current font
		if not font_sizes[font] then
			font_sizes[font] = {
				space = gui.get_text_metrics(font, " _").width - gui.get_text_metrics(font, "_").width,
				height = gui.get_text_metrics(font, "Ij").height,
			}
		end
		
		-- create and configure node
		local node
		if word.image then
			node = gui.new_box_node(V3_ZERO, V3_ZERO)
			gui.set_size_mode(node, gui.SIZE_MODE_AUTO)
			gui.set_texture(node, word.image.texture)
			gui.play_flipbook(node, hash(word.image.anim))

			-- get metrics of node based on image size
			local image_size = gui.get_size(node)
			word.metrics = {}
			word.metrics.total_width = image_size.x
			word.metrics.width = image_size.x
			word.metrics.height = image_size.y
		else
			node = gui.new_text_node(V3_ZERO, word.text)
			gui.set_font(node, font)
			gui.set_color(node, word.color)
			gui.set_scale(node, V3_ONE * (word.size or 1))

			-- get metrics of node with and without trailing whitespace
			word.metrics = gui.get_text_metrics_from_node(node)
			word.metrics.total_width = (word.metrics.width + #get_trailing_whitespace(word.text) * font_sizes[font].space) * word.size
			word.metrics.width = word.metrics.width * word.size
			word.metrics.height = word.metrics.height * word.size
		end
		
		word.node = node
		if settings.parent then
			gui.set_parent(node, settings.parent)
		end
		gui.set_pivot(node, gui.PIVOT_NW)

		-- move word to next row if it overflows the width
		local current_width = position.x - settings.position.x
		local width = current_width + word.metrics.width
		if settings.width and width > settings.width then
			position.y = position.y - highest_word
			position.x = settings.position.x
			highest_word = word.metrics.height
			text_metrics.width = math.max(text_metrics.width, current_width)
		else
			highest_word = math.max(highest_word, word.metrics.height)
			text_metrics.width = math.max(text_metrics.width, width)
		end

		-- position word
		gui.set_position(node, position)

		-- update text metrics height
		text_metrics.height = (settings.position.y - (position.y - highest_word))
		
		-- handle linebreak or advance on same line
		if word.linebreak then
			position.y = position.y - highest_word
			position.x = settings.position.x
			highest_word = font_sizes[font].height
		else
			position.x = position.x + word.metrics.total_width
		end

	end

	return words, text_metrics
end


--- Get all words with a specific tag
-- @param words The words to search (as received from richtext.create)
-- @param tag The tag to search for. Nil to search for words without a tag
-- @return Words matching the tag
function M.tagged(words, tag)
	local tagged = {}
	for i=1,#words do
		local word = words[i]
		if not tag and not word.tags then
			tagged[#tagged + 1] = word
		elseif word.tags and word.tags[tag] then
			tagged[#tagged + 1] = word
		end
	end
	return tagged
end


return M