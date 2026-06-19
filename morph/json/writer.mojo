"""JSON serialization: struct -> JSON string.

Uses compile-time reflection to walk struct fields and produce JSON output.

Supported field types:
    Scalars: Int, Int64, Bool, Float64, Float32, String
    Containers: Optional[Int/String/Float64/Bool], List[Int/String/Float64/Bool]
    Nested structs (recursive)
    Custom: types implementing morph.serde.Serializable

Parameters:
    rename: Naming strategy for JSON keys ("none", "camelCase", "PascalCase",
            "SCREAMING_SNAKE_CASE"). Default "none" = use field names as-is.
    skip_private: If True, skip fields whose name starts with ``_``.
    add_type: If True, inject ``"type":"StructName"`` as the first field.
    as_array: If True, serialize as positional JSON array (no field names).
"""

from std.builtin.rebind import trait_downcast, downcast, rebind
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
from morph.json.value import escape_string as _escape_string


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def write[
    T: AnyType,
    pretty: Bool = False,
    rename: StaticString = "none",
    skip_private: Bool = False,
    add_type: Bool = False,
    as_array: Bool = False,
](value: T) raises -> String:
    """Serialize a struct to a JSON string via compile-time reflection.

    Parameters:
        T: The struct type (inferred).
        pretty: If True, format with 2-space indentation.
        rename: Naming strategy for JSON keys.
        skip_private: If True, skip fields starting with ``_``.
        add_type: If True, inject ``"type":"StructName"`` field.
        as_array: If True, emit positional JSON array instead of object.

    Args:
        value: The struct instance to serialize.

    Returns:
        A JSON string representation.
    """
    var json = _ser[T, rename, skip_private, add_type, as_array](value)

    comptime
    if pretty:
        from morph.json.value import loads as _loads, dumps as _dumps

        var parsed = _loads(json)
        return _dumps(parsed, indent="  ")

    return json^


# ---------------------------------------------------------------------------
# Internal dispatch
# ---------------------------------------------------------------------------


def _ser[
    T: AnyType,
    rename: StaticString = "none",
    skip_private: Bool = False,
    add_type: Bool = False,
    as_array: Bool = False,
](value: T) raises -> String:
    """Dispatch serialization by compile-time type."""
    comptime tname = reflect[T].name()

    comptime
    if tname == STRING_NAME:
        return _escape_string(rebind[String](value))
    elif tname == INT_NAME:
        return String(rebind[Int](value))
    elif tname == INT64_NAME:
        return String(rebind[Int64](value))
    elif tname == BOOL_NAME:
        return "true" if rebind[Bool](value) else "false"
    elif tname == OPT_INT_NAME:
        return _ser_opt_int(rebind[Optional[Int]](value))
    elif tname == OPT_STRING_NAME:
        return _ser_opt_string(rebind[Optional[String]](value))
    elif tname == OPT_FLOAT64_NAME:
        return _ser_opt_float64(rebind[Optional[Float64]](value))
    elif tname == OPT_BOOL_NAME:
        return _ser_opt_bool(rebind[Optional[Bool]](value))
    elif tname == LIST_INT_NAME:
        return _ser_list_int(rebind[List[Int]](value))
    elif tname == LIST_STRING_NAME:
        return _ser_list_string(rebind[List[String]](value))
    elif tname == LIST_FLOAT64_NAME:
        return _ser_list_float64(rebind[List[Float64]](value))
    elif tname == LIST_BOOL_NAME:
        return _ser_list_bool(rebind[List[Bool]](value))
    elif tname == FLOAT64_NAME or _FLOAT64_SIMD_PREFIX in tname:
        return String(rebind[Float64](value))
    elif tname == FLOAT32_NAME or _FLOAT32_SIMD_PREFIX in tname:
        return String(rebind[Float32](value))
    elif reflect[T].is_struct():
        comptime
        if conforms_to(T, Serializable):
            ref custom = trait_downcast[Serializable](value)
            return custom.serialize()
        else:
            return _ser_struct[T, rename, skip_private, add_type, as_array](value)
    else:
        return "null"


def _ser_struct[
    T: AnyType,
    rename: StaticString = "none",
    skip_private: Bool = False,
    add_type: Bool = False,
    as_array: Bool = False,
](value: T) raises -> String:
    """Serialize a struct as JSON object or array."""
    comptime field_count = reflect[T].field_count()
    comptime field_names = reflect[T].field_names()
    comptime field_types = reflect[T].field_types()

    # --- Array mode: [val, val, ...] ---
    comptime
    if as_array:
        if field_count == 0:
            return "[]"
        var out = String("[")
        var first = True
        comptime
        for idx in range(field_count):
            comptime field_name = field_names[idx]
            comptime field_type = field_types[idx]
            var raw_name = String(field_name)
            var skip = False
            comptime
            if skip_private:
                if raw_name.as_bytes()[0] == UInt8(ord("_")):
                    skip = True
            if not skip:
                if not first:
                    out += ","
                first = False
                ref field = reflect[T].field_ref[idx](value)
                out += _ser[field_type, rename, skip_private, False, as_array](
                    rebind[field_type](field)
                )
        out += "]"
        return out^
    else:
        # --- Object mode: {"key":val, ...} ---
        if field_count == 0:
            return "{}"
        var out = String("{")
        var first = True

        comptime
        if add_type:
            comptime type_name = reflect[T].base_name()
            out += '"type":"' + String(type_name) + '"'
            first = False

        comptime
        for idx in range(field_count):
            comptime field_name = field_names[idx]
            comptime field_type = field_types[idx]

            var raw_name = String(field_name)
            var skip = False

            comptime
            if skip_private:
                if raw_name.as_bytes()[0] == UInt8(ord("_")):
                    skip = True

            if not skip:
                if not first:
                    out += ","
                first = False

                var key_name: String
                comptime
                if rename == "none":
                    key_name = raw_name
                else:
                    key_name = apply_rename(raw_name, String(rename))

                out += '"' + key_name + '":'

                ref field = reflect[T].field_ref[idx](value)
                out += _ser[field_type, rename, skip_private, False, as_array](
                    rebind[field_type](field)
                )

        out += "}"
        return out^


# ---------------------------------------------------------------------------
# Flatten: embed nested struct fields at top level
# ---------------------------------------------------------------------------


def write_flat[
    T: AnyType,
    pretty: Bool = False,
    rename: StaticString = "none",
    skip_private: Bool = False,
](value: T) raises -> String:
    """Serialize a struct, flattening nested struct fields to the top level.

    Serializes ``value`` normally first, then inlines any top-level keys
    whose values are JSON objects so that their sub-keys appear directly
    at the top level.

    Parameters:
        T: The struct type.
        pretty: If True, format with 2-space indentation.
        rename: Naming strategy for JSON keys.
        skip_private: If True, skip fields starting with ``_``.

    Args:
        value: The struct instance to serialize.

    Returns:
        A JSON string with nested struct fields flattened.
    """
    from morph.json.value import loads as _loads, dumps as _dumps

    var nested_json = write[T, rename=rename, skip_private=skip_private](value)
    var parsed = _loads(nested_json)
    if not parsed.is_object():
        return nested_json

    var keys = parsed.object_keys()
    var out = String("{")
    var first = True

    for ki in range(len(keys)):
        var k = keys[ki]
        var raw = parsed.get(k)
        var sub = _loads(raw)
        if sub.is_object():
            var sub_keys = sub.object_keys()
            for si in range(len(sub_keys)):
                if not first:
                    out += ","
                first = False
                out += '"' + sub_keys[si] + '":' + sub.get(sub_keys[si])
        else:
            if not first:
                out += ","
            first = False
            out += '"' + k + '":' + raw

    out += "}"

    comptime
    if pretty:
        var formatted = _loads(out)
        return _dumps(formatted, indent="  ")

    return out^


# ---------------------------------------------------------------------------
# Optional helpers
# ---------------------------------------------------------------------------


def _ser_opt_int(opt: Optional[Int]) -> String:
    if opt:
        return String(opt.value())
    return "null"


def _ser_opt_string(opt: Optional[String]) -> String:
    if opt:
        return _escape_string(opt.value())
    return "null"


def _ser_opt_float64(opt: Optional[Float64]) -> String:
    if opt:
        return String(opt.value())
    return "null"


def _ser_opt_bool(opt: Optional[Bool]) -> String:
    if opt:
        return "true" if opt.value() else "false"
    return "null"


# ---------------------------------------------------------------------------
# List helpers
# ---------------------------------------------------------------------------


def _ser_list_int(lst: List[Int]) -> String:
    var out = String("[")
    for i in range(len(lst)):
        if i > 0:
            out += ","
        out += String(lst[i])
    out += "]"
    return out^


def _ser_list_string(lst: List[String]) -> String:
    var out = String("[")
    for i in range(len(lst)):
        if i > 0:
            out += ","
        out += _escape_string(lst[i])
    out += "]"
    return out^


def _ser_list_float64(lst: List[Float64]) -> String:
    var out = String("[")
    for i in range(len(lst)):
        if i > 0:
            out += ","
        out += String(lst[i])
    out += "]"
    return out^


def _ser_list_bool(lst: List[Bool]) -> String:
    var out = String("[")
    for i in range(len(lst)):
        if i > 0:
            out += ","
        out += "true" if lst[i] else "false"
    out += "]"
    return out^
