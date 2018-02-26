local M = {}

local function parse_color(c)
	local r,g,b,a = c:match("#(%x%x)(%x%x)(%x%x)(%x%x)")
	if r and g and b and a then
		return vmath.vector4(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255)
	end
	local r,g,b,a = c:match("(%d*%.?%d*),(%d*%.?%d*),(%d*%.?%d*),(%d*%.?%d*)")
	if r and g and b and a then
		return vmath.vector4(tonumber(r), tonumber(g), tonumber(b), tonumber(a))
	end
	return nil
end


local COLORS = {
	aqua = parse_color("#00ffffff"),
	black = parse_color("#000000ff"),
	blue = parse_color("#0000ffff"),
	brown = parse_color("#a52a2aff"),
	cyan = parse_color("#00ffffff"),
	darkblue = parse_color("#0000a0ff"),
	fuchsia = parse_color("#ff00ffff"),
	green = parse_color("#008000ff"),
	grey = parse_color("#808080ff"),
	lightblue = parse_color("#add8e6ff"),
	lime = parse_color("#00ff00ff"),
	magenta = parse_color("#ff00ffff"),
	maroon = parse_color("#800000ff"),
	navy = parse_color("#000080ff"),
	olive = parse_color("#808000ff"),
	orange = parse_color("#ffa500ff"),
	purple = parse_color("#800080ff"),
	red	 = parse_color("#ff0000ff"),
	silver = parse_color("#c0c0c0ff"),
	teal = parse_color("#008080ff"),
	white = parse_color("#ffffffff"),
	yellow = parse_color("#ffff00ff"),
}


local function parse_tag(tag, params)
	local settings = {}
	if tag == "color" then
		settings.color = COLORS[params]
		if not settings.color then
			settings.color = parse_color(params)
		end
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


local function add_word(text, settings, words)
	local data = { text = text }
	for k,v in pairs(settings) do
		data[k] = v
	end
	words[#words + 1] = data
end

local function split_and_add(text, settings, words)
	local ws_start, trimmed_text, ws_end = text:match("^(%s*)(.-)(%s*)$")
	if trimmed_text == "" then
		add_word(ws_start .. ws_end, settings, words)
	else
		local wi = #words
		for word in text:gmatch("%S+") do
			add_word(word .. " ", settings, words)
		end
		if #words > wi then
			local first = words[wi + 1]
			first.text = ws_start .. first.text
			local last = words[#words]
			last.text = last.text:sub(1,#last.text - 1) .. ws_end
		end
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
			split_and_add(s, parent_settings, all_words)
			break
		end

		-- split and add text before the encountered tag
		if before ~= "" then
			split_and_add(before, parent_settings, all_words)
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