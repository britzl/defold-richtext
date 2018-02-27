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

### Important note about nested elements!
It is currently not possible to nest elements of the same tag. This means that the following will not work:

	This <color=green>will <color=red>not</color> work</color>

A workaround is to do like this instead:

	This <color=green>will</color> <color=red>not</color> <color=green>work</color>

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
|-----------|:-----------:|:---------------------------------:|
| aqua      | `#00ffffff` | ![](https://placehold.it/15/00ffff/000000?text=+) |
| black     | `#000000ff` | ![](https://placehold.it/15/000000/000000?text=+) |
| blue      | `#0000ffff` | ![](https://placehold.it/15/0000ff/000000?text=+) |
| brown     | `#a52a2aff` | ![](https://placehold.it/15/a52a2a/000000?text=+) |
| cyan      | `#00ffffff` | ![](https://placehold.it/15/00ffff/000000?text=+) |
| darkblue  | `#0000a0ff` | ![](https://placehold.it/15/0000a0/000000?text=+) |
| fuchsia   | `#ff00ffff` | ![](https://placehold.it/15/ff00ff/000000?text=+) |
| green     | `#008000ff` | ![](https://placehold.it/15/008000/000000?text=+) |
| grey      | `#808080ff` | ![](https://placehold.it/15/808080/000000?text=+) |
| lightblue | `#add8e6ff` | ![](https://placehold.it/15/add8e6/000000?text=+) |
| lime      | `#00ff00ff` | ![](https://placehold.it/15/00ff00/000000?text=+) |
| magenta   | `#ff00ffff` | ![](https://placehold.it/15/ff00ff/000000?text=+) |
| maroon    | `#800000ff` | ![](https://placehold.it/15/800000/000000?text=+) |
| navy      | `#000080ff` | ![](https://placehold.it/15/000080/000000?text=+) |
| olive     | `#808000ff` | ![](https://placehold.it/15/808000/000000?text=+) |
| orange    | `#ffa500ff` | ![](https://placehold.it/15/ffa500/000000?text=+) |
| purple    | `#800080ff` | ![](https://placehold.it/15/800080/000000?text=+) |
| red	    | `#ff0000ff` | ![](https://placehold.it/15/ff0000/000000?text=+) |
| silver    | `#c0c0c0ff` | ![](https://placehold.it/15/c0c0c0/000000?text=+) |
| teal      | `#008080ff` | ![](https://placehold.it/15/008080/000000?text=+) |
| white     | `#ffffffff` | ![](https://placehold.it/15/ffffff/000000?text=+) |
| yellow    | `#ffff00ff` | ![](https://placehold.it/15/ffff00/000000?text=+) |

## Line breaks
There is no need for the HTML `<br>` tag since line breaks (i.e. `\n`) are parsed and presented by the system.

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
			Nanum = {
				regular = hash("Nanum-Regular"),
			},
		},
		width = 400,
		position = vmath.vector3(0, 0, 0),
		parent = gui.get_node("parent"),
	}

	local text = "<size=3>RichText</size>Lorem <color=0,0.5,0,1>ipsum </color>dolor <color=red>sit </color><color=#ff00ffff>amet, </color><size=1.15><font=Nanum>consectetur </font></size>adipiscing elit. <b>Nunc </b>tincidunt <b><i>mattis</i> libero</b> <i>non viverra</i>. Nullam ornare accumsan rhoncus. Nunc placerat nibh a purus auctor, id scelerisque massa rutrum."

	self.nodes = richtext.create(text, "Roboto", settings)

This would result in the following output:

![](docs/example.png)

## API
### richtext.create(text, settings)
Creates rich text gui nodes from a text containing markup.

**PARAMETERS**
* `text` (string) - The text to create rich text from
* `font` (string) - Name of default font. Must match the name of a font in the gui scene.
* `settings` (table) - Optional table containing settings

The `settings` table can contain the following values:

* `width` (number) - Maximum width of a line of text. Omit this value to present the entire text on a single line
* `position` (vector3) - Top-left corner of the first letter of the text. Text will flow from left to right and top to bottom from this position
* `parent` (node) - GUI nodes will be attached to this node if specified.
* `fonts` (table) - Table with fonts, keyed on font name. Each entry should be a table with mappings to fonts for different font styles. Accepted keys are `regular`, `italic`, `bold`, `bold_italic`.
* `color` (vector4) - The default color of text. Will be white if not specified.

**RETURNS**
* `nodes` (table) - A table with all the gui text nodes used to create the text
