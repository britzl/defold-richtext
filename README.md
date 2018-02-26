# Defold-RichText
Defold-RichText is a system to create styled text based on an HTML inspired markup language.

# Installation
You can use RichText in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/). Open your game.project file and in the dependencies field under project add:

https://github.com/britzl/defold-richtext/archive/master.zip

Or point to the ZIP file of a [specific release](https://github.com/britzl/defold-richtext/releases).

# Markup format
The markup format is HTML inspired, but not intended to be fully compatible with standard HTML. Just like in HTML the idea is that sections of text can be enclosed in matching start and end tags:

	This is a <b>bold</b> statement!

This is a <b>bold</b> statement!

## Nested elements
Nested elements are supported. Use this to give a section of text a combination of styles:

	This is a <b>bold <i>italic</i></b> statement!

This is a <b>bold <i>italic</i></b> statement!

## Supported tags
The following tags are supported:

| Tag   | Description                                    | Example                               |
|-------|------------------------------------------------|---------------------------------------|
| b     | The text should be bold                        | `<b>Foobar</b>`                       |
| i     | The text should be italic                      | `<i>Foobar</i>`                       |
| size  | Change text size, relative to default size     | `<size="2">Twice as large</size>`     |
| color | Change text color                              | `<color=red>Foobar</color>`           |
|       |                                                | `<color=1.0,0.5,0,1.0>Foobar</color>` |
|       |                                                | `<color=#ff00ffff>Foobar</color>`     |
| font  | Change font                                    | `<font=MyCoolFont>Foobar</font>`      |

### Named colors
The following named colors are supported:

| Name      | Hex value   | Swatch                            |
|-----------|-------------|-----------------------------------|
| aqua      | `#00ffffff` | [<font color="#00ffff">■■■■■■</font>] |
| black     | `#000000ff` | [<font color="#000000">■■■■■■</font>] |
| blue      | `#0000ffff` | [<font color="#0000ff">■■■■■■</font>] |
| brown     | `#a52a2aff` | [<font color="#a52a2a">■■■■■■</font>] |
| cyan      | `#00ffffff` | [<font color="#00ffff">■■■■■■</font>] |
| darkblue  | `#0000a0ff` | [<font color="#0000a0">■■■■■■</font>] |
| fuchsia   | `#ff00ffff` | [<font color="#ff00ff">■■■■■■</font>] |
| green     | `#008000ff` | [<font color="#008000">■■■■■■</font>] |
| grey      | `#808080ff` | [<font color="#808080">■■■■■■</font>] |
| lightblue | `#add8e6ff` | [<font color="#add8e6">■■■■■■</font>] |
| lime      | `#00ff00ff` | [<font color="#00ff00">■■■■■■</font>] |
| magenta   | `#ff00ffff` | [<font color="#ff00ff">■■■■■■</font>] |
| maroon    | `#800000ff` | [<font color="#800000">■■■■■■</font>] |
| navy      | `#000080ff` | [<font color="#000080">■■■■■■</font>] |
| olive     | `#808000ff` | [<font color="#808000">■■■■■■</font>] |
| orange    | `#ffa500ff` | [<font color="#ffa500">■■■■■■</font>] |
| purple    | `#800080ff` | [<font color="#800080">■■■■■■</font>] |
| red	    | `#ff0000ff` | [<font color="#ff0000">■■■■■■</font>] |
| silver    | `#c0c0c0ff` | [<font color="#c0c0c0">■■■■■■</font>] |
| teal      | `#008080ff` | [<font color="#008080">■■■■■■</font>] |
| white     | `#ffffffff` | [<font color="#ffffff">■■■■■■</font>] |
| yellow    | `#ffff00ff` | [<font color="#ffff00">■■■■■■</font>] |

# Usage
The RichText library will create gui text nodes representing the markup in the text passed to the library. It will search for tags and split the entire text into words, where each word contains additional meta-data that is used to create and configure text nodes. This means that the library will create as many text nodes as there are words in the text. Example:

	local settings = {
		fonts = {
			Roboto = {
				regular = hash("Roboto-Regular"),
				italic = hash("Roboto-Italic"),
				bold = hash("Roboto-Bold"),
				bold_italic = hash("Roboto-BoldItalic"),
			},
			VeraMo = {
				regular = hash("VeraMo"),
			},
			Nanum = {
				regular = hash("Nanum-Regular"),
			},
		},
		width = 400,
		position = vmath.vector3(0, 0, 0),
		parent = gui.get_node("parent"),
	}
	self.nodes = richtext.create("Lorem <b>ipsum</b> dolor <color=red>sit</color> amet.", "Roboto", settings)

### richtext.create(text, settings)
Creates rich text gui nodes from a text containing markup.

** PARAMETERS **
* `text` (string) - The text to create rich text from
* `font` (string) - Name of default font. Must match the name of a font in the gui scene.
* `settings` (table) - Optional table containing settings

The `settings` table can contain the following values:

* `width` (number) - Maximum width of a line of text. Omit this value to present the entire text on a single line
* `position` (vector3) - Top-left corner of the first letter of the text. Text will flow from left to right and top to bottom from this position
* `parent` (node) - GUI nodes will be attached to this node if specified.
* `fonts` (table) - Table with fonts, keyed on font name. Each entry should be a table with mappings to fonts for different font styles. Accepted keys are `regular`, `italic`, `bold`, `bold_italic`.

** PARAMETERS **
* `nodes` (table) - A table with all the gui text nodes used to create the text
