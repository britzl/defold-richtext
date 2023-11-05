local parser = require "richtext.parse"
local utf8 =require("richtext.utf8")

local M = {}

M.ALIGN_CENTER = hash("ALIGN_CENTER")
M.ALIGN_LEFT = hash("ALIGN_LEFT")
M.ALIGN_RIGHT = hash("ALIGN_RIGHT")
M.ALIGN_JUSTIFY = hash("ALIGN_JUSTIFY")

M.VALIGN_TOP = hash("VALIGN_TOP")
M.VALIGN_MIDDLE = hash("VALIGN_MIDDLE")
M.VALIGN_BOTTOM = hash("VALIGN_BOTTOM")


local V4_ZERO = vmath.vector4(0)
local V4_ONE = vmath.vector4(1)

local V3_ZERO = vmath.vector3(0)
local V3_ONE = vmath.vector3(1)

-- temporary v3s (to avoid creating a lot of short-lived v3s)
local size_v3 = vmath.vector3()
local position_v3 = vmath.vector3()

local id_counter = 0

local function new_id(prefix)
	id_counter = id_counter + 1
	return hash((prefix or "") .. tostring(id_counter))
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


local function get_font(word, fonts, default_font)
	local font_settings = fonts[(word.tags.font or word.font) or default_font]
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
		font = default_font
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

-- compare two words and check that they have the same size, color, font and tags
local function compare_words(one, two)
	if one == nil
	or two == nil
	or one.size ~= two.size
	or one.color ~= two.color
	or one.shadow ~= two.shadow
	or one.outline ~= two.outline
	or one.font ~= two.font then
		return false
	end
	local one_tags, two_tags = one.tags, two.tags
	if one_tags == two_tags then
		return true
	end
	if one_tags == nil or two_tags == nil then
		return false
	end
	for k, v in pairs(one_tags) do
		if two_tags[k] ~= v then
			return false
		end
	end
	for k, v in pairs(two_tags) do
		if one_tags[k] ~= v then
			return false
		end
	end
	return true
end


-- position all words according to the line alignment and line width
-- the list of words will be empty after this function is called
local function position_words(words, line_width, line_height, position, settings)
	if settings.align == M.ALIGN_RIGHT then
		position.x = position.x - line_width
	elseif settings.align == M.ALIGN_CENTER then
		position.x = position.x - line_width / 2
	end

	local spacing = 0
	if settings.align == M.ALIGN_JUSTIFY then
		local words_width = 0
		local word_count = 0
		for i=1,#words do
			local word = words[i]
			if word.metrics.total_width > 0 then
				words_width = words_width + word.metrics.total_width
				word_count = word_count + 1
			end
		end
		if word_count > 1 then
			spacing = (settings.width - words_width) / (word_count - 1)
		end
	end
	for i=1,#words do
		local word = words[i]
		-- align spine animations to bottom of line since
		-- spine animations ignore pivot (always PIVOT_S)
		if word.spine then
			position.y = position.y - line_height
			word.position_x = position.x
			word.position_y = position.y
			position.y = position.y + line_height
		elseif word.image and settings.image_pixel_grid_snap then
			word.position_x = math.floor(position.x + 0.5)
			word.position_y = math.floor(position.y + 0.5)
		else
			word.position_x = position.x
			word.position_y = position.y
		end
		position.x = position.x + word.metrics.total_width + spacing
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
	position_v3.x = word.position_x or 0
	position_v3.y = word.position_y or 0
	if not word.node then
		word.node = gui.new_box_node(position_v3, V3_ZERO)
	else
		gui.set_position(word.node, position_v3)
	end

	local node = word.node
	local word_image = word.image
	local image_width = word_image.width
	local image_height = word_image.height
	gui.set_id(node, new_id("box"))
	if image_width then
		gui.set_size_mode(node, gui.SIZE_MODE_MANUAL)
		size_v3.x = image_width
		size_v3.y = image_height
		size_v3.z = 0
		gui.set_size(node, size_v3)
	else
		gui.set_size_mode(node, gui.SIZE_MODE_AUTO)
	end
	gui.set_texture(node, word.image.texture)
	local word_size = word.size
	size_v3.x = word_size
	size_v3.y = word_size
	size_v3.z = word_size
	gui.set_scale(node, size_v3)
	gui.play_flipbook(node, hash(word.image.anim))
end


local function create_spine_node(word)
	position_v3.x = word.position_x or 0
	position_v3.y = word.position_y or 0
	if not word.node then
		word.node = gui.new_spine_node(position_v3, word.spine.scene)
	else
		gui.set_position(word.node, position_v3)
	end

	local node = word.node
	gui.set_id(node, new_id("spine"))
	gui.set_size_mode(node, gui.SIZE_MODE_AUTO)
	gui.set_scale(node, vmath.vector3(word.size))
	gui.play_spine_anim(node, word.spine.anim, gui.PLAYBACK_LOOP_FORWARD)
end

local function get_text_metrics(word, text)
	text = text or word.text

	local metrics
	if utf8.len(text) == 0 then
		metrics = gui.get_text_metrics(word.font, "|")
		metrics.width = 0
		metrics.total_width = 0
		metrics.height = metrics.height * word.size
	else
		metrics = gui.get_text_metrics(word.font, text)
		metrics.width = metrics.width * word.size
		metrics.total_width = metrics.width
		metrics.height = metrics.height * word.size
	end

	return metrics
end

local function get_box_metrics(word)
	-- there is no way to measure an image without actually creating the node first
	create_box_node(word)

	-- get metrics of node based on image size
	local size = gui.get_size(word.node)
	local metrics = {}
	metrics.total_width = size.x * word.size
	metrics.width = size.x * word.size
	metrics.height = size.y * word.size
	return metrics
end

local function get_spine_metrics(word)
	-- there is no way to measure a spine model without actually creating the node first
	create_spine_node(word)
	local size = gui.get_size(word.node)
	local metrics = {}
	metrics.total_width = size.x
	metrics.width = size.x
	metrics.height = size.y
	return metrics
end



local function create_text_node(word)
	position_v3.x = word.position_x or 0
	position_v3.y = word.position_y or 0
	if not word.node then
		word.node = gui.new_text_node(position_v3, word.text)
	else
		gui.set_position(word.node, position_v3)
	end

	local node = word.node
	gui.set_id(node, new_id("textnode"))
	gui.set_font(node, word.font)
	gui.set_color(node, word.color)
	if word.shadow then gui.set_shadow(node, word.shadow) end
	if word.outline then gui.set_outline(node, word.outline) end
	gui.set_scale(node, V3_ONE * word.size)

	local metrics = get_text_metrics(word)
	gui.set_size_mode(node, gui.SIZE_MODE_MANUAL)
	gui.set_size(node, vmath.vector3(metrics.width / word.size, metrics.height / word.size, 0))

	word.metrics = metrics
end


local function create_node(word, parent)
	if word.image then
		create_box_node(word)
	elseif word.spine then
		create_spine_node(word)
	else
		create_text_node(word)
	end
	gui.set_parent(word.node, parent)
	gui.set_inherit_alpha(word.node, true)
end


local function measure_node(word, previous_word)
	if word.image then
		word.metrics = get_box_metrics(word)
		return word.metrics
	elseif word.spine then
		word.metrics = get_spine_metrics(word)
		return word.metrics
	elseif word.text then
		-- text node
		word.metrics = get_text_metrics(word)
		local combined_metrics = previous_word and get_text_metrics(word, previous_word.text .. word.text)
		return word.metrics, combined_metrics
	else
		error("Unknown word type")
	end
end

local function split_word(word, max_width)
	local one = deepcopy(word)
	local two = deepcopy(word)
	local text = word.text
	local metrics = get_text_metrics(one)
	local char_count = utf8.len(text)
	local split_index = math.floor(char_count * (max_width / metrics.total_width))
	local rest = ""
	while split_index > 1 do
		one.text = utf8.sub(text, 1, split_index)
		one.linebreak = true
		metrics = get_text_metrics(one)
		if metrics.width <= max_width then
			rest = utf8.sub(text, split_index + 1)
			break
		end
		split_index = split_index - 1
	end
	two.text = rest
	return one, two
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
	settings.valign = settings.valign or M.VALIGN_TOP
	settings.size = settings.size or 1
	settings.fonts = settings.fonts or {}
	settings.fonts[font] = settings.fonts[font] or { regular = hash(font) }
	settings.layers = settings.layers or {}
	settings.layers.fonts = settings.layers.fonts or {}
	settings.layers.images = settings.layers.images or {}
	settings.layers.spinescenes = settings.layers.spinescenes or {}
	settings.color = settings.color or V4_ONE
	settings.shadow = settings.shadow or V4_ZERO
	settings.outline = settings.outline or V4_ZERO
	settings.position = settings.position or V3_ZERO
	settings.line_spacing = settings.line_spacing or 1
	settings.paragraph_spacing = settings.paragraph_spacing or 0.5
	settings.image_pixel_grid_snap = settings.image_pixel_grid_snap or false
	settings.combine_words = settings.combine_words or false
	settings.dryrun = settings.dryrun or false
	if settings.align == M.ALIGN_JUSTIFY and not settings.width then
		error("Width must be specified if text should be justified")
	end

	local line_increment_before = 0
	local line_increment_after = 1
	local pivot = gui.PIVOT_NW
	if settings.valign == M.VALIGN_MIDDLE then
		line_increment_before = 0.5
		line_increment_after = 0.5
		pivot = gui.PIVOT_W
	elseif settings.valign == M.VALIGN_BOTTOM then
		line_increment_before = 1
		line_increment_after = 0
		pivot = gui.PIVOT_SW
	end

	-- default settings for a word
	-- will be assigned to each word unless tags override the values
	local word_settings = {
		color = settings.color,
		shadow = settings.shadow,
		outline = settings.outline,
		size = settings.size
	}
	local words = parser.parse(text, word_settings)

	-- assign the correct font to each word, based on tags
	for i=1,#words do
		local word = words[i]
		word.font = get_font(word, settings.fonts, font)
	end

	local text_metrics = {
		width = 0,
		height = 0,
		char_count = 0,
		img_count = 0,
		spine_count = 0,
	}
	local line_words = {}
	local line_width = 0
	local line_height = 0
	local paragraph_spacing = 0
	local position = vmath.vector3(settings.position)
	local word_count = #words
	local i = 1
	repeat
		local word = words[i]
		if word.image then
			text_metrics.img_count = text_metrics.img_count + 1
		elseif word.spine then
			text_metrics.spine_count = text_metrics.spine_count + 1
		else
			text_metrics.char_count = text_metrics.char_count + parser.length(word.text)
		end

		-- get the previous word, so we can combine
		local previous_word
		if settings.combine_words then
			previous_word = line_words[#line_words]
			if not compare_words(previous_word, word) then
				previous_word = nil
			end
		end

		-- get metrics first
		local word_metrics, combined_metrics = measure_node(word, previous_word)

		-- check if the line overflows due to this word
		local overflow = false
		if settings.width then
			if combined_metrics then
				overflow = (line_width - previous_word.metrics.total_width + combined_metrics.width) > settings.width
			else
				overflow = (line_width + word_metrics.width)  > settings.width
			end

			-- if we overflow and the word is longer than a full line we
			-- split the word and add the first part to the current line
			if overflow and word.text and word_metrics.width > settings.width then
				local remaining_width = settings.width - line_width
				local one, two = split_word(word, remaining_width)
				word_metrics, combined_metrics = measure_node(one, previous_word)
				words[i] = one
				word = one
				table.insert(words, i + 1, two)
				word_count = word_count + 1
				overflow = false
			end
		end

		if overflow and not word.nobr then
			-- overflow, position the words that fit on the line
			text_metrics.height = text_metrics.height + (line_height * line_increment_before * settings.line_spacing)
			position.x = settings.position.x
			position.y = settings.position.y - text_metrics.height
			position_words(line_words, line_width, line_height, position, settings)

			-- add the word that didn't fit to the next line instead
			line_words[#line_words + 1] = word

			-- update text metrics
			text_metrics.width = math.max(text_metrics.width, line_width)
			text_metrics.height = text_metrics.height + (line_height * line_increment_after * settings.line_spacing) + paragraph_spacing
			line_width = word_metrics.total_width
			line_height = word_metrics.height
			paragraph_spacing = 0
		else
			-- the word fits on the line, add it and update text metrics
			if combined_metrics then
				line_width = line_width - previous_word.metrics.total_width + combined_metrics.total_width
				line_height = math.max(line_height, combined_metrics.height)
				previous_word.text = previous_word.text .. word.text
				previous_word.metrics = combined_metrics
				word.delete = true
			else
				line_width = line_width + word_metrics.total_width
				line_height = math.max(line_height, word_metrics.height)
				line_words[#line_words + 1] = word
			end
			text_metrics.width = math.max(text_metrics.width, line_width)
		end

		if word.paragraph_end then
			local paragraph = word.paragraph
			if paragraph then
				paragraph_spacing = math.max(
					paragraph_spacing,
					line_height * (paragraph == true and settings.paragraph_spacing or paragraph)
				)
			end
		end

		-- handle line break
		if word.linebreak then
			-- position all words on the line up until the linebreak
			text_metrics.height = text_metrics.height + (line_height * line_increment_before * settings.line_spacing)
			position.x = settings.position.x
			position.y = settings.position.y - text_metrics.height
			position_words(line_words, line_width, line_height, position, settings)

			-- update text metrics
			text_metrics.height = text_metrics.height + (line_height * line_increment_after * settings.line_spacing) + paragraph_spacing
			line_height = word_metrics.height
			line_width = 0
			paragraph_spacing = 0
		end

		i = i + 1
	until i > word_count

	-- position remaining words
	if #line_words > 0 then
		text_metrics.height = text_metrics.height + (line_height * line_increment_before * settings.line_spacing)
		position.x = settings.position.x
		position.y = settings.position.y - text_metrics.height
		position_words(line_words, line_width, line_height, position, settings)
		text_metrics.height = text_metrics.height + (line_height * line_increment_after * settings.line_spacing)
	end

	-- create the nodes (unless doing a dry-run)
	if not settings.dryrun then
		for i=1,word_count do
			local word = words[i]
			if not word.delete then
				create_node(word, settings.parent)
				gui.set_pivot(word.node, pivot)
				local layer = get_layer(word, settings.layers)
				if layer then
					gui.set_layer(word.node, layer)
				end
			end
		end
	end

	-- compact words table
	-- delete words (and associated nodes if they exist)
	local j = 1
	for i = 1, word_count do
		local word = words[i]
		if not word.delete then
			words[i] = nil
			words[j] = word
			j = j + 1
		else
			words[i] = nil
			if word.node then
				gui.delete_node(word.node)
			end
		end
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
					screen_x = action.screen_x, screen_y = action.screen_y,
					tags = word.tags
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
-- @param options Optional table with truncate options. Available options are: words
-- @return Last visible word
function M.truncate(words, length, options)
	assert(words)
	assert(length)
	local last_visible_word = nil
	if options and options.words then
		for i=1, #words do
			local word = words[i]
			local visible = i <= length
			if visible then
				last_visible_word = word
			end
			gui.set_enabled(word.node, visible)
		end
	else
		local count = 0
		for i=1, #words do
			local word = words[i]
			local is_text_node = not word.image and not word.spine
			local word_length = is_text_node and utf8.len(word.text) or 1
			local visible = count < length
			if visible then
				last_visible_word = word
			end
			gui.set_enabled(word.node, visible)
			if count < length and is_text_node then
				local text = word.text
				-- partial word?
				if count + word_length > length then
					-- remove overflowing characters from word
					local overflow = (count + word_length) - length
					text = utf8.sub(word.text, 1, word_length - overflow)
				end
				gui.set_text(word.node, text)
				word.metrics = get_text_metrics(word, text)
			end
			count = count + word_length
		end
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
	local pivot = gui.get_pivot(word.node)

	local word_length = utf8.len(word.text)

	-- exit early if word is a single character or empty
	if word_length <= 1 then
		local char = deepcopy(word)
		char.node = nil
		create_node(char, parent)
		gui.set_pivot(char.node, pivot)
		gui.set_position(char.node, gui.get_position(word.node))
		gui.set_layer(char.node, layer)
		return { char }
	end

	-- split word into characters
	local chars = {}
	local position = gui.get_position(word.node)
	local position_x = position.x

	for i = 1, word_length do
		local char = deepcopy(word)
		char.node = nil
		chars[#chars + 1] = char
		char.text = utf8.sub(word.text, i, i)
		create_node(char, parent)
		gui.set_layer(char.node, layer)
		gui.set_pivot(char.node, pivot)

		local sub_metrics = get_text_metrics(word, utf8.sub(word.text, 1, i))
		position.x = position_x + sub_metrics.width - char.metrics.width
		gui.set_enabled(char.node, true)
		gui.set_position(char.node, position)
	end

	return chars
end

---Removes the gui nodes created by rich text
function M.remove(words)
	assert(words)

	local num = #words
	for i=1,num do
		gui.delete_node(words[i].node)
	end
end

function M.plaintext(words)
	local s = ""
	for i=1,#words do
		local word = words[i]
		if word.text then
			s = s .. word.text
			if word.linebreak then
				s = s .. "\n"
			end
		end
	end
	return s
end


return M
