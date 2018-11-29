local color = require "richtext.color"
local utf8 = require("richtext.utf8")

local M = {}

local function parse_tag(tag, params)
	local settings = { tags = { [tag] = params } }
	if tag == "color" then
		settings.color = color.parse(params)
	elseif tag == "font" then
		settings.font = params
	elseif tag == "size" then
		settings.size = tonumber(params)
	elseif tag == "b" then
		settings.bold = true
	elseif tag == "i" then
		settings.italic = true
	elseif tag == "a" then
		settings.anchor = true
	elseif tag == "br" then
		settings.linebreak = true
	elseif tag == "img" then
		local texture, anim = params:match("(.-):(.*)")
		settings.image = {
			texture = texture,
			anim = anim
		}
	elseif tag == "spine" then
		local scene, anim = params:match("(.-):(.*)")
		settings.spine = {
			scene = scene,
			anim = anim
		}
	elseif tag == "nobr" then
		settings.nobr = true
	end

	return settings
end


-- add a single word to the list of words
local function add_word(text, settings, words)
	local data = { text = text }
	for k,v in pairs(settings) do
		data[k] = v
	end
	words[#words + 1] = data
end


-- split a line into words
local function split_line(line, settings, words)
	assert(line)
	assert(settings)
	assert(words)
	local ws_start, trimmed_text, ws_end = line:match("^(%s*)(.-)(%s*)$")
	if trimmed_text == "" then
		add_word(ws_start .. ws_end, settings, words)
	else
		local wi = #words
		for word in trimmed_text:gmatch("%S+") do
			add_word(word .. " ", settings, words)
		end
		local first = words[wi + 1]
		first.text = ws_start .. first.text
		local last = words[#words]
		last.text = utf8.sub(last.text, 1, utf8.len(last.text) - 1) .. ws_end
	end
end


-- split text
-- split by lines first
local function split_text(text, settings, words)
	assert(text)
	assert(settings)
	assert(words)
	-- special treatment of empty text with a linebreak <br/>
	if text == "" and settings.linebreak then
		add_word(text, settings, words)
		return
	end

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
		split_line(line, settings, words)
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


-- find tag in text
-- return the tag, tag params and any text before and after the tag
local function find_tag(text)
	assert(text)
	-- find tag, end if no tag was found
	local before_start_tag, tag, after_start_tag = text:match("(.-)(</?%S->)(.*)")
	if not before_start_tag or not tag or not after_start_tag then
		return nil
	end

	-- parse the tag, split into name and optional parameters
	local name, params, empty = tag:match("<(%a+)=?(%S-)(/?)>")

	-- empty tag, ie tag without content
	-- example <br/> and <img=texture:image/>
	if empty == "/" then
		return before_start_tag, name, params, "", after_start_tag
	end

	-- find end tag
	local inside_tag, after_end_tag = after_start_tag:match("(.-)</" .. name .. ">(.*)")
	-- no end tag, treat the rest of the text as inside the tag
	if not inside_tag then
		return before_start_tag, name, params, after_start_tag, ""
	-- end tag found
	else
		return before_start_tag, name, params, inside_tag, after_end_tag
	end
end


--- Parse the text into individual words
-- @param text The text to parse
-- @param word_settings Default settings for each word
-- @return List of all words
function M.parse(text, word_settings)
	assert(text)
	assert(word_settings)
	local all_words = {}
	repeat
		local before, tag, params, text_in_tag, after = find_tag(text)
		-- no more tags? Split and add the entire string
		if not tag then
			split_text(text, word_settings, all_words)
			break
		end

		-- split and add text before the encountered tag
		if before ~= "" then
			split_text(before, word_settings, all_words)
		end

		-- parse the tag and merge settings
		local tag_settings = parse_tag(tag, params)
		for k,v in pairs(word_settings) do
			tag_settings[k] = tag_settings[k] or v
		end
		for tag,params in pairs(word_settings.tags or {}) do
			tag_settings.tags[tag] = (params == "") and true or params
		end

		-- parse the text in the tag and add the words
		local inner_words = M.parse(text_in_tag, tag_settings)
		for _,word in ipairs(inner_words) do
			all_words[#all_words + 1] = word
		end

		text = after
	until text == ""
	return all_words
end

--- Get the length of a text, excluding any tags (except image and spine tags)
function M.length(text)
	return utf8.len(text:gsub("<img.-/>", " "):gsub("<spine.-/>", " "):gsub("<.->", ""))
end

return M
