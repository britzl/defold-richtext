## Defold RichText 5.1.1 [britzl released 2018-05-22]
FIX: Empty lines didn't get the proper text metrics for height. This caused problems with multiple consecutive linebreaks

## Defold RichText 5.1.0 [britzl released 2018-04-11]
NEW: Added `<nobr>` tag to let words overflow on a line without breaking

## Defold RichText 5.0.0 [britzl released 2018-04-11]
BREAKING CHANGE: The truncate() function updates the metrics of a node</br>
CHANGE: truncate() returns the last visible word

## Defold RichText 4.0.0 [britzl released 2018-03-27]
BREAKING CHANGE: All nodes now have inherit alpha set to true (requires Defold 1.2.124)

## Defold RichText 3.1.1 [britzl released 2018-03-19]
NEW: Tag parameters are now accessible per word:</br>
</br>
```</br>
<foo=bar>Defold</foo></br>
</br>
print(word.text, word.tags.foo) -- Defold  bar</br>
```

## Defold RichText 3.0.0 [britzl released 2018-03-08]
NEW: Added support for a new setting `image_pixel_grid_snap` to snap images to full pixels to avoid certain anti-aliasing effects</br>
CHANGE: Images are now affected by `<size>` tags

## Defold RichText 2.8.0 [britzl released 2018-03-05]
NEW: Added support for assigning layers to generated nodes to reduce draw calls.

## Defold RichText 2.7.0 [britzl released 2018-03-05]
NEW: Added support for `<spine=scene:anim\>` tags

## Defold RichText 2.6.0 [britzl released 2018-03-05]
NEW: Added `line_spacing` option to richtext.create() settings. This is a scaling value for line height. Set to 1.0 for default spacing. Less than 1.0 to decrease and more than 1.0 to increase spacing.

## Defold RichText 2.5.3 [britzl released 2018-03-05]
FIX: Text metrics for words with trailing space were wrong</br>
FIX: Line height was wrong after a line break

## Defold RichText 2.5.2 [britzl released 2018-03-02]
FIX: Make sure to properly handle \r\n (throw away all \r's)

## Defold RichText 2.5.1 [britzl released 2018-03-02]
FIX: `<img>` tags were broken

## Defold RichText 2.5.0 [britzl released 2018-03-02]
NEW: Added support for splitting a word into it's individual characters. Useful when creating character effects on specific words.</br>
FIX: Parsing of nested tags could result in empty "words"

## Defold RichText 2.4.1 [britzl released 2018-03-01]
FIX: Typo caused bug while parsing rich text

## Defold RichText 2.4.0 [britzl released 2018-03-01]
NEW: richtext.truncate(words, length)</br>
NEW: richtext.length(text)

## Defold RichText 2.3.0 [britzl released 2018-03-01]
NEW: Added support for `align` setting with accepted values `richtext.ALIGN_LEFT`, `richtext.ALIGN_CENTER` and `richtext.ALIGN_RIGHT`

## Defold RichText 2.2.0 [britzl released 2018-02-28]
NEW: Added support for linebreak tag <br/> (although normal linebreaks are still supported)</br>
CHANGE: Image tags can now be empty: <img=texture:image/>

## Defold RichText 2.1.0 [britzl released 2018-02-28]
NEW: Support for inline images using the `<img=texture:image></img>` tag

## Defold RichText 2.0.1 [britzl released 2018-02-28]
FIX: Solved issue with text metrics width measurement under certain conditions

## Defold RichText 2.0.0 [britzl released 2018-02-27]
CHANGE: `richtext.create()` now returns `words` and `metrics` instead of `nodes` and `metrics`</br>
NEW: Use `richtext.tagged(words, tag)` to get a list of all words matching a specific tag

## Defold RichText 1.4.0 [britzl released 2018-02-27]
NEW: richtext.create() now returns a metrics table with width and height as second return value</br>
FIX: Added documentation for default text color

## Defold RichText 1.3.0 [britzl released 2018-02-26]
NEW: Added support for linebreaks

## Defold RichText 1.2.0 [britzl released 2018-02-26]
FIX: Text measurement was incorrect if initial position was negative

## Defold RichText 1.1.0 [britzl released 2018-02-26]
CHANGE: Improved how space width is measured

## Defold RichText 1.0.1 [britzl released 2018-02-26]
FIX: Added library folder

## Defold RichText 1.0.0 [britzl released 2018-02-26]
First pre-release

