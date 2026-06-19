"""JSON deserialization: JSON string -> struct.

Uses compile-time reflection to walk struct fields and populate them
from parsed JSON values.

Supported field types:
    Scalars: Int, Int64, Bool, Float64, Float32, String
    Containers: Optional[Int/String/Float64/Bool], List[Int/String/Float64/Bool]
    Nested structs (recursive, must implement Defaultable & Movable)
    Custom: types implementing morph.serde.Deserializable

Parameters:
    rename: Naming strategy for JSON keys (applied to struct field names
            to derive the JSON key). Same as write().
    skip_private: If True, skip fields whose name starts with ``_``.
    default_if_missing: If True, keep default values for missing JSON keys
                        instead of raising.
    strict: If True, raise on unknown JSON keys not in the struct.
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
    _Base,
    Morphable,
)
from morph.serde import Deserializable
from morph.rename import apply_rename
from morph.json.value import loads, Value, get_string, get_int, get_bool, get_float


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def read[
    T: Morphable,
    rename: StaticString = "none",
    skip_private: Bool = False,
    default_if_missing: Bool = False,
    strict: Bool = False,
    no_optionals: Bool = False,
](json_str: String) raises -> T:
    """Deserialize a JSON string into a struct via compile-time reflection.

    Parameters:
        T: The target struct type (must be Defaultable & Movable).
        rename: Naming strategy applied to field names when looking up JSON keys.
        skip_private: If True, skip fields starting with ``_``.
        default_if_missing: If True, missing keys keep defaults instead of raising.
        strict: If True, error on unknown JSON keys (NoExtraFields).
        no_optionals: If True, reject null for Optional fields (require a value).

    Args:
        json_str: A JSON string.

    Returns:
        A populated struct of type T.

    Raises:
        Error on parse failure, missing fields, or type mismatches.
    """
    var json = loads(json_str)
    return _read_value[T, rename, skip_private, default_if_missing, strict, no_optionals](json)


# ---------------------------------------------------------------------------
# Internal dispatch
# ---------------------------------------------------------------------------


def _read_value[
    T: Morphable,
    rename: StaticString = "none",
    skip_private: Bool = False,
    default_if_missing: Bool = False,
    strict: Bool = False,
    no_optionals: Bool = False,
](json: Value) raises -> T:
    """Deserialize a Value into a struct."""
    comptime
    if conforms_to(T, Deserializable):
        return downcast[T, Deserializable].deserialize(json.raw_json())
    else:
        if not json.is_object():
            raise Error(
                "Expected JSON object for struct deserialization, got "
                + _type_label(json)
            )
        var result = T()
        _fill[T, rename, skip_private, default_if_missing, strict, no_optionals](result, json)
        return result^


def _fill[
    T: AnyType,
    rename: StaticString = "none",
    skip_private: Bool = False,
    default_if_missing: Bool = False,
    strict: Bool = False,
    no_optionals: Bool = False,
](mut result: T, json: Value) raises:
    """Fill every field of result from the JSON object."""
    comptime field_count = reflect[T].field_count()
    comptime field_names = reflect[T].field_names()
    comptime field_types = reflect[T].field_types()

    # --- strict mode: check for unknown keys ---
    comptime
    if strict:
        var json_keys = json.object_keys()
        for ki in range(len(json_keys)):
            var jk = json_keys[ki]
            var known = False
            comptime
            for fi in range(field_count):
                comptime fn_name = field_names[fi]
                var expected_key: String
                comptime
                if rename == "none":
                    expected_key = String(fn_name)
                else:
                    expected_key = apply_rename(String(fn_name), String(rename))
                if jk == expected_key:
                    known = True
            if not known:
                raise Error("Unknown JSON key '" + jk + "' (strict mode)")

    comptime
    for idx in range(field_count):
        comptime field_name = field_names[idx]
        comptime field_type = field_types[idx]
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

            var present = _has_key(json, key)

            if not present:
                comptime
                if not default_if_missing:
                    # Optional types naturally default to None
                    comptime
                    if not (field_type_name == OPT_INT_NAME or field_type_name == OPT_STRING_NAME or field_type_name == OPT_FLOAT64_NAME or field_type_name == OPT_BOOL_NAME):
                        raise Error("Missing required field '" + key + "'")
            else:
                ref field = trait_downcast[_Base](reflect[T].field_ref[idx](result))
                var ptr = UnsafePointer(to=field)

                comptime
                if no_optionals:
                    comptime
                    if field_type_name == OPT_INT_NAME or field_type_name == OPT_STRING_NAME or field_type_name == OPT_FLOAT64_NAME or field_type_name == OPT_BOOL_NAME:
                        if _is_null_field(json, key):
                            raise Error(
                                "Field '" + key + "' is null but no_optionals is set"
                            )

                comptime
                if field_type_name == STRING_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[String]().init_pointee_move(get_string(json, key))
                elif field_type_name == INT_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Int]().init_pointee_move(get_int(json, key))
                elif field_type_name == INT64_NAME:
                    ptr.destroy_pointee()
                    var raw = json.get(key)
                    var parsed = loads(raw)
                    if not parsed.is_int():
                        raise _field_type_error(key, "Int64", parsed)
                    ptr.bitcast[Int64]().init_pointee_move(parsed.int_value())
                elif field_type_name == BOOL_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Bool]().init_pointee_move(get_bool(json, key))
                elif field_type_name == OPT_INT_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Optional[Int]]().init_pointee_move(
                        _deser_opt_int(json, key)
                    )
                elif field_type_name == OPT_STRING_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Optional[String]]().init_pointee_move(
                        _deser_opt_string(json, key)
                    )
                elif field_type_name == OPT_FLOAT64_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Optional[Float64]]().init_pointee_move(
                        _deser_opt_float64(json, key)
                    )
                elif field_type_name == OPT_BOOL_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Optional[Bool]]().init_pointee_move(
                        _deser_opt_bool(json, key)
                    )
                elif field_type_name == LIST_INT_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[List[Int]]().init_pointee_move(
                        _deser_list_int(json, key)
                    )
                elif field_type_name == LIST_STRING_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[List[String]]().init_pointee_move(
                        _deser_list_string(json, key)
                    )
                elif field_type_name == LIST_FLOAT64_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[List[Float64]]().init_pointee_move(
                        _deser_list_float64(json, key)
                    )
                elif field_type_name == LIST_BOOL_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[List[Bool]]().init_pointee_move(
                        _deser_list_bool(json, key)
                    )
                elif field_type_name == FLOAT64_NAME or _FLOAT64_SIMD_PREFIX in field_type_name:
                    ptr.destroy_pointee()
                    ptr.bitcast[Float64]().init_pointee_move(get_float(json, key))
                elif field_type_name == FLOAT32_NAME or _FLOAT32_SIMD_PREFIX in field_type_name:
                    ptr.destroy_pointee()
                    ptr.bitcast[Float32]().init_pointee_move(
                        Float32(get_float(json, key))
                    )
                elif reflect[field_type].is_struct():
                    var raw = json.get(key)
                    var sub_json = loads(raw)
                    if not sub_json.is_object():
                        raise _field_type_error(key, "object", sub_json)
                    _fill[field_type, rename, skip_private, default_if_missing, False, no_optionals](
                        ptr.bitcast[field_type]()[], sub_json
                    )
                else:
                    raise Error(
                        "Unsupported field type for '"
                        + key
                        + "': "
                        + String(field_type_name)
                    )


# ---------------------------------------------------------------------------
# Flatten: read top-level fields back into nested structs
# ---------------------------------------------------------------------------


def read_flat[
    T: Morphable,
    rename: StaticString = "none",
    skip_private: Bool = False,
    default_if_missing: Bool = False,
](json_str: String) raises -> T:
    """Deserialize a flattened JSON object back into a struct with nested structs.

    Reconstructs nested JSON objects from flat keys, then delegates to the
    normal ``read()`` function. Nested struct fields are identified by comparing
    against the default-serialized struct's shape.

    Parameters:
        T: The target struct type.
        rename: Naming strategy applied to field names.
        skip_private: If True, skip fields starting with ``_``.
        default_if_missing: If True, missing keys keep defaults.

    Args:
        json_str: A JSON string with flattened fields.

    Returns:
        A populated struct with nested structs reconstructed.
    """
    from morph.json.writer import write as _write

    var default_instance = T()
    var default_json_str = _write[T, rename=rename, skip_private=skip_private](
        default_instance
    )
    var default_json = loads(default_json_str)

    var flat_json = loads(json_str)
    if not flat_json.is_object():
        raise Error("Expected JSON object for flat deserialization")

    var default_keys = default_json.object_keys()

    var nested_fields = List[String]()
    for di in range(len(default_keys)):
        var dk = default_keys[di]
        var raw = default_json.get(dk)
        var sub = loads(raw)
        if sub.is_object():
            nested_fields.append(dk)

    var out = String("{")
    var first = True
    for di in range(len(default_keys)):
        var dk = default_keys[di]
        if not first:
            out += ","
        first = False
        out += '"' + dk + '":'

        var is_nested = False
        for ni in range(len(nested_fields)):
            if nested_fields[ni] == dk:
                is_nested = True
                break

        if is_nested:
            var raw_sub = default_json.get(dk)
            var sub = loads(raw_sub)
            var sub_keys = sub.object_keys()
            var inner = String("{")
            var ifirst = True
            for si in range(len(sub_keys)):
                var sk = sub_keys[si]
                if not ifirst:
                    inner += ","
                ifirst = False
                inner += '"' + sk + '":'
                if _has_key(flat_json, sk):
                    inner += flat_json.get(sk)
                else:
                    inner += sub.get(sk)
            inner += "}"
            out += inner^
        else:
            if _has_key(flat_json, dk):
                out += flat_json.get(dk)
            else:
                out += default_json.get(dk)

    out += "}"
    return read[T, rename=rename, skip_private=skip_private, default_if_missing=True](
        out
    )


# ---------------------------------------------------------------------------
# Optional deserialization
# ---------------------------------------------------------------------------


def _deser_opt_int(json: Value, key: String) raises -> Optional[Int]:
    if not _has_key(json, key):
        return None
    var parsed = loads(json.get(key))
    if parsed.is_null():
        return None
    if not parsed.is_int():
        raise _field_type_error(key, "int", parsed)
    return Int(parsed.int_value())


def _deser_opt_string(json: Value, key: String) raises -> Optional[String]:
    if not _has_key(json, key):
        return None
    var parsed = loads(json.get(key))
    if parsed.is_null():
        return None
    if not parsed.is_string():
        raise _field_type_error(key, "string", parsed)
    return parsed.string_value()


def _deser_opt_float64(
    json: Value, key: String
) raises -> Optional[Float64]:
    if not _has_key(json, key):
        return None
    var parsed = loads(json.get(key))
    if parsed.is_null():
        return None
    if parsed.is_float():
        return parsed.float_value()
    elif parsed.is_int():
        return Float64(parsed.int_value())
    raise _field_type_error(key, "number", parsed)


def _deser_opt_bool(json: Value, key: String) raises -> Optional[Bool]:
    if not _has_key(json, key):
        return None
    var parsed = loads(json.get(key))
    if parsed.is_null():
        return None
    if not parsed.is_bool():
        raise _field_type_error(key, "bool", parsed)
    return parsed.bool_value()


# ---------------------------------------------------------------------------
# List deserialization
# ---------------------------------------------------------------------------


def _deser_list_int(json: Value, key: String) raises -> List[Int]:
    var raw = json.get(key)
    var arr = loads(raw)
    if not arr.is_array():
        raise _field_type_error(key, "array", arr)
    var items = arr.array_items()
    var result = List[Int]()
    for i in range(len(items)):
        if not items[i].is_int():
            raise Error(
                "Element " + String(i) + " of '" + key + "' expected int, got "
                + _type_label(items[i])
            )
        result.append(Int(items[i].int_value()))
    return result^


def _deser_list_string(json: Value, key: String) raises -> List[String]:
    var raw = json.get(key)
    var arr = loads(raw)
    if not arr.is_array():
        raise _field_type_error(key, "array", arr)
    var items = arr.array_items()
    var result = List[String]()
    for i in range(len(items)):
        if not items[i].is_string():
            raise Error(
                "Element " + String(i) + " of '" + key + "' expected string, got "
                + _type_label(items[i])
            )
        result.append(items[i].string_value())
    return result^


def _deser_list_float64(
    json: Value, key: String
) raises -> List[Float64]:
    var raw = json.get(key)
    var arr = loads(raw)
    if not arr.is_array():
        raise _field_type_error(key, "array", arr)
    var items = arr.array_items()
    var result = List[Float64]()
    for i in range(len(items)):
        if items[i].is_float():
            result.append(items[i].float_value())
        elif items[i].is_int():
            result.append(Float64(items[i].int_value()))
        else:
            raise Error(
                "Element " + String(i) + " of '" + key + "' expected number, got "
                + _type_label(items[i])
            )
    return result^


def _deser_list_bool(json: Value, key: String) raises -> List[Bool]:
    var raw = json.get(key)
    var arr = loads(raw)
    if not arr.is_array():
        raise _field_type_error(key, "array", arr)
    var items = arr.array_items()
    var result = List[Bool]()
    for i in range(len(items)):
        if not items[i].is_bool():
            raise Error(
                "Element " + String(i) + " of '" + key + "' expected bool, got "
                + _type_label(items[i])
            )
        result.append(items[i].bool_value())
    return result^


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------


def _has_key(json: Value, key: String) -> Bool:
    if not json.is_object():
        return False
    var keys = json.object_keys()
    for i in range(len(keys)):
        if keys[i] == key:
            return True
    return False


def _is_null_field(json: Value, key: String) -> Bool:
    try:
        var raw = json.get(key)
        return raw == "null"
    except:
        return True


def _type_label(v: Value) -> String:
    if v.is_null():
        return "null"
    elif v.is_bool():
        return "bool"
    elif v.is_int():
        return "int"
    elif v.is_float():
        return "float"
    elif v.is_string():
        return "string"
    elif v.is_array():
        return "array"
    elif v.is_object():
        return "object"
    return "unknown"


def _field_type_error(field: String, expected: String, got: Value) -> Error:
    return Error(
        "Field '" + field + "' expected " + expected + ", got " + _type_label(got)
    )
