"""Example 07: Validation and JSON Schema generation.

Demonstrates: check_* validators, raise_if_errors, json_schema[T]().
"""

from morph.validate import (
    ValidationError,
    check_min,
    check_max,
    check_range,
    check_non_empty,
    check_min_length,
    check_one_of,
    raise_if_errors,
)
from morph.schema import json_schema
from std.collections import List


@fieldwise_init
struct Config(Defaultable, Movable):
    var host: String
    var port: Int
    var log_level: String
    var max_connections: Int

    def __init__(out self):
        self.host = ""
        self.port = 0
        self.log_level = ""
        self.max_connections = 0


def _make_levels() -> List[String]:
    var levels = List[String]()
    levels.append("debug")
    levels.append("info")
    levels.append("warn")
    levels.append("error")
    return levels^


def validate_config(config: Config) raises:
    """Validate a Config struct using morph validators."""
    var errors = List[ValidationError]()

    var e1 = check_non_empty(config.host, "host")
    if e1:
        errors.append(e1.value().copy())

    var e2 = check_range(config.port, 1, 65535, "port")
    if e2:
        errors.append(e2.value().copy())

    var levels = _make_levels()
    var e3 = check_one_of(config.log_level, levels, "log_level")
    if e3:
        errors.append(e3.value().copy())

    var e4 = check_min(config.max_connections, 1, "max_connections")
    if e4:
        errors.append(e4.value().copy())

    raise_if_errors(errors)


def main() raises:
    print("=== Validation: Valid Config ===\n")

    var good = Config(
        host="localhost", port=8080, log_level="info", max_connections=100
    )
    validate_config(good)
    print("Config is valid!")

    print("\n=== Validation: Invalid Config ===\n")

    var bad = Config(
        host="", port=99999, log_level="verbose", max_connections=0
    )
    try:
        validate_config(bad)
    except e:
        print("Validation errors:\n" + String(e))

    print("\n=== Individual Validators ===\n")

    var e1 = check_min(-5, 0, "age")
    if e1:
        print("check_min: " + e1.value().message)

    var e2 = check_max(150, 100, "score")
    if e2:
        print("check_max: " + e2.value().message)

    var e3 = check_min_length("ab", 8, "password")
    if e3:
        print("check_min_length: " + e3.value().message)

    print("\n=== JSON Schema Generation ===\n")

    var schema = json_schema[Config]()
    print("Schema:\n" + schema)

    print("\nWith title:")
    var titled = json_schema[Config, title="AppConfig"]()
    print(titled)

    print("\nWith camelCase rename:")
    var renamed = json_schema[Config, rename="camelCase"]()
    print(renamed)
