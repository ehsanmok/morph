"""CSV serialization/deserialization for Mojo structs via reflection.

Handles single-row and multi-row CSV with header line matching struct fields.

Usage::

    from morph.csv import to_csv, from_csv, to_csv_row, from_csv_row

    @fieldwise_init
    struct Record(Defaultable, Movable):
        var name: String
        var age: Int
        def __init__(out self):
            self.name = ""
            self.age = 0

    var csv = to_csv(Record(name="Alice", age=30))
    # "name,age\\nAlice,30"
"""

from std.collections import List
from std.builtin.rebind import trait_downcast, rebind
from morph.reflect import (
    Morphable,
    _Base,
    INT_NAME,
    INT64_NAME,
    BOOL_NAME,
    STRING_NAME,
    FLOAT64_NAME,
    FLOAT32_NAME,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _split_lines(s: String) -> List[String]:
    """Split string by newlines."""
    var lines = List[String]()
    var current = String("")
    var data = s.as_bytes()
    for i in range(len(data)):
        if data[i] == UInt8(ord('\n')):
            lines.append(current^)
            current = String("")
        else:
            current += chr(Int(data[i]))
    if len(current) > 0:
        lines.append(current^)
    return lines^


def _split_csv_line(line: String) -> List[String]:
    """Split a CSV line respecting quoted fields."""
    var fields = List[String]()
    var current = String("")
    var in_quotes = False
    var data = line.as_bytes()
    var i = 0

    while i < len(data):
        var ch = data[i]
        if in_quotes:
            if ch == UInt8(ord('"')):
                if i + 1 < len(data) and data[i + 1] == UInt8(ord('"')):
                    current += '"'
                    i += 1
                else:
                    in_quotes = False
            else:
                current += chr(Int(ch))
        else:
            if ch == UInt8(ord('"')):
                in_quotes = True
            elif ch == UInt8(ord(',')):
                fields.append(current^)
                current = String("")
            else:
                current += chr(Int(ch))
        i += 1

    fields.append(current^)
    return fields^


# ---------------------------------------------------------------------------
# Serialize
# ---------------------------------------------------------------------------


def csv_header[T: AnyType]() -> String:
    """Return CSV header line for struct T.

    Parameters:
        T: The struct type.
    """
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()

    var out = String("")
    var first = True

    comptime
    for idx in range(count):
        comptime field_name = names[idx]
        if not first:
            out += ","
        first = False
        out += String(field_name)

    return out^


def to_csv_row[T: AnyType](value: T) -> String:
    """Serialize one struct instance as a single CSV data row (no header).

    Parameters:
        T: The struct type.

    Args:
        value: The struct instance.

    Returns:
        A comma-separated row string.
    """
    comptime count = reflect[T].field_count()
    comptime types = reflect[T].field_types()

    var out = String("")
    var first = True

    comptime
    for idx in range(count):
        comptime field_type = types[idx]
        comptime type_name = reflect[field_type].name()

        if not first:
            out += ","
        first = False

        ref field = reflect[T].field_ref[idx](value)

        comptime
        if type_name == INT_NAME:
            out += String(rebind[Int](field))
        elif type_name == INT64_NAME:
            out += String(rebind[Int64](field))
        elif type_name == BOOL_NAME:
            if rebind[Bool](field):
                out += "true"
            else:
                out += "false"
        elif type_name == FLOAT64_NAME:
            out += String(rebind[Float64](field))
        elif type_name == FLOAT32_NAME:
            out += String(rebind[Float32](field))
        elif type_name == STRING_NAME:
            var s = String(rebind[String](field))
            if "," in s or '"' in s or "\n" in s:
                out += '"' + s.replace('"', '""') + '"'
            else:
                out += s
        else:
            out += "?"

    return out^


def to_csv[T: AnyType](value: T) -> String:
    """Serialize a struct as CSV with header + one data row.

    Parameters:
        T: The struct type.

    Args:
        value: The struct instance.

    Returns:
        A two-line CSV string (header + data).
    """
    return csv_header[T]() + "\n" + to_csv_row(value)


# ---------------------------------------------------------------------------
# Deserialize
# ---------------------------------------------------------------------------


def from_csv_row[T: Morphable](header: List[String], row: String) raises -> T:
    """Deserialize a single CSV row into struct T using header for field mapping.

    Parameters:
        T: The struct type.

    Args:
        header: List of column names.
        row: A CSV data line.

    Returns:
        A populated struct instance.
    """
    var values = _split_csv_line(row)
    if len(values) != len(header):
        raise Error(
            "CSV column count mismatch: header has "
            + String(len(header))
            + " columns, row has "
            + String(len(values))
        )

    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()

    var result = T()

    comptime
    for idx in range(count):
        comptime field_name = names[idx]
        comptime field_type = types[idx]
        comptime type_name = reflect[field_type].name()

        var col_idx = -1
        for hi in range(len(header)):
            if header[hi] == String(field_name):
                col_idx = hi
                break

        if col_idx >= 0:
            var raw = values[col_idx]
            ref field = trait_downcast[_Base](reflect[T].field_ref[idx](result))
            var ptr = UnsafePointer(to=field)

            comptime
            if type_name == INT_NAME:
                var val = atol(raw)
                ptr.destroy_pointee()
                ptr.bitcast[Int]().init_pointee_move(val)
            elif type_name == INT64_NAME:
                var val = atol(raw)
                ptr.destroy_pointee()
                ptr.bitcast[Int64]().init_pointee_move(Int64(val))
            elif type_name == BOOL_NAME:
                var val = raw == "true" or raw == "True" or raw == "1"
                ptr.destroy_pointee()
                ptr.bitcast[Bool]().init_pointee_move(val)
            elif type_name == FLOAT64_NAME:
                var val = atof(raw)
                ptr.destroy_pointee()
                ptr.bitcast[Float64]().init_pointee_move(val)
            elif type_name == STRING_NAME:
                ptr.destroy_pointee()
                ptr.bitcast[String]().init_pointee_move(raw)

    return result^


comptime _CsvMorphable = Defaultable & Movable & Copyable & ImplicitlyDestructible


def from_csv[T: _CsvMorphable](csv_str: String) raises -> List[T]:
    """Deserialize a full CSV string (header + rows) into a List of structs.

    Parameters:
        T: The struct type (Defaultable, Movable, Copyable).

    Args:
        csv_str: Multi-line CSV string.

    Returns:
        List of populated struct instances.
    """
    var lines = _split_lines(csv_str)
    if len(lines) < 1:
        raise Error("CSV must have at least a header line")

    var header = _split_csv_line(lines[0])
    var results = List[T]()

    for i in range(1, len(lines)):
        if len(lines[i]) > 0:
            var row = from_csv_row[T](header, lines[i])
            results.append(row^)

    return results^
