"""Minimal JSON value type and parsing for morph.

Self-contained JSON value type, parser, and serializer.
Scalars are stored directly; arrays and objects store raw JSON
strings and parse lazily on access.
"""

from std.collections import List


struct Null(Writable):
    """Represents JSON null."""

    def __init__(out self):
        pass

    def write_to[W: Writer](self, mut writer: W):
        writer.write("null")


struct Value(Copyable):
    """A JSON value: null, bool, int, float, string, array, or object."""

    var _type: Int
    var _bool: Bool
    var _int: Int64
    var _float: Float64
    var _string: String
    var _raw: String
    var _keys: List[String]
    var _count: Int

    def __init__(out self, null: Null):
        self._type = 0
        self._bool = False
        self._int = 0
        self._float = 0.0
        self._string = String()
        self._raw = String()
        self._keys = List[String]()
        self._count = 0

    def __init__(out self, none: NoneType):
        self._type = 0
        self._bool = False
        self._int = 0
        self._float = 0.0
        self._string = String()
        self._raw = String()
        self._keys = List[String]()
        self._count = 0

    def __init__(out self, b: Bool):
        self._type = 1
        self._bool = b
        self._int = 0
        self._float = 0.0
        self._string = String()
        self._raw = String()
        self._keys = List[String]()
        self._count = 0

    def __init__(out self, i: Int):
        self._type = 2
        self._bool = False
        self._int = Int64(i)
        self._float = 0.0
        self._string = String()
        self._raw = String()
        self._keys = List[String]()
        self._count = 0

    def __init__(out self, i: Int64):
        self._type = 2
        self._bool = False
        self._int = i
        self._float = 0.0
        self._string = String()
        self._raw = String()
        self._keys = List[String]()
        self._count = 0

    def __init__(out self, f: Float64):
        self._type = 3
        self._bool = False
        self._int = 0
        self._float = f
        self._string = String()
        self._raw = String()
        self._keys = List[String]()
        self._count = 0

    def __init__(out self, s: String):
        self._type = 4
        self._bool = False
        self._int = 0
        self._float = 0.0
        self._string = s
        self._raw = String()
        self._keys = List[String]()
        self._count = 0

    def copy(self) -> Self:
        var v = Value(Null())
        v._type = self._type
        v._bool = self._bool
        v._int = self._int
        v._float = self._float
        v._string = self._string
        v._raw = self._raw
        v._keys = self._keys.copy()
        v._count = self._count
        return v^

    def is_null(self) -> Bool:
        return self._type == 0

    def is_bool(self) -> Bool:
        return self._type == 1

    def is_int(self) -> Bool:
        return self._type == 2

    def is_float(self) -> Bool:
        return self._type == 3

    def is_string(self) -> Bool:
        return self._type == 4

    def is_array(self) -> Bool:
        return self._type == 5

    def is_object(self) -> Bool:
        return self._type == 6

    def bool_value(self) -> Bool:
        return self._bool

    def int_value(self) -> Int64:
        return self._int

    def float_value(self) -> Float64:
        return self._float

    def string_value(self) -> String:
        return self._string

    def raw_json(self) -> String:
        if self._type == 0:
            return "null"
        elif self._type == 1:
            return "true" if self._bool else "false"
        elif self._type == 2:
            return String(self._int)
        elif self._type == 3:
            return String(self._float)
        elif self._type == 4:
            return escape_string(self._string)
        return self._raw

    def object_keys(self) -> List[String]:
        return self._keys.copy()

    def get(self, key: String) raises -> String:
        """Get a field's raw JSON string from a JSON object."""
        if not self.is_object():
            raise Error("get() requires a JSON object")
        var found = False
        for i in range(len(self._keys)):
            if self._keys[i] == key:
                found = True
                break
        if not found:
            raise Error("Key '" + key + "' not found")
        return _extract_field_value(self._raw, key)

    def array_items(self) raises -> List[Value]:
        """Parse array elements lazily and return as Values."""
        if not self.is_array():
            raise Error("array_items() requires a JSON array")
        var result = List[Value]()
        if self._count == 0:
            return result^
        for i in range(self._count):
            var elem_str = _extract_array_element(self._raw, i)
            var elem = _parse_value(elem_str)
            result.append(elem^)
        return result^


def _make_array(raw: String, count: Int) -> Value:
    var v = Value(Null())
    v._type = 5
    v._raw = raw
    v._count = count
    return v^


def _make_object(raw: String, var keys: List[String]) -> Value:
    var v = Value(Null())
    v._type = 6
    v._raw = raw
    v._count = len(keys)
    v._keys = keys^
    return v^


# ── String escaping ─────────────────────────────────────────────


def escape_string(s: String) -> String:
    """Escape a string for JSON output, adding surrounding quotes.

    Builds the result incrementally using String += so that no null terminators
    are embedded between appended substrings. ASCII-printable bytes (0x20–0x7F)
    use chr(); multi-byte UTF-8 sequences are appended as StringSlice views via
    s[byte=i:i+n] — zero-copy and no unsafe constructor needed since the
    original String s is already valid UTF-8.
    """
    var out = String('"')
    var n = s.byte_length()
    var data = s.as_bytes()
    var i = 0
    while i < n:
        var c = data[i]
        if c == UInt8(ord('"')):
            out += '\\"'
            i += 1
        elif c == UInt8(ord("\\")):
            out += "\\\\"
            i += 1
        elif c == UInt8(ord("\n")):
            out += "\\n"
            i += 1
        elif c == UInt8(ord("\r")):
            out += "\\r"
            i += 1
        elif c == UInt8(ord("\t")):
            out += "\\t"
            i += 1
        elif c < 0x20:
            out += "\\u00"
            out += _hex_digit(Int(c >> 4))
            out += _hex_digit(Int(c & 0x0F))
            i += 1
        elif c >= 0x80:
            # Multi-byte UTF-8 sequence: append as a StringSlice view of the
            # original String. String.__iadd__ accepts StringSlice directly so
            # no allocation or unsafe constructor is needed.
            var seq_len: Int
            if c >= 0xF0:
                seq_len = min(4, n - i)
            elif c >= 0xE0:
                seq_len = min(3, n - i)
            else:
                seq_len = min(2, n - i)
            out += s[byte = i : i + seq_len]
            i += seq_len
        else:
            out += chr(Int(c))
            i += 1
    out += '"'
    return out^


def _hex_digit(n: Int) -> String:
    if n < 10:
        return chr(ord("0") + n)
    return chr(ord("a") + n - 10)


def _hex_byte(n: Int) -> UInt8:
    """Return the ASCII byte for a hex nibble (0–15)."""
    if n < 10:
        return UInt8(ord("0") + n)
    return UInt8(ord("a") + n - 10)


# ── JSON parser (recursive descent) ─────────────────────────────


def loads(s: String) raises -> Value:
    """Parse a JSON string into a Value."""
    return _parse_value(s)


def _parse_value(s: String) raises -> Value:
    """Parse a raw JSON value string into a Value."""
    var data = s.as_bytes()
    var n = len(data)
    if n == 0:
        raise Error("Empty JSON value")

    var i = 0
    while i < n and (
        data[i] == UInt8(ord(" "))
        or data[i] == UInt8(ord("\t"))
        or data[i] == UInt8(ord("\n"))
        or data[i] == UInt8(ord("\r"))
    ):
        i += 1

    if i >= n:
        raise Error("Empty JSON value")

    var c = data[i]

    if c == UInt8(ord("n")):
        return Value(Null())
    if c == UInt8(ord("t")):
        return Value(True)
    if c == UInt8(ord("f")):
        return Value(False)

    if c == UInt8(ord('"')):
        var start = i + 1
        var end = start
        var has_escapes = False
        while end < n:
            if data[end] == UInt8(ord("\\")):
                has_escapes = True
                end += 2
                continue
            if data[end] == UInt8(ord('"')):
                break
            end += 1
        if not has_escapes:
            return Value(String(from_utf8_lossy=s[byte=start:end].as_bytes()))
        return Value(_unescape(s, start, end))

    if c == UInt8(ord("-")) or (c >= UInt8(ord("0")) and c <= UInt8(ord("9"))):
        var num_str = String()
        var is_float = False
        while i < n:
            var d = data[i]
            if (
                d == UInt8(ord("-"))
                or d == UInt8(ord("+"))
                or (d >= UInt8(ord("0")) and d <= UInt8(ord("9")))
            ):
                num_str += chr(Int(d))
            elif (
                d == UInt8(ord("."))
                or d == UInt8(ord("e"))
                or d == UInt8(ord("E"))
            ):
                num_str += chr(Int(d))
                is_float = True
            else:
                break
            i += 1
        if is_float:
            return Value(atof(num_str))
        else:
            return Value(atol(num_str))

    if c == UInt8(ord("[")):
        var count = _count_array_elements(s)
        return _make_array(s, count)

    if c == UInt8(ord("{")):
        var keys = _extract_object_keys(s)
        return _make_object(s, keys^)

    raise Error("Invalid JSON value: " + s)


def _unescape(s: String, start: Int, end: Int) -> String:
    """Unescape a JSON string between start and end indices.

    Builds the result incrementally using String +=. Escape sequences are
    converted to their character equivalents. Raw bytes >= 0x80 (multi-byte
    UTF-8 sequences) are appended as StringSlice views via s[byte=i:i+1],
    which avoids reinterpreting raw bytes as code points and requires no
    unsafe constructor. \\uXXXX code points are converted with chr() which
    is correct because the decoded value IS a Unicode code point.
    """
    var out = String()
    var data = s.as_bytes()
    var i = start
    while i < end:
        if data[i] == UInt8(ord("\\")) and i + 1 < end:
            var next_c = data[i + 1]
            if next_c == UInt8(ord('"')):
                out += '"'
            elif next_c == UInt8(ord("\\")):
                out += "\\"
            elif next_c == UInt8(ord("/")):
                out += "/"
            elif next_c == UInt8(ord("n")):
                out += "\n"
            elif next_c == UInt8(ord("r")):
                out += "\r"
            elif next_c == UInt8(ord("t")):
                out += "\t"
            elif next_c == UInt8(ord("b")):
                out += chr(8)
            elif next_c == UInt8(ord("f")):
                out += chr(12)
            elif next_c == UInt8(ord("u")) and i + 5 < end:
                var cp = _parse_hex4(data, i + 2)
                if cp >= 0xD800 and cp <= 0xDBFF and i + 11 < end:
                    if data[i + 6] == UInt8(ord("\\")) and data[i + 7] == UInt8(
                        ord("u")
                    ):
                        var low = _parse_hex4(data, i + 8)
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                        i += 6
                # chr() is correct here: cp is a valid Unicode code point,
                # not a raw byte; chr() produces the correct UTF-8 string.
                out += chr(cp)
                i += 4
            else:
                out += chr(Int(next_c))
            i += 2
        else:
            var b = data[i]
            if b >= 0x80:
                # Multi-byte UTF-8 continuation byte: append as StringSlice
                # view of the original String so the raw byte is NOT
                # reinterpreted as a Unicode code point by chr().
                out += s[byte = i : i + 1]
                i += 1
            else:
                out += chr(Int(b))
                i += 1
    return out^


def _parse_hex4(data: Span[UInt8, _], start: Int) -> Int:
    """Parse 4 hex digits at data[start:start+4] to an integer."""
    var result = 0
    for j in range(4):
        var c = Int(data[start + j])
        result <<= 4
        if c >= ord("0") and c <= ord("9"):
            result += c - ord("0")
        elif c >= ord("a") and c <= ord("f"):
            result += c - ord("a") + 10
        elif c >= ord("A") and c <= ord("F"):
            result += c - ord("A") + 10
    return result


# ── Pretty printer ───────────────────────────────────────────────


def dumps(v: Value, indent: String = "") -> String:
    """Serialize a Value to a JSON string, optionally with indentation."""
    if indent == "":
        return v.raw_json()
    return _format(v, indent, 0)


def _format(v: Value, indent: String, depth: Int) -> String:
    if v.is_null():
        return "null"
    elif v.is_bool():
        return "true" if v.bool_value() else "false"
    elif v.is_int():
        return String(v.int_value())
    elif v.is_float():
        return String(v.float_value())
    elif v.is_string():
        return escape_string(v.string_value())
    elif v.is_array():
        try:
            var items = v.array_items()
            if len(items) == 0:
                return "[]"
            var out = String("[\n")
            for i in range(len(items)):
                if i > 0:
                    out += ",\n"
                out += indent * (depth + 1)
                out += _format(items[i], indent, depth + 1)
            out += "\n" + indent * depth + "]"
            return out^
        except:
            return v.raw_json()
    elif v.is_object():
        try:
            var keys = v.object_keys()
            if len(keys) == 0:
                return "{}"
            var out = String("{\n")
            for i in range(len(keys)):
                if i > 0:
                    out += ",\n"
                out += indent * (depth + 1)
                out += escape_string(keys[i])
                out += ": "
                var val_str = v.get(keys[i])
                var val = _parse_value(val_str)
                out += _format(val, indent, depth + 1)
            out += "\n" + indent * depth + "}"
            return out^
        except:
            return v.raw_json()
    return "null"


# ── Field extraction helpers ──────────────────────────────────────


def get_string(json: Value, key: String) raises -> String:
    """Extract a string field from a JSON object."""
    var raw = json.get(key)
    var parsed = _parse_value(raw)
    if not parsed.is_string():
        raise Error("Field '" + key + "' expected string")
    return parsed.string_value()


def get_int(json: Value, key: String) raises -> Int:
    """Extract an int field from a JSON object."""
    var raw = json.get(key)
    var parsed = _parse_value(raw)
    if not parsed.is_int():
        raise Error("Field '" + key + "' expected int")
    return Int(parsed.int_value())


def get_bool(json: Value, key: String) raises -> Bool:
    """Extract a bool field from a JSON object."""
    var raw = json.get(key)
    var parsed = _parse_value(raw)
    if not parsed.is_bool():
        raise Error("Field '" + key + "' expected bool")
    return parsed.bool_value()


def get_float(json: Value, key: String) raises -> Float64:
    """Extract a float field from a JSON object."""
    var raw = json.get(key)
    var parsed = _parse_value(raw)
    if parsed.is_float():
        return parsed.float_value()
    elif parsed.is_int():
        return Float64(parsed.int_value())
    raise Error("Field '" + key + "' expected number")


# ── Raw JSON extraction (byte-level) ──────────────────────────────


def _extract_field_value(raw: String, key: String) raises -> String:
    """Extract a field's raw JSON value from a JSON object string."""
    var data = raw.as_bytes()
    var i = 0
    var n = len(data)

    while i < n and (
        data[i] == UInt8(ord("{"))
        or data[i] == UInt8(ord(" "))
        or data[i] == UInt8(ord("\t"))
        or data[i] == UInt8(ord("\n"))
    ):
        i += 1

    while i < n:
        while i < n and (
            data[i] == UInt8(ord(" "))
            or data[i] == UInt8(ord("\t"))
            or data[i] == UInt8(ord("\n"))
        ):
            i += 1
        if i >= n:
            break

        if data[i] == UInt8(ord('"')):
            i += 1
            var key_start = i
            while i < n and data[i] != UInt8(ord('"')):
                if data[i] == UInt8(ord("\\")):
                    i += 2
                else:
                    i += 1
            var found_key = String(
                from_utf8_lossy=raw[byte=key_start:i].as_bytes()
            )
            i += 1

            while i < n and (
                data[i] == UInt8(ord(" "))
                or data[i] == UInt8(ord("\t"))
                or data[i] == UInt8(ord("\n"))
                or data[i] == UInt8(ord(":"))
            ):
                i += 1

            if found_key == key:
                return _extract_json_value(raw, i)
            else:
                _ = _extract_json_value(raw, i)
                while (
                    i < n
                    and data[i] != UInt8(ord(","))
                    and data[i] != UInt8(ord("}"))
                ):
                    i += 1
                if i < n and data[i] == UInt8(ord(",")):
                    i += 1
        else:
            i += 1

    raise Error("Key not found in JSON object")


def _extract_json_value(raw: String, start: Int) raises -> String:
    """Extract a single JSON value starting at a byte position."""
    var data = raw.as_bytes()
    var i = start
    var n = len(data)

    while i < n and (
        data[i] == UInt8(ord(" "))
        or data[i] == UInt8(ord("\t"))
        or data[i] == UInt8(ord("\n"))
    ):
        i += 1

    if i >= n:
        raise Error("Unexpected end of JSON")

    var c = data[i]

    if c == UInt8(ord('"')):
        var vs = i
        i += 1
        while i < n:
            if data[i] == UInt8(ord("\\")):
                i += 2
            elif data[i] == UInt8(ord('"')):
                return String(from_utf8_lossy=raw[byte = vs : i + 1].as_bytes())
            else:
                i += 1
        raise Error("Unterminated string")

    if c == UInt8(ord("{")) or c == UInt8(ord("[")):
        var close = UInt8(ord("}")) if c == UInt8(ord("{")) else UInt8(ord("]"))
        var depth = 1
        var vs = i
        i += 1
        var in_str = False
        while i < n and depth > 0:
            if data[i] == UInt8(ord("\\")) and in_str:
                i += 2
                continue
            elif data[i] == UInt8(ord('"')):
                in_str = not in_str
            elif not in_str:
                if data[i] == c:
                    depth += 1
                elif data[i] == close:
                    depth -= 1
            i += 1
        return String(from_utf8_lossy=raw[byte=vs:i].as_bytes())

    var vs = i
    while (
        i < n
        and data[i] != UInt8(ord(","))
        and data[i] != UInt8(ord("}"))
        and data[i] != UInt8(ord("]"))
        and data[i] != UInt8(ord(" "))
        and data[i] != UInt8(ord("\t"))
        and data[i] != UInt8(ord("\n"))
    ):
        i += 1
    return String(from_utf8_lossy=raw[byte=vs:i].as_bytes())


def _extract_array_element(raw: String, index: Int) raises -> String:
    """Extract an array element by index from raw JSON."""
    var data = raw.as_bytes()
    var n = len(data)
    var i = 0
    var current = 0
    var depth = 0

    while i < n and (
        data[i] == UInt8(ord("["))
        or data[i] == UInt8(ord(" "))
        or data[i] == UInt8(ord("\t"))
        or data[i] == UInt8(ord("\n"))
        or data[i] == UInt8(ord("\r"))
    ):
        if data[i] == UInt8(ord("[")):
            _ = depth
            depth = 1
        i += 1

    while i < n:
        while i < n and (
            data[i] == UInt8(ord(" "))
            or data[i] == UInt8(ord("\t"))
            or data[i] == UInt8(ord("\n"))
            or data[i] == UInt8(ord("\r"))
        ):
            i += 1
        if i >= n or data[i] == UInt8(ord("]")):
            break
        if current == index:
            return _extract_json_value(raw, i)

        var ed = 0
        var in_str = False
        var escaped = False
        while i < n:
            var c = data[i]
            if escaped:
                escaped = False
                i += 1
                continue
            if c == UInt8(ord("\\")) and in_str:
                escaped = True
                i += 1
                continue
            if c == UInt8(ord('"')):
                in_str = not in_str
                i += 1
                continue
            if in_str:
                i += 1
                continue
            if c == UInt8(ord("[")) or c == UInt8(ord("{")):
                ed += 1
            elif c == UInt8(ord("]")) or c == UInt8(ord("}")):
                if ed > 0:
                    ed -= 1
                else:
                    break
            elif c == UInt8(ord(",")) and ed == 0:
                i += 1
                current += 1
                break
            i += 1

        if i >= n or data[i] == UInt8(ord("]")):
            break

    raise Error("Array index out of bounds: " + String(index))


def _count_array_elements(raw: String) -> Int:
    """Count top-level elements in a JSON array string."""
    var data = raw.as_bytes()
    var n = len(data)
    var count = 0
    var depth = 0
    var in_str = False
    var escaped = False
    var has_content = False

    for i in range(n):
        var c = data[i]
        if escaped:
            escaped = False
            continue
        if c == UInt8(ord("\\")):
            escaped = True
            continue
        if c == UInt8(ord('"')):
            in_str = not in_str
            continue
        if in_str:
            continue
        if c == UInt8(ord("[")) or c == UInt8(ord("{")):
            depth += 1
        elif c == UInt8(ord("]")) or c == UInt8(ord("}")):
            depth -= 1
        elif c == UInt8(ord(",")) and depth == 1:
            count += 1

    _ = depth
    depth = 0
    in_str = False
    for i in range(n):
        var c = data[i]
        if c == UInt8(ord("[")):
            depth += 1
        elif c == UInt8(ord("]")):
            depth -= 1
        elif c == UInt8(ord('"')):
            if depth == 1 and not in_str:
                has_content = True
            in_str = not in_str
        elif (
            depth == 1
            and not in_str
            and c != UInt8(ord(" "))
            and c != UInt8(ord("\t"))
            and c != UInt8(ord("\n"))
            and c != UInt8(ord("\r"))
        ):
            has_content = True

    if has_content:
        count += 1
    return count


def _extract_object_keys(raw: String) -> List[String]:
    """Extract all keys from a JSON object string."""
    var keys = List[String]()
    var data = raw.as_bytes()
    var n = len(data)
    var depth = 0
    var in_str = False
    var escaped = False
    var key_start = -1
    var expect_key = True

    for i in range(n):
        var c = data[i]
        if escaped:
            escaped = False
            continue
        if c == UInt8(ord("\\")):
            escaped = True
            continue
        if c == UInt8(ord('"')):
            if not in_str:
                in_str = True
                if depth == 1 and expect_key:
                    key_start = i + 1
            else:
                in_str = False
                if key_start >= 0 and depth == 1:
                    keys.append(
                        String(from_utf8_lossy=raw[byte=key_start:i].as_bytes())
                    )
                    key_start = -1
            continue
        if in_str:
            continue
        if c == UInt8(ord("{")) or c == UInt8(ord("[")):
            depth += 1
        elif c == UInt8(ord("}")) or c == UInt8(ord("]")):
            depth -= 1
        elif c == UInt8(ord(":")) and depth == 1:
            expect_key = False
        elif c == UInt8(ord(",")) and depth == 1:
            expect_key = True

    return keys^
