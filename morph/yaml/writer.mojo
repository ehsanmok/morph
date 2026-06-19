"""YAML serialization: struct -> YAML string.

Uses compile-time reflection to walk struct fields and produce YAML output
using indentation-based nesting.

Supported field types:
    Scalars: Int, Int64, Bool, Float64, Float32, String
    Containers: Optional[Int/String/Float64/Bool], List[Int/String/Float64/Bool]
    Nested structs (indented sub-mappings)
"""

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


def to_yaml[
    T: AnyType,
    rename: StaticString = "none",
    skip_private: Bool = False,
](value: T) raises -> String:
    """Serialize a struct to a YAML string via compile-time reflection.

    Parameters:
        T: The struct type (inferred).
        rename: Naming strategy for YAML keys.
        skip_private: If True, skip fields starting with ``_``.

    Args:
        value: The struct instance to serialize.

    Returns:
        A YAML string representation.
    """
    return _ser_mapping[T, rename, skip_private](value, indent=0)


def _ser_mapping[
    T: AnyType,
    rename: StaticString = "none",
    skip_private: Bool = False,
](value: T, indent: Int) raises -> String:
    """Serialize struct fields as YAML key: value pairs."""
    comptime field_count = reflect[T].field_count()
    comptime field_names_ = reflect[T].field_names()
    comptime field_types_ = reflect[T].field_types()

    var out = String("")
    var pad = _indent(indent)

    comptime
    for idx in range(field_count):
        comptime field_name = field_names_[idx]
        comptime field_type = field_types_[idx]
        comptime field_type_name = reflect[field_type].name()

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

            ref field = reflect[T].field_ref[idx](value)

            comptime
            if field_type_name == INT_NAME:
                out += pad + key + ": " + String(rebind[Int](field)) + "\n"
            elif field_type_name == INT64_NAME:
                out += pad + key + ": " + String(rebind[Int64](field)) + "\n"
            elif field_type_name == BOOL_NAME:
                if rebind[Bool](field):
                    out += pad + key + ": true\n"
                else:
                    out += pad + key + ": false\n"
            elif field_type_name == STRING_NAME:
                out += pad + key + ": " + _yaml_scalar(rebind[String](field)) + "\n"
            elif field_type_name == OPT_INT_NAME:
                var opt = rebind[Optional[Int]](field)
                if opt:
                    out += pad + key + ": " + String(opt.value()) + "\n"
                else:
                    out += pad + key + ": null\n"
            elif field_type_name == OPT_STRING_NAME:
                var opt = rebind[Optional[String]](field)
                if opt:
                    out += pad + key + ": " + _yaml_scalar(opt.value()) + "\n"
                else:
                    out += pad + key + ": null\n"
            elif field_type_name == OPT_FLOAT64_NAME:
                var opt = rebind[Optional[Float64]](field)
                if opt:
                    out += pad + key + ": " + String(opt.value()) + "\n"
                else:
                    out += pad + key + ": null\n"
            elif field_type_name == OPT_BOOL_NAME:
                var opt = rebind[Optional[Bool]](field)
                if opt:
                    if opt.value():
                        out += pad + key + ": true\n"
                    else:
                        out += pad + key + ": false\n"
                else:
                    out += pad + key + ": null\n"
            elif field_type_name == LIST_INT_NAME:
                out += _yaml_list_int(key, rebind[List[Int]](field), indent)
            elif field_type_name == LIST_STRING_NAME:
                out += _yaml_list_string(key, rebind[List[String]](field), indent)
            elif field_type_name == LIST_FLOAT64_NAME:
                out += _yaml_list_float64(key, rebind[List[Float64]](field), indent)
            elif field_type_name == LIST_BOOL_NAME:
                out += _yaml_list_bool(key, rebind[List[Bool]](field), indent)
            elif field_type_name == FLOAT64_NAME or _FLOAT64_SIMD_PREFIX in field_type_name:
                out += pad + key + ": " + String(rebind[Float64](field)) + "\n"
            elif field_type_name == FLOAT32_NAME or _FLOAT32_SIMD_PREFIX in field_type_name:
                out += pad + key + ": " + String(rebind[Float32](field)) + "\n"
            elif reflect[field_type].is_struct():
                out += pad + key + ":\n"
                out += _ser_mapping[field_type, rename, skip_private](
                    rebind[field_type](field), indent + 2
                )

    return out^


def _yaml_scalar(s: String) -> String:
    """Format a YAML string scalar, quoting if needed."""
    if len(s) == 0:
        return '""'

    var needs_quote = False
    var data = s.as_bytes()

    if s == "true" or s == "false" or s == "null" or s == "~":
        needs_quote = True

    if not needs_quote:
        for i in range(len(data)):
            var ch = data[i]
            if (
                ch == UInt8(ord(":"))
                or ch == UInt8(ord("#"))
                or ch == UInt8(ord("{"))
                or ch == UInt8(ord("}"))
                or ch == UInt8(ord("["))
                or ch == UInt8(ord("]"))
                or ch == UInt8(ord(","))
                or ch == UInt8(ord("\n"))
                or ch == UInt8(ord('"'))
                or ch == UInt8(ord("'"))
            ):
                needs_quote = True
                break

    if not needs_quote:
        return s

    var out = String('"')
    for i in range(len(data)):
        var ch = data[i]
        if ch == UInt8(ord('"')):
            out += '\\"'
        elif ch == UInt8(ord("\\")):
            out += "\\\\"
        elif ch == UInt8(ord("\n")):
            out += "\\n"
        else:
            out += chr(Int(ch))
    out += '"'
    return out^


def _indent(n: Int) -> String:
    var out = String("")
    for _ in range(n):
        out += " "
    return out^


def _yaml_list_int(key: String, lst: List[Int], indent: Int) -> String:
    var pad = _indent(indent)
    if len(lst) == 0:
        return pad + key + ": []\n"
    var out = pad + key + ":\n"
    var item_pad = _indent(indent + 2)
    for i in range(len(lst)):
        out += item_pad + "- " + String(lst[i]) + "\n"
    return out^


def _yaml_list_string(key: String, lst: List[String], indent: Int) -> String:
    var pad = _indent(indent)
    if len(lst) == 0:
        return pad + key + ": []\n"
    var out = pad + key + ":\n"
    var item_pad = _indent(indent + 2)
    for i in range(len(lst)):
        out += item_pad + "- " + _yaml_scalar(lst[i]) + "\n"
    return out^


def _yaml_list_float64(key: String, lst: List[Float64], indent: Int) -> String:
    var pad = _indent(indent)
    if len(lst) == 0:
        return pad + key + ": []\n"
    var out = pad + key + ":\n"
    var item_pad = _indent(indent + 2)
    for i in range(len(lst)):
        out += item_pad + "- " + String(lst[i]) + "\n"
    return out^


def _yaml_list_bool(key: String, lst: List[Bool], indent: Int) -> String:
    var pad = _indent(indent)
    if len(lst) == 0:
        return pad + key + ": []\n"
    var out = pad + key + ":\n"
    var item_pad = _indent(indent + 2)
    for i in range(len(lst)):
        if lst[i]:
            out += item_pad + "- true\n"
        else:
            out += item_pad + "- false\n"
    return out^
