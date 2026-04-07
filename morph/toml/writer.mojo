"""TOML serialization: struct -> TOML string.

Uses compile-time reflection to walk struct fields and produce TOML output.

Supported field types:
    Scalars: Int, Int64, Bool, Float64, Float32, String
    Containers: Optional[Int/String/Float64/Bool], List[Int/String/Float64/Bool]
    Nested structs (emitted as [section] tables)
    Custom: types implementing morph.serde.Serializable
"""

from std.reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
    get_type_name,
    is_struct_type,
)
from std.builtin.rebind import trait_downcast, rebind
from std.collections import Optional, List

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
)
from morph.serde import Serializable
from morph.rename import apply_rename


def to_toml[
    T: AnyType,
    rename: StaticString = "none",
    skip_private: Bool = False,
](value: T) raises -> String:
    """Serialize a struct to a TOML string via compile-time reflection.

    Nested structs become ``[table]`` sections. Lists become TOML arrays.
    Optional fields with None value are omitted entirely (TOML has no null).

    Parameters:
        T: The struct type (inferred).
        rename: Naming strategy for TOML keys.
        skip_private: If True, skip fields starting with ``_``.

    Args:
        value: The struct instance to serialize.

    Returns:
        A TOML string representation.
    """
    return _ser_table[T, rename, skip_private](value, prefix=String(""))


def _ser_table[
    T: AnyType,
    rename: StaticString = "none",
    skip_private: Bool = False,
](value: T, prefix: String) raises -> String:
    """Serialize struct fields as TOML key-value pairs plus nested tables."""
    comptime field_count = struct_field_count[T]()
    comptime field_names_ = struct_field_names[T]()
    comptime field_types_ = struct_field_types[T]()

    var scalars = String("")
    var tables = String("")

    comptime
    for idx in range(field_count):
        comptime field_name = field_names_[idx]
        comptime field_type = field_types_[idx]
        comptime field_type_name = get_type_name[field_type]()

        var raw_name = String(field_name)
        var skip = False

        comptime
        if skip_private:
            if raw_name.as_bytes()[0] == UInt8(ord("_")):
                skip = True

        if not skip:
            var key: String
            comptime
            if rename == "none":
                key = raw_name
            else:
                key = apply_rename(raw_name, String(rename))

            ref field = __struct_field_ref(idx, value)

            comptime
            if field_type_name == INT_NAME:
                scalars += key + " = " + String(rebind[Int](field)) + "\n"
            elif field_type_name == INT64_NAME:
                scalars += key + " = " + String(rebind[Int64](field)) + "\n"
            elif field_type_name == BOOL_NAME:
                if rebind[Bool](field):
                    scalars += key + " = true\n"
                else:
                    scalars += key + " = false\n"
            elif field_type_name == STRING_NAME:
                scalars += key + " = " + _escape_toml_string(rebind[String](field)) + "\n"
            elif field_type_name == OPT_INT_NAME:
                var opt = rebind[Optional[Int]](field)
                if opt:
                    scalars += key + " = " + String(opt.value()) + "\n"
            elif field_type_name == OPT_STRING_NAME:
                var opt = rebind[Optional[String]](field)
                if opt:
                    scalars += key + " = " + _escape_toml_string(opt.value()) + "\n"
            elif field_type_name == OPT_FLOAT64_NAME:
                var opt = rebind[Optional[Float64]](field)
                if opt:
                    scalars += key + " = " + String(opt.value()) + "\n"
            elif field_type_name == OPT_BOOL_NAME:
                var opt = rebind[Optional[Bool]](field)
                if opt:
                    if opt.value():
                        scalars += key + " = true\n"
                    else:
                        scalars += key + " = false\n"
            elif field_type_name == LIST_INT_NAME:
                scalars += key + " = " + _ser_list_int(rebind[List[Int]](field)) + "\n"
            elif field_type_name == LIST_STRING_NAME:
                scalars += key + " = " + _ser_list_string(rebind[List[String]](field)) + "\n"
            elif field_type_name == LIST_FLOAT64_NAME:
                scalars += key + " = " + _ser_list_float64(rebind[List[Float64]](field)) + "\n"
            elif field_type_name == LIST_BOOL_NAME:
                scalars += key + " = " + _ser_list_bool(rebind[List[Bool]](field)) + "\n"
            elif field_type_name == FLOAT64_NAME or _FLOAT64_SIMD_PREFIX in field_type_name:
                scalars += key + " = " + String(rebind[Float64](field)) + "\n"
            elif field_type_name == FLOAT32_NAME or _FLOAT32_SIMD_PREFIX in field_type_name:
                scalars += key + " = " + String(rebind[Float32](field)) + "\n"
            elif is_struct_type[field_type]():
                var section: String
                if len(prefix) > 0:
                    section = prefix + "." + key
                else:
                    section = key
                var inner = _ser_table[field_type, rename, skip_private](
                    rebind[field_type](field), section
                )
                tables += "\n[" + section + "]\n" + inner

    return scalars + tables


def _escape_toml_string(s: String) -> String:
    """Wrap a string in double quotes and escape special characters."""
    var out = String('"')
    var data = s.as_bytes()
    for i in range(len(data)):
        var ch = data[i]
        if ch == UInt8(ord('"')):
            out += '\\"'
        elif ch == UInt8(ord("\\")):
            out += "\\\\"
        elif ch == UInt8(ord("\n")):
            out += "\\n"
        elif ch == UInt8(ord("\t")):
            out += "\\t"
        elif ch == UInt8(ord("\r")):
            out += "\\r"
        else:
            out += chr(Int(ch))
    out += '"'
    return out^


def _ser_list_int(lst: List[Int]) -> String:
    var out = String("[")
    for i in range(len(lst)):
        if i > 0:
            out += ", "
        out += String(lst[i])
    out += "]"
    return out^


def _ser_list_string(lst: List[String]) -> String:
    var out = String("[")
    for i in range(len(lst)):
        if i > 0:
            out += ", "
        out += _escape_toml_string(lst[i])
    out += "]"
    return out^


def _ser_list_float64(lst: List[Float64]) -> String:
    var out = String("[")
    for i in range(len(lst)):
        if i > 0:
            out += ", "
        out += String(lst[i])
    out += "]"
    return out^


def _ser_list_bool(lst: List[Bool]) -> String:
    var out = String("[")
    for i in range(len(lst)):
        if i > 0:
            out += ", "
        if lst[i]:
            out += "true"
        else:
            out += "false"
    out += "]"
    return out^
