local parser = require "richtext.parse"

local M = {}

M.ALIGN_CENTER = hash("ALIGN_CENTER")
M.ALIGN_LEFT = hash("ALIGN_LEFT")
M.ALIGN_RIGHT = hash("ALIGN_RIGHT")


local V3_ZERO = vmath.vector3(0)
local V3_ONE = vmath.vector3(1)

function deepcopy(orig)
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


-- position all words according to the line alignment and line width
-- the list of words will be empty after this function is called
local function position_words(words, line_width, position, settings)
	if settings.align == M.ALIGN_RIGHT then
		position.x = position.x - line_width
	elseif settings.align == M.ALIGN_CENTER then
		position.x = position.x - line_width / 2
	end

	for i=1,#words do
		local word = words[i]
		gui.set_position(word.node, position)
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
			count = count + (word.image and 1 or #word.text)
		end
		return count
	end
end


local function create_box_node(word)
	local node = gui.new_box_node(V3_ZERO, V3_ZERO)
	gui.set_size_mode(node, gui.SIZE_MODE_AUTO)
	gui.set_texture(node, word.image.texture)
	gui.play_flipbook(node, hash(word.image.anim))

	-- get metrics of node based on image size
	local image_size = gui.get_size(node)
	local metrics = {}
	metrics.total_width = image_size.x
	metrics.width = image_size.x
	metrics.height = image_size.y
	return node, metrics
end


local function create_text_node(word, font, font_cache)
	local node = gui.new_text_node(V3_ZERO, word.text)
	gui.set_font(node, font)
	gui.set_color(node, word.color)
	gui.set_scale(node, V3_ONE * (word.size or 1))

	-- get metrics of node with and without trailing whitespace
	local metrics = gui.get_text_metrics(font, word.text)
	metrics.width = metrics.width * word.size
	metrics.height = metrics.height * word.size

	-- get width of text with trailing whitespace included
	local trailing_whitespace = get_trailing_whitespace(word.text)
	if #trailing_whitespace > 0 then
		metrics.total_width = metrics.width + (#trailing_whitespace * get_space_width(font) * word.size)
	else
		metrics.total_width = metrics.width
	end
	return node, metrics
end


local function create_node(word, parent, font)
	local node, metrics
	if word.image then
		node, metrics = create_box_node(word)
	else
		node, metrics = create_text_node(word, font)
	end
	gui.set_pivot(node, gui.PIVOT_NW)
	gui.set_parent(node, parent)
	return node, metrics
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
	settings.align = settings.align or M.ALIGN_LEFT
	settings.fonts = settings.fonts or {}
	settings.fonts[font] = settings.fonts[font] or { regular = hash(font) }
	settings.color = settings.color or V3_ONE
	settings.position = settings.position or V3_ZERO
	settings.line_spacing = settings.line_spacing or 1

	-- default settings for a word
	-- will be assigned to each word unless tags override the values
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
		char_count = parser.length(text),
	}
	local line_words = {}
	local line_width = 0
	local position = vmath.vector3(settings.position)
	for i=1,#words do
		local word = words[i]
		--print("word: [" .. word.text .. "]")

		-- get font to use based on word tags
		local font = get_font(word, settings.fonts)
		
		-- create node and get metrics
		word.node, word.metrics = create_node(word, settings.parent, font)

		-- does the word fit on the line or does it overflow?
		local overflow = (settings.width and (line_width + word.metrics.width) > settings.width)
		if overflow then
			-- overflow, position the words that fit on the line
			position.x = settings.position.x
			position.y = settings.position.y - text_metrics.height
			position_words(line_words, line_width, position, settings)

			-- update text metrics
			text_metrics.width = math.max(text_metrics.width, line_width)
			text_metrics.height = text_metrics.height + (highest_word * settings.line_spacing)
			highest_word = word.metrics.height
			
			-- add the word that didn't fit to the next line instead
			line_width = word.metrics.total_width
			line_words[#line_words + 1] = word
		else
			-- the word fits on the line, add it and update text metrics
			line_width = line_width + word.metrics.total_width
			line_words[#line_words + 1] = word
			text_metrics.width = math.max(text_metrics.width, line_width)
			highest_word = math.max(highest_word, word.metrics.height)
		end

		-- handle line break
		if word.linebreak then
			-- position all words on the line up until the linebreak
			position.x = settings.position.x
			position.y = settings.position.y - text_metrics.height
			position_words(line_words, line_width, position, settings)

			-- update text metrics
			text_metrics.height = text_metrics.height + (highest_word * settings.line_spacing)
			highest_word = word.metrics.height
			line_width = 0
		end
	end

	-- position remaining words
	if #line_words > 0 then
		position.x = settings.position.x
		position.y = settings.position.y - text_metrics.height
		position_words(line_words, line_width, position, settings)
		text_metrics.height = text_metrics.height + highest_word
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


--- Truncate a set of words such that only a specific number of characters
-- and images are visible
-- @param words List of words to truncate
-- @param length Maximum number of characters to show
function M.truncate(words, length)
	assert(words)
	assert(length)
	local count = 0
	for i=1,#words do
		local word = words[i]
		local word_length = word.image and 1 or #word.text
		gui.set_enabled(word.node, count < length)
		if count < length and not word.image then
			-- should entire or part of word be visible?
			if count + word_length <= length then
				-- entire word
				gui.set_text(word.node, word.text)
			else
				-- partial word
				local overflow = (count + word_length) - length
				gui.set_text(word.node, word.text:sub(1, word_length - overflow))
			end
		end		
		count = count + word_length
	end
end


--- Split a word into it's characters
-- @param word The word to split
-- @return The individual characters
function M.characters(word)
	assert(word)

	-- exit early if word is a single character or empty
	if #word.text <= 1 then
		local char = deepcopy(word)
		char.node, char.metrics = create_node(char, parent, font)
		ui.set_position(char.node, gui.get_position(word.node))
		return { char }
	end
	
	-- split word into characters
	local parent = gui.get_parent(word.node)
	local font = gui.get_font(word.node)
	local chars = {}
	local chars_width = 0
	for i=1,#word.text do
		local char = deepcopy(word)
		chars[#chars + 1] = char
		char.text = word.text:sub(i,i)
		char.node, char.metrics = create_node(char, parent, font)
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