# morph

[![CI](https://github.com/ehsanmok/morph/actions/workflows/ci.yml/badge.svg)](https://github.com/ehsanmok/morph/actions/workflows/ci.yml)
[![Docs](https://github.com/ehsanmok/morph/actions/workflows/docs.yaml/badge.svg)](https://ehsanmok.github.io/morph/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Reflection-driven serialization, deserialization, and data transformation for Mojo.

Inspired by [reflect-cpp](https://github.com/getml/reflect-cpp), zero-boilerplate struct serde using compile-time reflection.

## Why morph?

Mojo structs don't serialize out of the box. `morph` uses compile-time reflection to automatically map struct fields to/from JSON, CSV, TOML, YAML, and CLI arguments (no manual `to_json()` or `from_json()` methods needed).

```mojo
from morph import write, read

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

## Requirements

[pixi](https://pixi.sh) package manager

## Installation

Add morph to your project's `pixi.toml`:

```toml
[workspace]
channels = ["https://conda.modular.com/max-nightly", "conda-forge"]
preview = ["pixi-build"]

[dependencies]
morph = { git = "https://github.com/ehsanmok/morph.git", branch = "main" }
```

Then run:

```bash
pixi install
```

## Supported Types

| Type | JSON | CSV | CLI | TOML | YAML |
|------|------|-----|-----|------|------|
| `Int`, `Int64` | yes | yes | yes | yes | yes |
| `Bool` | yes | yes | yes (flag) | yes | yes |
| `Float64`, `Float32` | yes | yes | yes | yes | yes |
| `String` | yes | yes | yes | yes | yes |
| `Optional[T]` | yes (null) | no | yes | yes (omit if None) | yes (null) |
| `List[T]` | yes | no | yes (comma) | yes (arrays) | yes (sequences) |
| Nested structs | yes | no | yes (dot-notation) | yes (tables) | yes (indented) |
| Custom traits | yes | no | no | no | no |

Where `T` is one of `Int`, `String`, `Float64`, `Bool`.

**CSV limitations** (inherent to the format):
CSV is flat/tabular: Optional needs an empty-string convention, List needs delimiter sub-fields, nested structs need column flattening.

## Features

### Core Serde

- **Zero boilerplate**: works on any struct via compile-time reflection
- **Round-trip safe**: `read(write(x))` preserves data
- **Custom serde**: implement `Serializable`/`Deserializable` to override
- **Pretty print**: `write[pretty=True](value)` for formatted output
- **Rich errors**: type mismatch, missing field, invalid JSON

### Field Renaming

Convert between naming conventions at the serde boundary:

```mojo
var json = write[rename="camelCase"](my_struct)
var obj = read[MyStruct, rename="camelCase"](json)
```

Supported: `camelCase`, `PascalCase`, `SCREAMING_SNAKE`, `none` (default).

### Serde Options

```mojo
# Skip fields starting with underscore
var json = write[skip_private=True](value)

# Add type discriminator field
var json = write[add_type=True](value)  # {"_type":"MyStruct",...}

# Serialize as array (no field names)
var json = write[as_array=True](value)  # [1,"hello",true]

# Default missing fields instead of raising
var obj = read[MyStruct, default_if_missing=True](json)

# Strict mode: reject unknown keys
var obj = read[MyStruct, strict=True](json)

# Reject null on Optional fields
var obj = read[MyStruct, no_optionals=True](json)
```

### Struct Introspection

```mojo
from morph import fields, field_names, as_type, replace, replace_int

var info = fields[Person]()    # List[FieldInfo] with name/type
var names = field_names[Person]()  # List[String]

# Convert between struct types (copies matching fields)
var employee = as_type[Employee](person)

# Copy with one field changed
var updated = replace[Person, "name"](person, "Bob")
var older = replace_int[Person, "age"](person, 31)
```

### Validation

Runtime validators return `Optional[ValidationError]`:

```mojo
from morph import check_min, check_max, check_range, check_exclusive_min,
    check_exclusive_max, check_non_empty, check_min_length, check_max_length,
    check_one_of, raise_if_errors

var errors = List[ValidationError]()
var e1 = check_min(config.age, 0, "age")            # age >= 0
if e1: errors.append(e1.value().copy())
var e2 = check_exclusive_max(config.age, 150, "age") # age < 150
if e2: errors.append(e2.value().copy())
var e3 = check_non_empty(config.name, "name")
if e3: errors.append(e3.value().copy())
var e4 = check_one_of(config.status, allowed, "status")  # enum-like
if e4: errors.append(e4.value().copy())
raise_if_errors(errors)
```

**Enum-like validation**: Mojo uses structs instead of C++ enums. Use `check_one_of`
with a list of allowed strings to validate enum-like values.

### JSON Schema Generation

```mojo
from morph import json_schema

var schema = json_schema[Config]()
var schema_titled = json_schema[Config, title="AppConfig"]()
var schema_renamed = json_schema[Config, rename="camelCase"]()
```

Generates Draft 2020-12 compatible schema with `type`, `properties`, `required`.

Add descriptions and deprecated markers:

```mojo
from morph import json_schema_described
from std.collections import Dict

var descriptions = Dict[String, String]()
descriptions["host"] = "Server hostname"
descriptions["port"] = "Server port"
descriptions["_deprecated"] = "log_level"  # Mark field as deprecated
var schema = json_schema_described[Config](descriptions)
```

### Flatten (Nested Struct Embedding)

Serialize/deserialize nested structs with their fields at the parent level:

```mojo
from morph import write_flat, read_flat

@fieldwise_init
struct Address(Defaultable, Movable):
    var street: String
    var city: String
    def __init__(out self):
        self.street = ""
        self.city = ""

@fieldwise_init
struct Person(Defaultable, Movable):
    var name: String
    var address: Address
    def __init__(out self):
        self.name = ""
        self.address = Address()

var p = Person(name="Alice", address=Address(street="123 Main", city="NYC"))
var json = write_flat(p)
# {"name":"Alice","street":"123 Main","city":"NYC"}

var restored = read_flat[Person](json)
```

### CLI Parsing

Parse command-line arguments directly into a struct:

```mojo
from morph import parse_args, usage

@fieldwise_init
struct Config(Defaultable, Movable):
    var host: String
    var port: Int
    var verbose: Bool
    var tags: List[String]
    var label: Optional[String]

    def __init__(out self):
        self.host = "localhost"
        self.port = 8080
        self.verbose = False
        self.tags = List[String]()
        self.label = None

def main() raises:
    var args = List[String]("-v", "--host", "0.0.0.0", "--port", "9090", "--tags", "web,api")
    var config = parse_args[Config](args)
    print(usage[Config]())
```

- Underscore fields become hyphenated flags: `max_retries` -> `--max-retries`
- Bool fields are flags (no value needed): `--verbose` or `-v`
- Short flags: first letter of field name (`-p` for `port`, `-h` for `host`)
- `Optional[T]` fields are non-required (default to None if omitted)
- `List[T]` fields accept comma-separated values: `--tags=web,api,prod`
- Other types require a value: `--port 9090`

**Nested structs** with dot-notation:

```mojo
from morph import parse_args_nested

@fieldwise_init
struct ServerConfig(Defaultable, Movable):
    var host: String
    var port: Int
    def __init__(out self):
        self.host = "localhost"
        self.port = 8080

@fieldwise_init
struct AppConfig(Defaultable, Movable):
    var debug: Bool
    var server: ServerConfig
    def __init__(out self):
        self.debug = False
        self.server = ServerConfig()

var args = List[String]("--debug", "--server.host", "0.0.0.0", "--server.port", "9090")
var config = parse_args_nested[AppConfig](args)
# config.server.host == "0.0.0.0", config.server.port == 9090
```

**Positional arguments** (non-flag args assigned to String fields in order):

```mojo
from morph import parse_args_positional

var args = List[String]("input.txt", "output.txt", "--verbose")
var config = parse_args_positional[CmdArgs](args)
# config.source == "input.txt", config.dest == "output.txt", config.verbose == True
```

### CSV Serde

```mojo
from morph import to_csv, from_csv, csv_header, to_csv_row

var csv = to_csv(record)        # header + data row
var rows = from_csv[Record](csv_string)  # parse CSV to List[Record]
```

- Auto-generates header from field names
- Handles quoted fields (commas, newlines, double quotes)
- Multi-row serialization with `to_csv_multi`

### TOML Serde

```mojo
from morph.toml import to_toml, from_toml

var toml = to_toml(config)
var cfg = from_toml[Config](toml_str)
```

- Scalars, Optional, List, nested structs (as TOML tables)
- Optional fields omitted when `None`
- Lists serialized as inline TOML arrays
- Supports field renaming (`rename` param)

### YAML Serde

```mojo
from morph.yaml import to_yaml, from_yaml

var yaml = to_yaml(person)
var p = from_yaml[Person](yaml_str)
```

- Indentation-based YAML subset (no anchors, aliases, or tags)
- Block sequences for lists, indented mappings for nested structs
- Optional fields serialize as `null` when `None`
- Handles `yes`/`no`/`on`/`off` as bool, `~` as null
- Supports field renaming (`rename` param)

### Format Backend Trait

Extensible format system for additional formats:

```mojo
from morph.format import FormatBackend

struct MyFormat(FormatBackend):
    def serialize[T: AnyType](self, value: T) raises -> String: ...
    def deserialize[T: Morphable](self, data: String) raises -> T: ...
    def file_extension(self) -> String: ...
```

Full API reference: [ehsanmok.github.io/morph](https://ehsanmok.github.io/morph/)

## Development

```bash
git clone https://github.com/ehsanmok/morph.git && cd morph
pixi install
pixi run tests
```

### Tasks

```bash
pixi run tests            # Run all 215 tests + examples
pixi run test-serialize   # Run serialize tests only
pixi run test-deserialize
pixi run test-roundtrip
pixi run test-edge-cases
pixi run test-reflect
pixi run test-rename
pixi run test-transform   # Rename, skip_private, transform, defaults
pixi run test-validate    # Validation, JSON Schema
pixi run test-processors  # Processors integration (add_type, strict, as_array)
pixi run test-cli-csv     # CLI parsing, CSV serde, string validators
pixi run test-new-features # Exclusive validators, replace, CLI Optional/List/short
pixi run test-toml-yaml   # TOML and YAML serde (24 tests)
pixi run examples         # Run all 11 examples
pixi run example-basic    # 01: Basic struct serde
pixi run example-nested   # 02: Nested structs
pixi run example-optional # 03: Optional and List fields
pixi run example-custom   # 04: Custom Serializable/Deserializable traits
pixi run example-rename   # 05: Field renaming strategies
pixi run example-transform # 06: Introspection, serde options, as_type
pixi run example-validate # 07: Validation and JSON Schema
pixi run example-cli      # 08: CLI argument parsing
pixi run example-csv      # 09: CSV serialization/deserialization
pixi run example-toml     # 10: TOML serialization/deserialization
pixi run example-yaml     # 11: YAML serialization/deserialization
pixi run format           # Format code
pixi run docs             # Generate and open API docs
```

## License

[MIT](./LICENSE)
