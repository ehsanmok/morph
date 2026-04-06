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
from .transform import FieldInfo, fields, field_names, as_type
