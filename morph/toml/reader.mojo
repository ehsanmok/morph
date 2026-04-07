"""TOML deserialization: TOML string -> struct.

Pure Mojo TOML parser supporting the subset needed for struct deserialization:
scalars, arrays, and [table] sections for nested structs.

Strategy: parse TOML into key-value pairs, build a JSON string, delegate
to the JSON reader. This reuses all existing type-handling logic.

TOML has no null -- missing keys keep defaults, Optional fields stay None.
"""

from std.collections import Optional, List

from morph.reflect import Morphable
from morph.rename import apply_rename


def from_toml[
    T: Morphable,
    rename: StaticString = "none",
    skip_private: Bool = False,
](toml_str: String) raises -> T:
    """Deserialize a TOML string into struct T.

    Parameters:
        T: The target struct type.
        rename: Naming strategy applied to field names.
        skip_private: If True, skip fields starting with ``_``.

    Args:
        toml_str: A TOML string.

    Returns:
        A populated struct instance.
    """
    from morph.json.reader import read as _json_read

    var json = _toml_to_json(toml_str)
    return _json_read[T, rename=rename, skip_private=skip_private, default_if_missing=True](
        json
    )


# ---------------------------------------------------------------------------
# TOML -> JSON converter
# ---------------------------------------------------------------------------


def _toml_to_json(toml_str: String) raises -> String:
    """Convert a TOML string to a JSON string.

    Parses key-value pairs and [table] headers, emitting JSON directly.
    Uses parallel lists for keys/values instead of Dict to avoid iteration issues.
    """
    var root_keys = List[String]()
    var root_vals = List[String]()

    var table_names = List[String]()
    var table_key_lists = List[List[String]]()
    var table_val_lists = List[List[String]]()

    var current_table_idx = -1

    var lines = _split_lines(toml_str)
    for li in range(len(lines)):
        var line = _strip(lines[li])

        if len(line) == 0 or line.as_bytes()[0] == UInt8(ord("#")):
            continue

        if line.as_bytes()[0] == UInt8(ord("[")):
            var end = _find_char(line, "]", 1)
            if end < 0:
                raise Error("Invalid TOML table header: " + line)
            table_names.append(_substr(line, 1, end))
            table_key_lists.append(List[String]())
            table_val_lists.append(List[String]())
            current_table_idx = len(table_names) - 1
            continue

        var eq_pos = _find_char(line, "=", 0)
        if eq_pos < 0:
            continue

        var key = _strip(_substr(line, 0, eq_pos))
        var val = _strip(_substr(line, eq_pos + 1, len(line)))
        var json_val = _toml_value_to_json(val)

        if current_table_idx >= 0:
            table_key_lists[current_table_idx].append(key^)
            table_val_lists[current_table_idx].append(json_val^)
        else:
            root_keys.append(key^)
            root_vals.append(json_val^)

    var out = String("{")
    var first = True

    for ki in range(len(root_keys)):
        if not first:
            out += ","
        first = False
        out += '"' + root_keys[ki] + '":' + root_vals[ki]

    for ti in range(len(table_names)):
        if not first:
            out += ","
        first = False

        var tname = table_names[ti]
        var dot_pos = _find_char(tname, ".", 0)
        var top_key: String
        if dot_pos >= 0:
            top_key = _substr(tname, 0, dot_pos)
        else:
            top_key = tname

        out += '"' + top_key + '":{'
        ref tkeys = table_key_lists[ti]
        ref tvals = table_val_lists[ti]
        var tfirst = True
        for tki in range(len(tkeys)):
            if not tfirst:
                out += ","
            tfirst = False
            out += '"' + tkeys[tki] + '":' + tvals[tki]
        out += "}"

    out += "}"
    return out^


def _toml_value_to_json(val: String) raises -> String:
    """Convert a TOML value string to its JSON equivalent."""
    if len(val) == 0:
        return '""'

    var first_byte = val.as_bytes()[0]

    if val == "true":
        return "true"
    if val == "false":
        return "false"

    if first_byte == UInt8(ord('"')):
        return _parse_toml_string(val)

    if first_byte == UInt8(ord("'")):
        return _parse_toml_literal_string(val)

    if first_byte == UInt8(ord("[")):
        return _parse_toml_array(val)

    return val


def _parse_toml_string(val: String) raises -> String:
    """Parse a TOML basic string (double-quoted) and return JSON string."""
    var data = val.as_bytes()
    if len(data) < 2:
        raise Error("Invalid TOML string: " + val)
    var out = String('"')
    var i = 1
    while i < len(data):
        var ch = data[i]
        if ch == UInt8(ord('"')):
            break
        if ch == UInt8(ord("\\")):
            i += 1
            if i < len(data):
                var esc = data[i]
                if esc == UInt8(ord("n")):
                    out += "\\n"
                elif esc == UInt8(ord("t")):
                    out += "\\t"
                elif esc == UInt8(ord("r")):
                    out += "\\r"
                elif esc == UInt8(ord("\\")):
                    out += "\\\\"
                elif esc == UInt8(ord('"')):
                    out += '\\"'
                else:
                    out += chr(Int(esc))
        else:
            out += chr(Int(ch))
        i += 1
    out += '"'
    return out^


def _parse_toml_literal_string(val: String) raises -> String:
    """Parse a TOML literal string (single-quoted) and return JSON."""
    var data = val.as_bytes()
    if len(data) < 2:
        raise Error("Invalid TOML literal string: " + val)
    var content = String("")
    for i in range(1, len(data)):
        if data[i] == UInt8(ord("'")):
            break
        content += chr(Int(data[i]))
    return '"' + content + '"'


def _parse_toml_array(val: String) raises -> String:
    """Parse a TOML array and return JSON array string."""
    var data = val.as_bytes()
    var depth = 0
    var items = List[String]()
    var current = String("")
    var in_string = False
    var str_char = UInt8(0)

    for i in range(len(data)):
        var ch = data[i]
        if in_string:
            current += chr(Int(ch))
            if ch == str_char and (i == 0 or data[i - 1] != UInt8(ord("\\"))):
                in_string = False
            continue

        if ch == UInt8(ord('"')) or ch == UInt8(ord("'")):
            in_string = True
            str_char = ch
            current += chr(Int(ch))
        elif ch == UInt8(ord("[")):
            depth += 1
            if depth > 1:
                current += "["
        elif ch == UInt8(ord("]")):
            depth -= 1
            if depth == 0:
                var stripped = _strip(current)
                if len(stripped) > 0:
                    items.append(stripped^)
                break
            else:
                current += "]"
        elif ch == UInt8(ord(",")) and depth == 1:
            var stripped = _strip(current)
            if len(stripped) > 0:
                items.append(stripped^)
            current = String("")
        else:
            current += chr(Int(ch))

    var out = String("[")
    for ii in range(len(items)):
        if ii > 0:
            out += ","
        out += _toml_value_to_json(items[ii])
    out += "]"
    return out^


# ---------------------------------------------------------------------------
# String helpers
# ---------------------------------------------------------------------------


def _split_lines(s: String) -> List[String]:
    var lines = List[String]()
    var current = String("")
    var data = s.as_bytes()
    for i in range(len(data)):
        if data[i] == UInt8(ord("\n")):
            lines.append(current^)
            current = String("")
        else:
            current += chr(Int(data[i]))
    if len(current) > 0:
        lines.append(current^)
    return lines^


def _strip(s: String) -> String:
    var data = s.as_bytes()
    var start = 0
    while start < len(data) and _is_ws(data[start]):
        start += 1
    var end = len(data)
    while end > start and _is_ws(data[end - 1]):
        end -= 1
    var out = String("")
    for i in range(start, end):
        out += chr(Int(data[i]))
    return out^


def _is_ws(ch: UInt8) -> Bool:
    return ch == UInt8(ord(" ")) or ch == UInt8(ord("\t")) or ch == UInt8(ord("\r"))


def _find_char(s: String, target: String, start: Int) -> Int:
    var data = s.as_bytes()
    var t = target.as_bytes()[0]
    for i in range(start, len(data)):
        if data[i] == t:
            return i
    return -1


def _substr(s: String, start: Int, end: Int) -> String:
    var data = s.as_bytes()
    var out = String("")
    for i in range(start, end):
        out += chr(Int(data[i]))
    return out^
