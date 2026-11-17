class_name DotChatWrap
extends RefCounted

## Word wrap for [DotChatWindow]: one line of coloured fragments in, rows that fit out.
##
## Words keep the colour of the fragment they came from, so a wrap inside what somebody
## said does not take the speaker's colour with it. A word wider than the box (a long URL,
## a held key) is broken by character so it stays inside the panel; no length limit applies.
## Falls back to the line as given when there is no font or no width to measure against.


static func wrap(parts: Array, font: Font, font_size: int, limit: float) -> Array:
	if font == null or limit <= 0.0:
		return [parts]

	var words := _words(parts)

	if words.is_empty():
		return [parts]

	var rows: Array = []
	var row: Array = []
	var row_width := 0.0

	for entry in words:
		var word := str(entry["text"])
		var word_width := _width(font, font_size, word)

		if word_width > limit:
			if not row.is_empty():
				rows.append(row)
				row = []
				row_width = 0.0

			word = _break_long(word, entry["colour"], font, font_size, limit, rows)
			word_width = _width(font, font_size, word)

		var piece := word if row.is_empty() else " " + word
		var piece_width := _width(font, font_size, piece)

		if not row.is_empty() and row_width + piece_width > limit:
			rows.append(row)
			row = []
			row_width = 0.0
			piece = word
			piece_width = word_width

		_append_piece(row, piece, entry["colour"])
		row_width += piece_width

	if not row.is_empty():
		rows.append(row)

	return rows


static func _width(font: Font, font_size: int, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


static func _words(parts: Array) -> Array[Dictionary]:
	var words: Array[Dictionary] = []

	for part in parts:
		var fragment: Dictionary = part
		var colour: Variant = fragment.get("colour", Color.WHITE)

		for word in str(fragment.get("text", "")).split(" ", false):
			words.append({"text": word, "colour": colour})

	return words


## Pushes every full chunk of [param word] onto [param rows] and returns the remainder.
static func _break_long(
	word: String, colour: Variant, font: Font, font_size: int, limit: float, rows: Array
) -> String:
	var chunk := ""

	for ch in word:
		var trial := chunk + ch

		if _width(font, font_size, trial) > limit and chunk != "":
			rows.append([{"text": chunk, "colour": colour}])
			chunk = ch
		else:
			chunk = trial

	return chunk


## Merged into the previous fragment when the colour matches, so a row of one person's
## words is one draw call rather than one per word.
static func _append_piece(row: Array, piece: String, colour: Variant) -> void:
	if not row.is_empty() and (row[row.size() - 1] as Dictionary)["colour"] == colour:
		var last: Dictionary = row[row.size() - 1]
		last["text"] = str(last["text"]) + piece
	else:
		row.append({"text": piece, "colour": colour})
