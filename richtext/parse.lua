local color = require "richtext.color"
local utf8 = require("richtext.utf8")

local M = {}


local function shallow_copy(t)
	if not t then
		return {}
	end
	local new = {}
	for k,v in pairs(t) do
		new[k] = v
	end
	return new
end


-- get a table of word properties that the tag will modify
local function get_tag_word_properties(tag, params)
	local word_prop = { tags = { [tag] = params } }
	if tag == "color" then
		word_prop.color = color.parse(params)
	elseif tag == "font" then
		word_prop.font = params
	elseif tag == "size" then
		word_prop.size = tonumber(params)
	elseif tag == "b" then
		word_prop.bold = true
	elseif tag == "i" then
		word_prop.italic = true
	elseif tag == "a" then
		word_prop.anchor = true
	elseif tag == "br" then
		word_prop.linebreak = true
	elseif tag == "img" then
		local texture, anim = params:match("(.-):(.*)")
		word_prop.image = {
			texture = texture,
			anim = anim
		}
	elseif tag == "spine" then
		local scene, anim = params:match("(.-):(.*)")
		word_prop.spine = {
			scene = scene,
			anim = anim
		}
	elseif tag == "nobr" then
		word_prop.nobr = true
	end

	return word_prop
end


-- add a single word to the list of words
local function add_word(text, word_prop, words, dont_copy_data)
	local data
	if dont_copy_data then
		data = word_prop
	else
		data = shallow_copy(word_prop)
		data.text = text
	end
	words[#words + 1] = data
end


-- split a line into words and add each word to the list with the current word properties
local function split_line_and_add_words(line, word_prop, words)
	assert(line)
	assert(word_prop)
	assert(words)
	local ws_start, trimmed_text, ws_end = line:match("^(%s*)(.-)(%s*)$") -- Trim any whitespace off either end.
	if trimmed_text == "" then
		add_word(ws_start .. ws_end, word_prop, words)
	else
		local wi = #words
		for word in trimmed_text:gmatch("%S+") do
			add_word(word .. " ", word_prop, words)
		end
		local first = words[wi + 1]
		first.text = ws_start .. first.text
		local last = words[#words]
		last.text = utf8.sub(last.text, 1, utf8.len(last.text) - 1) .. ws_end
	end
end


-- split text
-- first split into lines, then split each line into words and add the words.
local function split_text_and_add_words(text, word_prop, words)
	if text == "" then
		return
	end
	assert(text)
	assert(word_prop)
	assert(words)

	-- we don't want to deal with \r\n, remove all \r
	text = text:gsub("\r", "")

	-- the Lua pattern expects the text to have a linebreak at the end
	local added_linebreak = false
	if text:sub(-1)~="\n" then
		added_linebreak = true
		text = text .. "\n"
	end

	-- split into lines
	for line in text:gmatch("(.-)\n") do
		split_line_and_add_words(line, word_prop, words)
		-- flag last word of a line as having a linebreak
		local last = words[#words]
		last.linebreak = true
	end

	-- remove the last linebreak if we manually added it above
	if added_linebreak then
		local last = words[#words]
		last.linebreak = false
	end
end


-- parse raw tag string into its name, params, and type flags
local function parse_tag(tag)
	local is_end_tag, name, params, is_empty_tag = tag:match("<(/?)(%a+)=?(%S-)(/?)>")
	is_end_tag = is_end_tag == "/" or false
	is_empty_tag = is_empty_tag == "/" or false
	return is_end_tag, name, params, is_empty_tag
end


-- apply a tag's effects the current styling (`current_word_prop`)
-- save the old state of the properties that were changed
-- add special "words" for empty tags (images, etc.) to the word list
local function apply_tag_to_state(tag, current_tags, tag_prop_history, current_word_prop, words)
	local is_end_tag, name, params, is_empty_tag = parse_tag(tag)
	assert(name, "Invalid tag sent to tag parser: '" .. tag .. "'.")

	if is_end_tag then
		-- find most recent tag with the same name and revert the properties it changed
		local found_matching_tag = false
		for i=#current_tags,1,-1 do
			local old_tag_name = current_tags[i]
			if old_tag_name == name then
				found_matching_tag = true
				table.remove(current_tags, i)
				-- reset changed properties
				local old_prop = tag_prop_history[i]
				for k,v in pairs(old_prop) do
					if k ~= "tags" then
						current_word_prop[k] = v or nil
					end
				end
				-- tags changed, need a new `tags` table
				current_word_prop.tags = shallow_copy(current_word_prop.tags)
				if old_prop.tags and old_prop.tags[name] then
					current_word_prop.tags[name] = old_prop.tags[name]
				else
					current_word_prop.tags[name] = nil
				end
				if not next(current_word_prop.tags) then
					current_word_prop.tags = nil
				end
				table.remove(tag_prop_history, i)
				break
			end
		end
		if not found_matching_tag then
			print("WARNING: Defold-Richtext Parser: Found extra end tag: '" .. tag .. "'.")
		end

	elseif is_empty_tag then -- br, img, or spine - no closing tag for these
		-- empty tags add their own special "word" and don't affect the current word properties
		-- make our own word table just for the custom word
		local word = shallow_copy(current_word_prop)
		word.text = ""
		-- add in properties from the tag
		local tag_word_prop = get_tag_word_properties(name, params)
		for k,v in pairs(tag_word_prop) do
			if k ~= "tags" then
				word[k] = v
			end
		end
		word.tags = { [name] = tag_word_prop.tags[name] }
		-- add the special word, using our word table directly instead of copying the current properties
		add_word("", word, words, true, true)

	else -- start tag
		local tag_word_prop = get_tag_word_properties(name, params)
		table.insert(current_tags, name)
		-- get a table to store the old properties (reusing old ones)
		local old_prop = tag_prop_history[#current_tags]
		if not old_prop then -- add a new table if one doesn't exist for this index
			old_prop = {}
			table.insert(tag_prop_history, old_prop)
		end
		for k,v in pairs(old_prop) do -- clear the old table if it existed
			old_prop[k] = nil
		end
		-- save old property values for the ones we are changing and set values in current_word_prop to the new ones.
		for k,v in pairs(tag_word_prop) do
			if k ~= "tags" then
				old_prop[k] = current_word_prop[k] or false -- false will be converted to nil when the tag ends
				current_word_prop[k] = v
			end
		end
		-- tags changed, need a new `tags` table
		current_word_prop.tags = shallow_copy(current_word_prop.tags)
		if current_word_prop.tags[name] then
			old_prop.tags = { [name] = current_word_prop.tags[name] }
		end
		current_word_prop.tags[name] = params
	end
end

--- Parse the text into individual words
-- @param text The text to parse
-- @param default_word_prop Default properties for each word
-- @return List of all words

-- Takes a string of tagged text and a table of default word properties.
-- Returns a table containing a sequence of word objects/tables, containing
--   the text and style properties for that word.
function M.parse(text, default_word_prop)
	assert(text)
	assert(default_word_prop)

	local all_words = {}
	local current_word_prop = shallow_copy(default_word_prop)
	local current_tags = {} -- list of currently active tag names, from oldest at the start to newest at the end
	local tag_prop_history = {} -- history of word properties as they were -before- the tag of the same index was applied

	repeat
		local txt_before_tag, tag, txt_after_tag = text:match("(.-)(</?%S->)(.*)")

		-- update the remaining text
		if tag then
			text = txt_after_tag
		else
			txt_before_tag = text
			text = ""
		end

		-- split `txt_before_tag` into words and add them to the word list, with the current styling
		split_text_and_add_words(txt_before_tag, current_word_prop, all_words)

		if not tag then
			break
		end

		-- apply the tag to the current_word_prop, to be used next iteration (empty tag "words" get added immediately)
		apply_tag_to_state(tag, current_tags, tag_prop_history, current_word_prop, all_words)
	until text == ""
	return all_words
end


--- Get the length of a text, excluding any tags (except image and spine tags)
function M.length(text)
	return utf8.len(text:gsub("<img.-/>", " "):gsub("<spine.-/>", " "):gsub("<.->", ""))
end

return M
