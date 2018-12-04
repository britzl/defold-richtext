local parser = require "richtext.parse"
local utf8 =require("richtext.utf8")

local M = {}

M.ALIGN_CENTER = hash("ALIGN_CENTER")
M.ALIGN_LEFT = hash("ALIGN_LEFT")
M.ALIGN_RIGHT = hash("ALIGN_RIGHT")


local V3_ZERO = vmath.vector3(0)
local V3_ONE = vmath.vector3(1)

local id_counter = 0

local function new_id(prefix)
	id_counter = id_counter + 1
	return hash((prefix or "") .. tostring(id_counter))
end

local function round(v)
	if type(v) == "number" then
		return math.floor(v + 0.5)
	else
		return vmath.vector3(math.floor(v.x + 0.5), math.floor(v.y + 0.5), math.floor(v.z + 0.5))
	end
end


local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end


local function get_trailing_whitespace(text)
	return text:match("^.-(%s*)$") or ""
end


local function get_space_width(font)
	return gui.get_text_metrics(font, " _").width - gui.get_text_metrics(font, "_").width
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


local function get_layer(word, layers)
	local node = word.node
	if word.image then
		return layers.images[gui.get_texture(node)]
	elseif word.spine then
		return layers.spinescenes[gui.get_spine_scene(node)]
	end
	return layers.fonts[gui.get_font(node)]
end


-- position all words according to the line alignment and line width
-- the list of words will be empty after this function is called
local function position_words(words, line_width, line_height, position, settings)
	if settings.align == M.ALIGN_RIGHT then
		position.x = position.x - line_width
	elseif settings.align == M.ALIGN_CENTER then
		position.x = position.x - line_width / 2
	end

	for i=1,#words do
		local word = words[i]
		-- align spine animations to bottom of line since
		-- spine animations ignore pivot (always PIVOT_S)
		if word.spine then
			position.y = position.y - line_height
			gui.set_position(word.node, position)
			position.y = position.y + line_height
		elseif word.image and settings.image_pixel_grid_snap then
			gui.set_position(word.node, round(position))
		else
			gui.set_position(word.node, position)
		end
		position.x = position.x + word.metrics.total_width
		words[i] = nil
	end
end


--- Get the length of a text ignoring any tags except image tags
-- which are treated as having a length of 1
-- @param text String with text or a list of words (from richtext.create)
-- @return Length of text
function M.length(text)
	assert(text)
	if type(text) == "string" then
		return parser.length(text)
	else
		local count = 0
		for i=1,#text do
			local word = text[i]
			local is_text_node = not word.image and not word.spine
			count = count + (is_text_node and utf8.len(word.text) or 1)
		end
		return count
	end
end


local function create_box_node(word)
	local node = gui.new_box_node(V3_ZERO, V3_ZERO)
	gui.set_id(node, new_id("box"))
	gui.set_size_mode(node, gui.SIZE_MODE_AUTO)
	gui.set_texture(node, word.image.texture)
	gui.set_scale(node, vmath.vector3(word.size))
	gui.play_flipbook(node, hash(word.image.anim))

	-- get metrics of node based on image size
	local size = gui.get_size(node)
	local metrics = {}
	metrics.total_width = size.x * word.size
	metrics.width = size.x * word.size
	metrics.height = size.y * word.size
	return node, metrics
end


local function create_spine_node(word)
	local node = gui.new_spine_node(V3_ZERO, word.spine.scene)
	gui.set_id(node, new_id("spine"))
	gui.set_size_mode(node, gui.SIZE_MODE_AUTO)
	gui.set_scale(node, vmath.vector3(word.size))
	gui.play_spine_anim(node, word.spine.anim, gui.PLAYBACK_LOOP_FORWARD)

	local size = gui.get_size(node)
	local metrics = {}
	metrics.total_width = size.x
	metrics.width = size.x
	metrics.height = size.y
	return node, metrics
end


local function get_text_metrics(word, font, text)
	text = text or word.text
	font = font or word.font

	local metrics
	if utf8.len(text) == 0 then
		metrics = gui.get_text_metrics(font, "|")
		metrics.width = 0
		metrics.total_width = 0
	else
		metrics = gui.get_text_metrics(font, text)
		metrics.width = metrics.width * word.size
		metrics.height = metrics.height * word.size

		-- get width of text with trailing whitespace included
		local trailing_whitespace = get_trailing_whitespace(word.text)
		if #trailing_whitespace > 0 then
			metrics.total_width = metrics.width + (#trailing_whitespace * get_space_width(font) * word.size)
		else
			metrics.total_width = metrics.width
		end
	end
	return metrics
end


local function create_text_node(word, font)
	assert(font)
	local node = gui.new_text_node(V3_ZERO, word.text)
	gui.set_id(node, new_id("textnode"))
	gui.set_font(node, font)
	gui.set_color(node, word.color)
	gui.set_outline(node, word.color)
	gui.set_scale(node, V3_ONE * word.size)

	local metrics = get_text_metrics(word, font)
	gui.set_size_mode(node, gui.SIZE_MODE_MANUAL)
	gui.set_size(node, vmath.vector3(metrics.width, metrics.height, 0))
	return node, metrics
end


local function create_node(word, parent, font)
	local node, metrics
	if word.image then
		node, metrics = create_box_node(word)
	elseif word.spine then
		node, metrics = create_spine_node(word)
	else
		node, metrics = create_text_node(word, font)
	end
	gui.set_pivot(node, gui.PIVOT_NW)
	gui.set_parent(node, parent)
	gui.set_inherit_alpha(node, true)
	return node, metrics
end



--- Create rich text gui nodes from text
-- @param text The text to create rich text nodes from
-- @param font The default font
-- @param settings Optional settings table (refer to documentation for details)
-- @return words
-- @return metrics
function M.create(text, font, settings)
	assert(text, "You must provide a text")
	assert(font, "You must provide a font")
	settings = settings or {}
	settings.align = settings.align or M.ALIGN_LEFT
	settings.fonts = settings.fonts or {}
	settings.fonts[font] = settings.fonts[font] or { regular = hash(font) }
	settings.layers = settings.layers or {}
	settings.layers.fonts = settings.layers.fonts or {}
	settings.layers.images = settings.layers.images or {}
	settings.layers.spinescenes = settings.layers.spinescenes or {}
	settings.color = settings.color or V3_ONE
	settings.position = settings.position or V3_ZERO
	settings.line_spacing = settings.line_spacing or 1
	settings.image_pixel_grid_snap = settings.image_pixel_grid_snap or false

	-- default settings for a word
	-- will be assigned to each word unless tags override the values
	local word_settings = {
		color = settings.color,
		font = font,
		size = 1
	}
	local words = parser.parse(text, word_settings)
	local text_metrics = {
		width = 0,
		height = 0,
		char_count = parser.length(text),
	}
	local line_words = {}
	local line_width = 0
	local line_height = 0
	local position = vmath.vector3(settings.position)
	for i=1,#words do
		local word = words[i]
		--print("word: [" .. word.text .. "]")

		-- get font to use based on word tags
		local font_for_word = get_font(word, settings.fonts)

		-- create node and get metrics
		word.node, word.metrics = create_node(word, settings.parent, font_for_word)

		-- assign layer
		local layer = get_layer(word, settings.layers)
		if layer then
			gui.set_layer(word.node, layer)
		end

		-- does the word fit on the line or does it overflow?
		local overflow = (settings.width and (line_width + word.metrics.width) > settings.width)
		if overflow and not word.nobr then
			-- overflow, position the words that fit on the line
			position.x = settings.position.x
			position.y = settings.position.y - text_metrics.height
			position_words(line_words, line_width, line_height, position, settings)

			-- add the word that didn't fit to the next line instead
			line_words[#line_words + 1] = word

			-- update text metrics
			text_metrics.width = math.max(text_metrics.width, line_width)
			text_metrics.height = text_metrics.height + (line_height * settings.line_spacing)
			line_width = word.metrics.total_width
			line_height = word.metrics.height
		else
			-- the word fits on the line, add it and update text metrics
			line_width = line_width + word.metrics.total_width
			line_height = math.max(line_height, word.metrics.height)
			line_words[#line_words + 1] = word
			text_metrics.width = math.max(text_metrics.width, line_width)
		end

		-- handle line break
		if word.linebreak then
			-- position all words on the line up until the linebreak
			position.x = settings.position.x
			position.y = settings.position.y - text_metrics.height
			position_words(line_words, line_width, line_height, position, settings)

			-- update text metrics
			text_metrics.height = text_metrics.height + (line_height * settings.line_spacing)
			line_height = word.metrics.height
			line_width = 0
		end
	end

	-- position remaining words
	if #line_words > 0 then
		position.x = settings.position.x
		position.y = settings.position.y - text_metrics.height
		position_words(line_words, line_width, line_height, position, settings)
		text_metrics.height = text_metrics.height + line_height
	end

	return words, text_metrics
end


--- Detected click/touch events on words with an anchor tag
-- These words act as "hyperlinks" and will generate a message when clicked
-- @param words Words to search for anchor tags
-- @param action The action table from on_input
-- @return true if a word was clicked, otherwise false
function M.on_click(words, action)
	for i=1,#words do
		local word = words[i]
		if word.anchor and gui.pick_node(word.node, action.x, action.y) then
			if word.tags and word.tags.a then
				local message = {
					node_id = gui.get_id(word.node),
					text = word.text,
					x = action.x, y = action.y,
					screen_x = action.screen_x, screen_y = action.screen_y
				}
				msg.post("#", word.tags.a, message)
				return true
			end
		end
	end
	return false
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


--- Truncate a set of words such that only a specific number of characters
-- and images are visible
-- @param words List of words to truncate
-- @param length Maximum number of characters to show
function M.truncate(words, length)
	assert(words)
	assert(length)
	local count = 0
	local last_visible_word = nil
	for i=1, #words do
		local word = words[i]
		local is_text_node = not word.image and not word.spine
		local word_length = is_text_node and utf8.len(word.text) or 1
		local visible = count < length
		last_visible_word = visible and word or last_visible_word
		gui.set_enabled(word.node, visible)
		if count < length and is_text_node then
			local text = word.text
			-- partial word?
			if count + word_length > length then
				local overflow = (count + word_length) - length
				text = utf8.sub(word.text, 1, word_length - overflow)
			end
			gui.set_text(word.node, text)
			word.metrics = get_text_metrics(word, word.font, text)
		end
		count = count + word_length
	end
	return last_visible_word
end


--- Split a word into it's characters
-- @param word The word to split
-- @return The individual characters
function M.characters(word)
	assert(word)

	local parent = gui.get_parent(word.node)
	local font = gui.get_font(word.node)
	local layer = gui.get_layer(word.node)

	-- exit early if word is a single character or empty
	if utf8.len(word.text) <= 1 then
		local char = deepcopy(word)
		char.node, char.metrics = create_node(char, parent, font)
		gui.set_position(char.node, gui.get_position(word.node))
		gui.set_layer(char.node, layer)
		return { char }
	end

	-- split word into characters
	local chars = {}
	local chars_width = 0
	for i = 1, utf8.len(word.text) do
		local char = deepcopy(word)
		chars[#chars + 1] = char
		char.text = utf8.sub(word.text, i, i)
		char.node, char.metrics = create_node(char, parent, font)
		gui.set_layer(char.node, layer)
		chars_width = chars_width + char.metrics.width
	end

	-- position each character
	-- take into account that the sum of the width of the individual
	-- characters differ from the width of the entire word
	local position = gui.get_position(word.node)
	local spacing = (word.metrics.width - chars_width) / (#chars - 1)
	for i=1,#chars do
		local char = chars[i]
		gui.set_position(char.node, position)
		position.x = position.x + char.metrics.width + spacing
	end

	return chars
end


return M
