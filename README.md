# morph

Reflection-driven serialization, deserialization, and data transformation for Mojo.

Inspired by [reflect-cpp](https://github.com/getml/reflect-cpp), zero-boilerplate struct serde using compile-time reflection.

## Why morph?

Mojo structs don't serialize out of the box. `morph` uses compile-time reflection to automatically map struct fields to/from JSON, CSV, and CLI arguments (no manual `to_json()` or `from_json()` methods needed).

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
morph = { git = "https://github.com/ehsanmok/morph.git" }
```

Then run:

```bash
pixi install
```

## Supported Types

| Type | JSON | CSV | CLI | TOML | YAML |
|------|------|-----|-----|------|------|
| `Int`, `Int64` | yes | yes | yes | planned | planned |
| `Bool` | yes | yes | yes (flag) | planned | planned |
| `Float64`, `Float32` | yes | yes | yes | planned | planned |
| `String` | yes | yes | yes | planned | planned |
| `Optional[T]` | yes (null) | no | yes | planned | planned |
| `List[T]` | yes | no | yes (comma) | planned | planned |
| Nested structs | yes | no | no | planned | planned |
| Custom traits | yes | no | no | planned | planned |

Where `T` is one of `Int`, `String`, `Float64`, `Bool`.

**CSV limitations** (inherent to the format):
CSV is flat/tabular -- Optional needs an empty-string convention, List needs delimiter sub-fields, nested structs need column flattening.

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

### CSV Serde

```mojo
from morph import to_csv, from_csv, csv_header, to_csv_row

var csv = to_csv(record)        # header + data row
var rows = from_csv[Record](csv_string)  # parse CSV to List[Record]
```

- Auto-generates header from field names
- Handles quoted fields (commas, newlines, double quotes)
- Multi-row serialization with `to_csv_multi`

### Format Backend Trait

Extensible format system for future TOML/YAML/MessagePack:

```mojo
from morph.format import FormatBackend

struct MyFormat(FormatBackend):
    def serialize[T: AnyType](self, value: T) raises -> String: ...
    def deserialize[T: Morphable](self, data: String) raises -> T: ...
    def file_extension(self) -> String: ...
```

## Modules

| Module | Description |
|--------|-------------|
| `morph.json.writer` | Struct -> JSON serialization |
| `morph.json.reader` | JSON -> struct deserialization |
| `morph.reflect` | Type introspection utilities |
| `morph.rename` | Naming convention converters |
| `morph.serde` | Custom Serializable/Deserializable traits |
| `morph.transform` | Struct introspection: fields(), as_type() |
| `morph.validate` | Runtime validation functions |
| `morph.schema` | JSON Schema generation |
| `morph.cli` | CLI argument parsing from struct definition |
| `morph.csv` | CSV serialization/deserialization |
| `morph.format` | FormatBackend trait for pluggable formats |

## Development

```bash
git clone https://github.com/ehsanmok/morph.git && cd morph
pixi install
pixi run tests
```

### Tasks

```bash
pixi run tests            # Run all 180 tests + examples
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
pixi run examples         # Run all 9 examples
pixi run example-basic    # 01: Basic struct serde
pixi run example-nested   # 02: Nested structs
pixi run example-optional # 03: Optional and List fields
pixi run example-custom   # 04: Custom Serializable/Deserializable traits
pixi run example-rename   # 05: Field renaming strategies
pixi run example-transform # 06: Introspection, serde options, as_type
pixi run example-validate # 07: Validation and JSON Schema
pixi run example-cli      # 08: CLI argument parsing
pixi run example-csv      # 09: CSV serialization/deserialization
pixi run format           # Format code
pixi run docs             # Generate and open API docs
```

## Feature Parity with reflect-cpp

morph provides Mojo-idiomatic equivalents of [reflect-cpp](https://github.com/getml/reflect-cpp)'s
core features. Where C++ uses enums, Mojo uses struct constants + validators. Where C++ uses
`std::variant`, Mojo uses `Variant[*Ts]`. This is an apple-to-apple comparison.

| Feature | Status | Mojo approach |
|---------|--------|---------------|
| JSON serde (scalars, Optional, List, nested, custom) | Done | `write()` / `read()` |
| CSV serde (flat structs) | Done | `to_csv()` / `from_csv()` |
| Field renaming (camel, Pascal, SCREAMING) | Done | `rename` param |
| Skip/Default/Strict/NoOptionals processors | Done | Compile-time params |
| Type discriminator (`add_type`) | Done | `add_type` param |
| Array serialization (`as_array`) | Done | `as_array` param |
| Validation (min/max, exclusive, range, length, one_of) | Done | `check_*` functions |
| Enum-like values | Done | `check_one_of` (Mojo's idiom) |
| JSON Schema (Draft 2020-12) | Done | `json_schema[T]()` |
| Struct introspection (fields, as_type, replace) | Done | `fields()`, `replace()` |
| CLI parsing (flags, Optional, List, short flags) | Done | `parse_args[T]()` |
| Custom serde traits | Done | `Serializable` / `Deserializable` |
| Format backend trait | Done (stub) | `FormatBackend` for TOML/YAML |

### Remaining work

- `Flatten` -- embed sub-struct fields at the same JSON level
- `Description` / `Deprecated` annotations for JSON Schema
- CLI positional args, nested structs (`--server.port`)
- TOML backend (pure Mojo parser)
- msgpack backend (pure Mojo binary format)

### Mojo language limitations

These affect implementation style, not whether features exist:

| Limitation | Impact | Current approach |
|-----------|--------|-----------------|
| No field attributes | Per-field metadata | Global params + naming conventions |
| No generic decomposition | Bounded container types | `comptime if` chains for known types |
| No Variant reflection | TaggedUnion serde | Manual dispatch per union |
| No regex | Pattern validation | Character-by-character |

## License

[MIT](./LICENSE)
