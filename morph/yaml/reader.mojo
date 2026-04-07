"""YAML deserialization: YAML string -> struct.

Pure Mojo YAML parser supporting the subset needed for struct deserialization:
scalars (string, int, float, bool, null), block sequences (``- item``),
and indentation-based mappings for nested structs.
"""

from std.reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
    get_type_name,
    is_struct_type,
)
from std.builtin.rebind import trait_downcast, rebind
from std.collections import Optional, List, Dict

from morph.reflect import (
    INT_NAME,
    INT64_NAME,
    BOOL_NAME,
    STRING_NAME,
    FLOAT64_NAME,
    FLOAT32_NAME,
    OPT_INT_NAME,
    OPT_STRING_NAME,
    OPT_FLOAT64_NAME,
    OPT_BOOL_NAME,
    LIST_INT_NAME,
    LIST_STRING_NAME,
    LIST_FLOAT64_NAME,
    LIST_BOOL_NAME,
    _FLOAT64_SIMD_PREFIX,
    _FLOAT32_SIMD_PREFIX,
    _Base,
    Morphable,
)
from morph.rename import apply_rename


def from_yaml[
    T: Morphable,
    rename: StaticString = "none",
    skip_private: Bool = False,
](yaml_str: String) raises -> T:
    """Deserialize a YAML string into struct T.

    Parses YAML, converts to intermediate JSON, then delegates
    to the JSON reader for struct population.

    Parameters:
        T: The target struct type.
        rename: Naming strategy applied to field names.
        skip_private: If True, skip fields starting with ``_``.

    Args:
        yaml_str: A YAML string.

    Returns:
        A populated struct instance.
    """
    from morph.json.reader import read as _json_read

    var json = _yaml_to_json(yaml_str)
    return _json_read[T, rename=rename, skip_private=skip_private, default_if_missing=True](
        json
    )


# ---------------------------------------------------------------------------
# YAML -> JSON converter
# ---------------------------------------------------------------------------


def _yaml_to_json(yaml_str: String) raises -> String:
    """Convert a YAML string to a JSON string.

    Handles indentation-based mapping, block sequences, and scalars.
    """
    var lines = _split_lines(yaml_str)
    var cleaned = List[String]()
    var indents = List[Int]()

    for li in range(len(lines)):
        var raw = lines[li]
        var data = raw.as_bytes()

        var content_start = 0
        while content_start < len(data) and (
            data[content_start] == UInt8(ord(" "))
            or data[content_start] == UInt8(ord("\t"))
        ):
            content_start += 1

        if content_start >= len(data):
            continue
        if data[content_start] == UInt8(ord("#")):
            continue

        var content = _rstrip(_substr_bytes(data, content_start, len(data)))
        if len(content) == 0:
            continue

        var comment_pos = _find_unquoted_char(content, "#")
        if comment_pos >= 0:
            content = _rstrip(_substr_bytes(content.as_bytes(), 0, comment_pos))

        cleaned.append(content^)
        indents.append(content_start)

    return _parse_mapping(cleaned, indents, 0, len(cleaned), 0)


def _parse_mapping(
    lines: List[String],
    indents: List[Int],
    start: Int,
    end: Int,
    base_indent: Int,
) raises -> String:
    """Parse a YAML mapping into a JSON object string."""
    var out = String("{")
    var first = True
    var i = start

    while i < end:
        if indents[i] < base_indent:
            break
        if indents[i] > base_indent:
            i += 1
            continue

        var line = lines[i]
        var data = line.as_bytes()

        if len(data) > 0 and data[0] == UInt8(ord("-")):
            i += 1
            continue

        var colon_pos = _find_mapping_colon(line)
        if colon_pos < 0:
            i += 1
            continue

        var key = _rstrip(_substr_bytes(data, 0, colon_pos))
        var val_part = String("")
        if colon_pos + 1 < len(data):
            val_part = _lstrip(_substr_bytes(data, colon_pos + 1, len(data)))

        if not first:
            out += ","
        first = False
        out += '"' + key + '":'

        if len(val_part) > 0:
            var val_data = val_part.as_bytes()
            if val_data[0] == UInt8(ord("[")):
                out += _parse_flow_sequence(val_part)
            else:
                out += _yaml_scalar_to_json(val_part)
            i += 1
        else:
            var child_start = i + 1
            var child_end = child_start
            while child_end < end and indents[child_end] > base_indent:
                child_end += 1

            if child_start < child_end:
                var child_indent = indents[child_start]
                var child_line = lines[child_start]
                var child_data = child_line.as_bytes()

                if len(child_data) > 0 and child_data[0] == UInt8(ord("-")):
                    out += _parse_sequence(lines, indents, child_start, child_end, child_indent)
                else:
                    out += _parse_mapping(lines, indents, child_start, child_end, child_indent)
            else:
                out += '""'
            i = child_end

    out += "}"
    return out^


def _parse_sequence(
    lines: List[String],
    indents: List[Int],
    start: Int,
    end: Int,
    base_indent: Int,
) raises -> String:
    """Parse a YAML block sequence into a JSON array string."""
    var out = String("[")
    var first = True
    var i = start

    while i < end:
        if indents[i] < base_indent:
            break
        if indents[i] > base_indent:
            i += 1
            continue

        var line = lines[i]
        var data = line.as_bytes()

        if len(data) < 2 or data[0] != UInt8(ord("-")):
            i += 1
            continue

        var item_start = 1
        while item_start < len(data) and data[item_start] == UInt8(ord(" ")):
            item_start += 1

        var item = _substr_bytes(data, item_start, len(data))

        if not first:
            out += ","
        first = False
        out += _yaml_scalar_to_json(item)
        i += 1

    out += "]"
    return out^


def _parse_flow_sequence(val: String) raises -> String:
    """Parse a YAML flow sequence [a, b, c] to JSON array."""
    var data = val.as_bytes()
    if len(data) < 2:
        return "[]"

    var items = List[String]()
    var current = String("")
    var depth = 0
    var in_str = False
    var str_ch = UInt8(0)

    for i in range(len(data)):
        var ch = data[i]
        if in_str:
            current += chr(Int(ch))
            if ch == str_ch and (i == 0 or data[i - 1] != UInt8(ord("\\"))):
                in_str = False
            continue

        if ch == UInt8(ord('"')) or ch == UInt8(ord("'")):
            in_str = True
            str_ch = ch
            current += chr(Int(ch))
        elif ch == UInt8(ord("[")):
            depth += 1
            if depth > 1:
                current += "["
        elif ch == UInt8(ord("]")):
            depth -= 1
            if depth == 0:
                var stripped = _strip_str(current)
                if len(stripped) > 0:
                    items.append(stripped^)
                break
            else:
                current += "]"
        elif ch == UInt8(ord(",")) and depth == 1:
            var stripped = _strip_str(current)
            if len(stripped) > 0:
                items.append(stripped^)
            current = String("")
        else:
            current += chr(Int(ch))

    var out = String("[")
    for ii in range(len(items)):
        if ii > 0:
            out += ","
        out += _yaml_scalar_to_json(items[ii])
    out += "]"
    return out^


def _yaml_scalar_to_json(val: String) raises -> String:
    """Convert a YAML scalar value to JSON representation."""
    if val == "null" or val == "~" or val == "Null" or val == "NULL":
        return "null"
    if val == "true" or val == "True" or val == "TRUE" or val == "yes" or val == "on":
        return "true"
    if val == "false" or val == "False" or val == "FALSE" or val == "no" or val == "off":
        return "false"

    var data = val.as_bytes()
    if len(data) == 0:
        return "null"

    if data[0] == UInt8(ord('"')):
        return val

    if data[0] == UInt8(ord("'")):
        var content = String("")
        for i in range(1, len(data)):
            if data[i] == UInt8(ord("'")):
                break
            content += chr(Int(data[i]))
        return '"' + content + '"'

    var is_number = True
    var has_dot = False
    var start = 0
    if data[0] == UInt8(ord("-")) or data[0] == UInt8(ord("+")):
        start = 1
    if start >= len(data):
        is_number = False

    for i in range(start, len(data)):
        var ch = data[i]
        if ch == UInt8(ord(".")):
            if has_dot:
                is_number = False
                break
            has_dot = True
        elif ch < UInt8(ord("0")) or ch > UInt8(ord("9")):
            is_number = False
            break

    if is_number:
        return val

    var out = String('"')
    for i in range(len(data)):
        var ch = data[i]
        if ch == UInt8(ord('"')):
            out += '\\"'
        elif ch == UInt8(ord("\\")):
            out += "\\\\"
        else:
            out += chr(Int(ch))
    out += '"'
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


def _substr_bytes(data: Span[UInt8, _], start: Int, end: Int) -> String:
    var out = String("")
    for i in range(start, end):
        out += chr(Int(data[i]))
    return out^


def _rstrip(s: String) -> String:
    var data = s.as_bytes()
    var end = len(data)
    while end > 0 and (
        data[end - 1] == UInt8(ord(" "))
        or data[end - 1] == UInt8(ord("\t"))
        or data[end - 1] == UInt8(ord("\r"))
    ):
        end -= 1
    return _substr_bytes(data, 0, end)


def _lstrip(s: String) -> String:
    var data = s.as_bytes()
    var start = 0
    while start < len(data) and (
        data[start] == UInt8(ord(" ")) or data[start] == UInt8(ord("\t"))
    ):
        start += 1
    return _substr_bytes(data, start, len(data))


def _strip_str(s: String) -> String:
    return _lstrip(_rstrip(s))


def _find_mapping_colon(line: String) -> Int:
    """Find colon in 'key: value' that isn't inside a string."""
    var data = line.as_bytes()
    var in_str = False
    var str_ch = UInt8(0)
    for i in range(len(data)):
        var ch = data[i]
        if in_str:
            if ch == str_ch:
                in_str = False
            continue
        if ch == UInt8(ord('"')) or ch == UInt8(ord("'")):
            in_str = True
            str_ch = ch
            continue
        if ch == UInt8(ord(":")):
            if i + 1 < len(data) and data[i + 1] == UInt8(ord(" ")):
                return i
            if i + 1 == len(data):
                return i
    return -1


def _find_unquoted_char(s: String, target: String) -> Int:
    """Find target char outside of quotes."""
    var data = s.as_bytes()
    var t = target.as_bytes()[0]
    var in_str = False
    var str_ch = UInt8(0)
    for i in range(len(data)):
        var ch = data[i]
        if in_str:
            if ch == str_ch:
                in_str = False
            continue
        if ch == UInt8(ord('"')) or ch == UInt8(ord("'")):
            in_str = True
            str_ch = ch
            continue
        if ch == t:
            return i
    return -1
