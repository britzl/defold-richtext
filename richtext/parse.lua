local color = require "richtext.color"

local M = {}

local function parse_tag(tag, params)
	local settings = {}
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
		last.text = last.text:sub(1,#last.text - 1) .. ws_end
	end
end

-- split text
-- split by lines first
local function split_text(text, settings, words)
	local added_linebreak = false
	if text:sub(-1)~="\n" then
		added_linebreak = true
		text = text .. "\n"
	end

	for line in text:gmatch("(.-)\n") do
		split_line(line, settings, words)
		local last = words[#words]
		last.linebreak = true
	end

	if added_linebreak then
		local last = words[#words]
		last.linebreak = false
	end
end

local function find_tag(s)
	-- find tag, end if no tag was found
	local before_start_tag, tag, after_start_tag = s:match("(.-)(<[^/]%S->)(.*)")
	if not before_start_tag or not tag or not after_start_tag then
		return nil
	end
	
	-- parse the tag, split into name and optional parameters
	local name, params = tag:match("<(%a+)=?(%S*)>")

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

function M.parse(s, parent_settings)
	parent_settings = parent_settings or {}
	local all_words = {}
	while true do
		local before, tag, params, text, after = find_tag(s)
		-- no more tags? Split and add the entire string
		if not tag then
			split_text(s, parent_settings, all_words)
			break
		end

		-- split and add text before the encountered tag
		if before ~= "" then
			split_text(before, parent_settings, all_words)
		end

		-- parse the tag and merge it with settings for the parent tag
		local tag_settings = parse_tag(tag, params)
		for k,v in pairs(parent_settings) do
			tag_settings[k] = v
		end

		-- parse the text inside the tag and add the words
		local inner_words = M.parse(text, tag_settings)
		for _,word in ipairs(inner_words) do
			all_words[#all_words + 1] = word
		end
		
		s = after
	end
	return all_words
end






return M