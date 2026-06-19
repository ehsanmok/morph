"""JSON Schema generation from Mojo struct types via reflection.

Generates Draft 2020-12 compatible JSON Schema objects as strings.

Usage::

    from morph.schema import json_schema

    @fieldwise_init
    struct Person(Defaultable, Movable):
        var name: String
        var age: Int
        def __init__(out self):
            self.name = ""
            self.age = 0

    print(json_schema[Person]())
    # {"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}},"required":["name","age"]}
"""

from std.collections import Dict

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
)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def json_schema[
    T: AnyType,
    rename: StaticString = "none",
    title: StaticString = "",
]() -> String:
    """Generate a JSON Schema string for struct type T.

    Parameters:
        T: The struct type to generate schema for.
        rename: Naming convention for property keys.
        title: Optional title for the root schema.

    Returns:
        A JSON Schema string (Draft 2020-12).
    """
    var schema = String('{"type":"object"')

    comptime
    if title != "":
        schema += ',"title":"' + String(title) + '"'

    schema += ',"properties":{'
    schema += _properties[T, rename]()
    schema += "}"

    var req = _required[T, rename]()
    if len(req) > 0:
        schema += ',"required":[' + req + "]"

    schema += "}"
    return schema^


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _properties[T: AnyType, rename: StaticString = "none"]() -> String:
    """Build the "properties" object contents."""
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()

    var out = String("")
    var first = True

    comptime
    for idx in range(count):
        comptime field_name = names[idx]
        comptime field_type = types[idx]
        comptime type_name = reflect[field_type].name()

        if not first:
            out += ","
        first = False

        var key = String(field_name)

        comptime
        if rename == "camelCase":
            from morph.rename import snake_to_camel

            key = snake_to_camel(key)
        elif rename == "PascalCase":
            from morph.rename import snake_to_pascal

            key = snake_to_pascal(key)
        elif rename == "SCREAMING_SNAKE_CASE":
            from morph.rename import snake_to_screaming

            key = snake_to_screaming(key)

        out += '"' + key + '":'
        out += _type_schema[field_type, type_name]()

    return out^


def _required[T: AnyType, rename: StaticString = "none"]() -> String:
    """Build the "required" array contents (non-Optional fields)."""
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()

    var out = String("")
    var first = True

    comptime
    for idx in range(count):
        comptime field_type = types[idx]
        comptime type_name = reflect[field_type].name()

        comptime
        if not (type_name == OPT_INT_NAME or type_name == OPT_STRING_NAME or type_name == OPT_FLOAT64_NAME or type_name == OPT_BOOL_NAME):
            if not first:
                out += ","
            first = False

            var key = String(names[idx])

            comptime
            if rename == "camelCase":
                from morph.rename import snake_to_camel

                key = snake_to_camel(key)
            elif rename == "PascalCase":
                from morph.rename import snake_to_pascal

                key = snake_to_pascal(key)
            elif rename == "SCREAMING_SNAKE_CASE":
                from morph.rename import snake_to_screaming

                key = snake_to_screaming(key)

            out += '"' + key + '"'

    return out^


def json_schema_described[
    T: AnyType,
    rename: StaticString = "none",
    title: StaticString = "",
](descriptions: Dict[String, String]) raises -> String:
    """Generate a JSON Schema with per-field descriptions.

    Parameters:
        T: The struct type to generate schema for.
        rename: Naming convention for property keys.
        title: Optional title for the root schema.

    Args:
        descriptions: A mapping of field names to description strings.
            Keys matching field names will add "description" to that property.
            A key named "_deprecated" with comma-separated field names marks
            those fields as deprecated (sets "deprecated":true).

    Returns:
        A JSON Schema string with descriptions and deprecated annotations.
    """
    var schema = String('{"type":"object"')

    comptime
    if title != "":
        schema += ',"title":"' + String(title) + '"'

    schema += ',"properties":{'
    schema += _properties_described[T, rename](descriptions)
    schema += "}"

    var req = _required[T, rename]()
    if len(req) > 0:
        schema += ',"required":[' + req + "]"

    schema += "}"
    return schema^


def _properties_described[
    T: AnyType, rename: StaticString = "none"
](descriptions: Dict[String, String]) raises -> String:
    """Build properties with optional descriptions and deprecated flags."""
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()

    var deprecated_list = String("")
    if "_deprecated" in descriptions:
        deprecated_list = descriptions["_deprecated"]

    var out = String("")
    var first = True

    comptime
    for idx in range(count):
        comptime field_name = names[idx]
        comptime field_type = types[idx]
        comptime type_name = reflect[field_type].name()

        if not first:
            out += ","
        first = False

        var key = String(field_name)

        comptime
        if rename == "camelCase":
            from morph.rename import snake_to_camel

            key = snake_to_camel(key)
        elif rename == "PascalCase":
            from morph.rename import snake_to_pascal

            key = snake_to_pascal(key)
        elif rename == "SCREAMING_SNAKE_CASE":
            from morph.rename import snake_to_screaming

            key = snake_to_screaming(key)

        out += '"' + key + '":'

        var base = _type_schema[field_type, type_name]()
        var raw = String(field_name)
        var has_desc = raw in descriptions
        var is_deprecated = _contains_word(deprecated_list, raw)

        if has_desc or is_deprecated:
            var base_bytes = base.as_bytes()
            var enriched = String("")
            for bi in range(len(base_bytes) - 1):
                enriched += chr(Int(base_bytes[bi]))
            if has_desc:
                enriched += ',"description":"' + descriptions[raw] + '"'
            if is_deprecated:
                enriched += ',"deprecated":true'
            enriched += "}"
            out += enriched^
        else:
            out += base

    return out^


def _contains_word(csv: String, word: String) -> Bool:
    """Check if word appears in a comma-separated list."""
    if len(csv) == 0:
        return False
    var data = csv.as_bytes()
    var w = word.as_bytes()
    var start = 0
    for i in range(len(data) + 1):
        if i == len(data) or data[i] == UInt8(ord(",")):
            var segment_len = i - start
            if segment_len == len(w):
                var found = True
                for j in range(segment_len):
                    if data[start + j] != w[j]:
                        found = False
                        break
                if found:
                    return True
            start = i + 1
    return False


def _type_schema[T: AnyType, type_name: StaticString]() -> String:
    """Return JSON Schema for a single type."""
    comptime
    if type_name == INT_NAME or type_name == INT64_NAME:
        return '{"type":"integer"}'
    elif type_name == BOOL_NAME:
        return '{"type":"boolean"}'
    elif type_name == STRING_NAME:
        return '{"type":"string"}'
    elif type_name == FLOAT64_NAME or type_name == FLOAT32_NAME:
        return '{"type":"number"}'
    elif type_name == OPT_INT_NAME:
        return '{"type":["integer","null"]}'
    elif type_name == OPT_STRING_NAME:
        return '{"type":["string","null"]}'
    elif type_name == OPT_FLOAT64_NAME:
        return '{"type":["number","null"]}'
    elif type_name == OPT_BOOL_NAME:
        return '{"type":["boolean","null"]}'
    elif type_name == LIST_INT_NAME:
        return '{"type":"array","items":{"type":"integer"}}'
    elif type_name == LIST_STRING_NAME:
        return '{"type":"array","items":{"type":"string"}}'
    elif type_name == LIST_FLOAT64_NAME:
        return '{"type":"array","items":{"type":"number"}}'
    elif type_name == LIST_BOOL_NAME:
        return '{"type":"array","items":{"type":"boolean"}}'
    else:
        var schema = String('{"type":"object","properties":{')
        schema += _properties[T]()
        schema += "}"
        var req = _required[T]()
        if len(req) > 0:
            schema += ',"required":[' + req + "]"
        schema += "}"
        return schema^
