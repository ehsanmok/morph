"""Reflection-powered serialization, deserialization, and validation for Mojo.

Inspired by reflect-cpp, morph uses compile-time reflection to automatically
map Mojo structs to and from serialization formats with zero boilerplate.
No manual `to_json()` or `from_json()` methods needed.

## Quick Start

```mojo
from morph.json import write, read

@fieldwise_init
struct Person(Defaultable, Movable):
    var name: String
    var age: Int
    var active: Bool

    def __init__(out self):
        self.name = ""
        self.age = 0
        self.active = False

def main() raises:
    var p = Person(name="Alice", age=30, active=True)
    print(write(p))         # {"name":"Alice","age":30,"active":true}

    var q = read[Person]('{"name":"Bob","age":25,"active":false}')
    print(q.name)            # Bob
```

## Supported Types

| Type                | JSON | CSV | CLI       | TOML           | YAML           |
|---------------------|------|-----|-----------|----------------|----------------|
| Int, Int64          | yes  | yes | yes       | yes            | yes            |
| Bool                | yes  | yes | yes (flag)| yes            | yes            |
| Float64, Float32    | yes  | yes | yes       | yes            | yes            |
| String              | yes  | yes | yes       | yes            | yes            |
| Optional[T]         | yes  | no  | yes       | yes (omit)     | yes (null)     |
| List[T]             | yes  | no  | yes (csv) | yes (arrays)   | yes (sequences)|
| Nested structs      | yes  | no  | yes (dot) | yes (tables)   | yes (indented) |
| Custom traits       | yes  | no  | no        | no             | no             |

Where T is one of Int, String, Float64, Bool.

## Features

### Core Serde

Zero-boilerplate struct mapping via compile-time reflection. Round-trip safe:
`read(write(x))` preserves data. Rich errors for type mismatch, missing fields,
and invalid input.

### Serde Options

```mojo
var json = write[pretty=True](value)           # formatted output
var json = write[rename="camelCase"](value)     # field renaming
var json = write[skip_private=True](value)      # skip underscore fields
var json = write[add_type=True](value)          # type discriminator
var json = write[as_array=True](value)          # array serialization
var obj = read[T, default_if_missing=True](s)   # default missing fields
var obj = read[T, strict=True](s)               # reject unknown keys
```

Renaming strategies: camelCase, PascalCase, SCREAMING_SNAKE, none (default).

### Struct Introspection

```mojo
from morph import fields, field_names, as_type, replace, replace_int

var info = fields[Person]()           # List[FieldInfo] with name/type
var names = field_names[Person]()     # List[String]
var employee = as_type[Employee](person)  # copy matching fields
var updated = replace[Person, "name"](person, "Bob")
```

### Validation

Runtime validators return Optional[ValidationError]:

```mojo
from morph import check_min, check_range, check_non_empty,
    check_one_of, raise_if_errors

var errors = List[ValidationError]()
var e1 = check_min(config.age, 0, "age")
if e1: errors.append(e1.value().copy())
raise_if_errors(errors)
```

### JSON Schema Generation

```mojo
from morph import json_schema, json_schema_described

var schema = json_schema[Config]()
var schema_titled = json_schema[Config, title="AppConfig"]()
```

Generates Draft 2020-12 compatible schema with type, properties, required.

### Flatten (Nested Struct Embedding)

```mojo
from morph.json import write_flat, read_flat

var json = write_flat(person)     # nested fields at parent level
var p = read_flat[Person](json)
```

### CLI Parsing

Parse command-line arguments directly into a struct:

```mojo
from morph import parse_args, parse_args_nested, usage

var config = parse_args[Config](args)
var nested = parse_args_nested[AppConfig](args)  # --server.host 0.0.0.0
print(usage[Config]())
```

Underscore fields become hyphenated flags (max_retries -> --max-retries).
Bool fields are flags (no value needed). Short flags use the first letter.
Optional fields are non-required. List fields accept comma-separated values.

### CSV Serde

```mojo
from morph import to_csv, from_csv

var csv = to_csv(record)                     # header + data row
var rows = from_csv[Record](csv_string)      # parse CSV to List[Record]
```

### TOML Serde

```mojo
from morph.toml import to_toml, from_toml

var toml = to_toml(config)
var cfg = from_toml[Config](toml_str)
```

Scalars, Optional, List, and nested structs (as TOML tables).

### YAML Serde

```mojo
from morph.yaml import to_yaml, from_yaml

var yaml = to_yaml(person)
var p = from_yaml[Person](yaml_str)
```

Indentation-based YAML subset. Block sequences for lists, indented mappings
for nested structs. Handles yes/no/on/off as bool, ~ as null.

### Format Backend Trait

Extensible format system for additional formats:

```mojo
from morph.format import FormatBackend

struct MyFormat(FormatBackend):
    def serialize[T: AnyType](self, value: T) raises -> String: ...
    def deserialize[T: Morphable](self, data: String) raises -> T: ...
    def file_extension(self) -> String: ...
```

## Modules

| Module             | Description                                          |
|--------------------|------------------------------------------------------|
| morph.json         | JSON serialization/deserialization (self-contained)  |
| morph.toml         | TOML serialization/deserialization (pure Mojo)       |
| morph.yaml         | YAML serialization/deserialization (pure Mojo)       |
| morph.reflect      | Core reflection utilities (type matchers, fields)    |
| morph.serde        | Serializable/Deserializable traits for custom serde  |
| morph.rename       | Field renaming strategies (snake_case, camelCase)    |
| morph.transform    | Struct introspection and composition (fields, as_type)|
| morph.validate     | Runtime validation functions (min, max, one_of)      |
| morph.schema       | JSON Schema generation (Draft 2020-12)               |
| morph.cli          | CLI argument parsing from struct definitions         |
| morph.csv          | CSV serialization/deserialization                    |
| morph.format       | FormatBackend trait for pluggable formats             |
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
from .transform import (
    FieldInfo,
    fields,
    field_names,
    as_type,
    replace,
    replace_int,
)
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
