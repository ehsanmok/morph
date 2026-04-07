"""morph -- Reflection-powered serialization, deserialization, and validation for Mojo.

Inspired by reflect-cpp, morph uses compile-time reflection to automatically
map Mojo structs to and from serialization formats with zero boilerplate.

## Quick Start

```mojo
from morph.json import write, read

@fieldwise_init
struct Person(Defaultable, Movable):
    var name: String
    var age: Int
    def __init__(out self):
        self.name = ""
        self.age = 0

var json = write(Person(name="Alice", age=30))
var bob = read[Person]('{"name":"Bob","age":25}')
```

## Modules

- `morph.json` -- JSON serialization/deserialization (powered by mojson)
- `morph.toml` -- TOML serialization/deserialization (pure Mojo)
- `morph.yaml` -- YAML serialization/deserialization (pure Mojo)
- `morph.reflect` -- Core reflection utilities (type matchers, field helpers)
- `morph.serde` -- Serializable/Deserializable traits for custom overrides
- `morph.rename` -- Field renaming strategies (snake_case <-> camelCase)
- `morph.transform` -- Struct introspection and composition (fields, as_type)
"""

from .reflect import (
    Morphable,
    is_int_type,
    is_int64_type,
    is_bool_type,
    is_string_type,
    is_float64_type,
    is_float32_type,
    is_scalar_type,
    is_optional_type,
    is_list_type,
    is_container_type,
)
from .serde import Serializable, Deserializable
from .rename import (
    snake_to_camel,
    camel_to_snake,
    snake_to_pascal,
    snake_to_screaming,
    apply_rename,
)
from .transform import FieldInfo, fields, field_names, as_type, replace, replace_int
from .validate import (
    ValidationError,
    check_min,
    check_max,
    check_range,
    check_exclusive_min,
    check_exclusive_max,
    check_min_float,
    check_max_float,
    check_exclusive_min_float,
    check_exclusive_max_float,
    check_non_empty,
    check_min_length,
    check_max_length,
    check_equal,
    check_not_equal,
    check_one_of,
    raise_if_errors,
)
from .schema import json_schema, json_schema_described
from .cli import parse_args, parse_args_positional, parse_args_nested, usage
from .csv import csv_header, to_csv_row, to_csv, from_csv_row, from_csv
from .toml import to_toml, from_toml
from .yaml import to_yaml, from_yaml
