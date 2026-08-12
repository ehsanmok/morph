"""Tests for gap-closing features: exclusive validators, replace,
CLI Optional/List/short/nested/positional, no_optionals, flatten, schema descriptions."""

from morph.validate import (
    check_exclusive_min,
    check_exclusive_max,
    check_exclusive_min_float,
    check_exclusive_max_float,
    ValidationError,
    raise_if_errors,
)
from morph.transform import fields, field_names, replace, replace_int, as_type
from morph.cli import (
    parse_args,
    parse_args_nested,
    parse_args_positional,
    usage,
)
from morph.json.reader import read, read_flat
from morph.json.writer import write, write_flat
from morph.schema import json_schema, json_schema_described
from std.collections import Dict
from std.collections import List, Optional
from std.testing import assert_equal, assert_true


# ---------------------------------------------------------------------------
# Test structs
# ---------------------------------------------------------------------------


@fieldwise_init
struct Person(Defaultable, Movable):
    var name: String
    var age: Int
    var active: Bool

    def __init__(out self):
        self.name = ""
        self.age = 0
        self.active = False


@fieldwise_init
struct Address(Defaultable, Movable):
    var street: String
    var city: String

    def __init__(out self):
        self.street = ""
        self.city = ""


@fieldwise_init
struct PersonWithAddress(Defaultable, Movable):
    var name: String
    var age: Int
    var address: Address

    def __init__(out self):
        self.name = ""
        self.age = 0
        self.address = Address()


@fieldwise_init
struct OptionalConfig(Defaultable, Movable):
    var host: String
    var port: Optional[Int]
    var label: Optional[String]
    var verbose: Optional[Bool]

    def __init__(out self):
        self.host = "localhost"
        self.port = None
        self.label = None
        self.verbose = None


@fieldwise_init
struct ListConfig(Defaultable, Movable):
    var name: String
    var tags: List[String]
    var ports: List[Int]

    def __init__(out self):
        self.name = ""
        self.tags = List[String]()
        self.ports = List[Int]()


@fieldwise_init
struct ShortOpts(Defaultable, Movable):
    var verbose: Bool
    var port: Int
    var host: String

    def __init__(out self):
        self.verbose = False
        self.port = 8080
        self.host = "localhost"


@fieldwise_init
struct ServerConfig(Defaultable, Movable):
    var host: String
    var port: Int

    def __init__(out self):
        self.host = "localhost"
        self.port = 8080


@fieldwise_init
struct AppConfig(Defaultable, Movable):
    var name: String
    var server: ServerConfig
    var verbose: Bool

    def __init__(out self):
        self.name = "app"
        self.server = ServerConfig()
        self.verbose = False


@fieldwise_init
struct CmdArgs(Defaultable, Movable):
    var input_file: String
    var output_file: String
    var verbose: Bool

    def __init__(out self):
        self.input_file = ""
        self.output_file = ""
        self.verbose = False


# ---------------------------------------------------------------------------
# Exclusive validators
# ---------------------------------------------------------------------------


def test_exclusive_min_pass() raises:
    var err = check_exclusive_min(5, 3, "value")
    assert_true(not err)


def test_exclusive_min_fail_equal() raises:
    var err = check_exclusive_min(3, 3, "value")
    assert_true(err.__bool__())
    assert_true("> 3" in err.value().message)


def test_exclusive_min_fail_below() raises:
    var err = check_exclusive_min(2, 3, "value")
    assert_true(err.__bool__())


def test_exclusive_max_pass() raises:
    var err = check_exclusive_max(3, 5, "value")
    assert_true(not err)


def test_exclusive_max_fail_equal() raises:
    var err = check_exclusive_max(5, 5, "value")
    assert_true(err.__bool__())
    assert_true("< 5" in err.value().message)


def test_exclusive_max_fail_above() raises:
    var err = check_exclusive_max(6, 5, "value")
    assert_true(err.__bool__())


def test_exclusive_min_float_pass() raises:
    var err = check_exclusive_min_float(0.1, 0.0, "rate")
    assert_true(not err)


def test_exclusive_min_float_fail() raises:
    var err = check_exclusive_min_float(0.0, 0.0, "rate")
    assert_true(err.__bool__())


def test_exclusive_max_float_pass() raises:
    var err = check_exclusive_max_float(0.9, 1.0, "rate")
    assert_true(not err)


def test_exclusive_max_float_fail() raises:
    var err = check_exclusive_max_float(1.0, 1.0, "rate")
    assert_true(err.__bool__())


# ---------------------------------------------------------------------------
# replace
# ---------------------------------------------------------------------------


def test_replace_string_field() raises:
    var p = Person(name="Alice", age=30, active=True)
    var p2 = replace[Person, "name"](p, "Bob")
    assert_equal(p2.name, "Bob")
    assert_equal(p2.age, 30)
    assert_equal(p2.active, True)


def test_replace_int_field() raises:
    var p = Person(name="Alice", age=30, active=True)
    var p2 = replace_int[Person, "age"](p, 99)
    assert_equal(p2.name, "Alice")
    assert_equal(p2.age, 99)
    assert_equal(p2.active, True)


# ---------------------------------------------------------------------------
# CLI Optional support
# ---------------------------------------------------------------------------


def test_cli_optional_provided() raises:
    var args = List[String]()
    args.append("--host")
    args.append("myhost")
    args.append("--port")
    args.append("9090")
    args.append("--label")
    args.append("prod")
    args.append("--verbose")

    var cfg = parse_args[OptionalConfig](args)
    assert_equal(cfg.host, "myhost")
    assert_true(cfg.port.__bool__())
    assert_equal(cfg.port.value(), 9090)
    assert_true(cfg.label.__bool__())
    assert_equal(cfg.label.value(), "prod")
    assert_true(cfg.verbose.__bool__())
    assert_equal(cfg.verbose.value(), True)


def test_cli_optional_defaults() raises:
    var args = List[String]()
    args.append("--host")
    args.append("myhost")

    var cfg = parse_args[OptionalConfig](args)
    assert_equal(cfg.host, "myhost")
    assert_true(not cfg.port.__bool__())
    assert_true(not cfg.label.__bool__())
    assert_true(not cfg.verbose.__bool__())


# ---------------------------------------------------------------------------
# CLI List support
# ---------------------------------------------------------------------------


def test_cli_list_strings() raises:
    var args = List[String]()
    args.append("--name")
    args.append("app")
    args.append("--tags")
    args.append("web,api,prod")

    var cfg = parse_args[ListConfig](args)
    assert_equal(cfg.name, "app")
    assert_equal(len(cfg.tags), 3)
    assert_equal(cfg.tags[0], "web")
    assert_equal(cfg.tags[1], "api")
    assert_equal(cfg.tags[2], "prod")


def test_cli_list_ints() raises:
    var args = List[String]()
    args.append("--name")
    args.append("srv")
    args.append("--ports")
    args.append("80,443,8080")

    var cfg = parse_args[ListConfig](args)
    assert_equal(len(cfg.ports), 3)
    assert_equal(cfg.ports[0], 80)
    assert_equal(cfg.ports[1], 443)
    assert_equal(cfg.ports[2], 8080)


# ---------------------------------------------------------------------------
# CLI short flags
# ---------------------------------------------------------------------------


def test_cli_short_flag_bool() raises:
    var args = List[String]()
    args.append("-v")

    var opts = parse_args[ShortOpts](args)
    assert_equal(opts.verbose, True)
    assert_equal(opts.port, 8080)


def test_cli_short_flag_value() raises:
    var args = List[String]()
    args.append("-p")
    args.append("3000")

    var opts = parse_args[ShortOpts](args)
    assert_equal(opts.port, 3000)


def test_cli_mixed_short_long() raises:
    var args = List[String]()
    args.append("-v")
    args.append("--host")
    args.append("myhost")
    args.append("-p")
    args.append("9090")

    var opts = parse_args[ShortOpts](args)
    assert_equal(opts.verbose, True)
    assert_equal(opts.host, "myhost")
    assert_equal(opts.port, 9090)


# ---------------------------------------------------------------------------
# CLI usage with new types
# ---------------------------------------------------------------------------


def test_cli_usage_optional_list() raises:
    var u = usage[OptionalConfig]()
    assert_true("--host" in u)
    assert_true("--port" in u)
    assert_true("--label" in u)
    assert_true("--verbose" in u)

    var u2 = usage[ListConfig]()
    assert_true("--tags" in u2)
    assert_true("--ports" in u2)


# ---------------------------------------------------------------------------
# no_optionals processor
# ---------------------------------------------------------------------------


def test_no_optionals_rejects_null() raises:
    var json = '{"host":"x","port":null,"label":"hi","verbose":true}'
    var raised = False
    try:
        _ = read[OptionalConfig, no_optionals=True](json)
    except e:
        raised = True
        assert_true("null" in String(e))
        assert_true("no_optionals" in String(e))
    assert_true(raised)


def test_no_optionals_accepts_values() raises:
    var json = '{"host":"x","port":9090,"label":"hi","verbose":true}'
    var cfg = read[OptionalConfig, no_optionals=True](json)
    assert_equal(cfg.host, "x")
    assert_true(cfg.port.__bool__())
    assert_equal(cfg.port.value(), 9090)


def test_no_optionals_off_allows_null() raises:
    var json = '{"host":"x","port":null,"label":null,"verbose":null}'
    var cfg = read[OptionalConfig](json)
    assert_equal(cfg.host, "x")
    assert_true(not cfg.port.__bool__())


# ---------------------------------------------------------------------------
# Flatten
# ---------------------------------------------------------------------------


def test_write_flat_basic() raises:
    var addr = Address(street="123 Main St", city="Springfield")
    var p = PersonWithAddress(name="Alice", age=30, address=addr^)
    var json = write_flat(p)
    assert_true('"name":"Alice"' in json)
    assert_true('"street":"123 Main St"' in json)
    assert_true('"city":"Springfield"' in json)
    assert_true('"address"' not in json)


def test_write_flat_roundtrip() raises:
    var addr = Address(street="456 Oak Ave", city="Portland")
    var p = PersonWithAddress(name="Bob", age=25, address=addr^)
    var json = write_flat(p)
    var p2 = read_flat[PersonWithAddress](json)
    assert_equal(p2.name, "Bob")
    assert_equal(p2.age, 25)
    assert_equal(p2.address.street, "456 Oak Ave")
    assert_equal(p2.address.city, "Portland")


def test_read_flat_from_json() raises:
    var json = '{"name":"Carol","age":40,"street":"789 Pine","city":"Denver"}'
    var p = read_flat[PersonWithAddress](json)
    assert_equal(p.name, "Carol")
    assert_equal(p.age, 40)
    assert_equal(p.address.street, "789 Pine")
    assert_equal(p.address.city, "Denver")


# ---------------------------------------------------------------------------
# JSON Schema descriptions
# ---------------------------------------------------------------------------


def test_schema_described_basic() raises:
    var descs = Dict[String, String]()
    descs["name"] = "The person's full name"
    descs["age"] = "Age in years"
    var schema = json_schema_described[Person](descs)
    assert_true(
        '"description":"The person\'s full name"' in schema
        or '"description":"The person' in schema
    )
    assert_true('"description":"Age in years"' in schema)


def test_schema_described_deprecated() raises:
    var descs = Dict[String, String]()
    descs["_deprecated"] = "active"
    var schema = json_schema_described[Person](descs)
    assert_true('"deprecated":true' in schema)


def test_schema_described_with_title() raises:
    var descs = Dict[String, String]()
    descs["name"] = "Full name"
    var schema = json_schema_described[Person, title="PersonSchema"](descs)
    assert_true('"title":"PersonSchema"' in schema)
    assert_true('"description":"Full name"' in schema)


# ---------------------------------------------------------------------------
# CLI nested structs
# ---------------------------------------------------------------------------


def test_cli_nested_basic() raises:
    var args = List[String]()
    args.append("--name")
    args.append("myapp")
    args.append("--server.port")
    args.append("9090")
    args.append("--server.host")
    args.append("0.0.0.0")

    var cfg = parse_args_nested[AppConfig](args)
    assert_equal(cfg.name, "myapp")
    assert_equal(cfg.server.port, 9090)
    assert_equal(cfg.server.host, "0.0.0.0")


def test_cli_nested_mixed() raises:
    var args = List[String]()
    args.append("--verbose")
    args.append("--server.port")
    args.append("3000")

    var cfg = parse_args_nested[AppConfig](args)
    assert_equal(cfg.verbose, True)
    assert_equal(cfg.server.port, 3000)
    assert_equal(cfg.server.host, "localhost")


# ---------------------------------------------------------------------------
# CLI positional args
# ---------------------------------------------------------------------------


def test_cli_positional_basic() raises:
    var args = List[String]()
    args.append("input.txt")
    args.append("output.txt")
    args.append("--verbose")

    var cmd = parse_args_positional[CmdArgs](args)
    assert_equal(cmd.input_file, "input.txt")
    assert_equal(cmd.output_file, "output.txt")
    assert_equal(cmd.verbose, True)


def test_cli_positional_flags_only() raises:
    var args = List[String]()
    args.append("--input-file")
    args.append("in.csv")
    args.append("--output-file")
    args.append("out.csv")

    var cmd = parse_args_positional[CmdArgs](args)
    assert_equal(cmd.input_file, "in.csv")
    assert_equal(cmd.output_file, "out.csv")


def test_cli_positional_mixed() raises:
    var args = List[String]()
    args.append("data.json")
    args.append("-v")
    args.append("--output-file")
    args.append("result.json")

    var cmd = parse_args_positional[CmdArgs](args)
    assert_equal(cmd.input_file, "data.json")
    assert_equal(cmd.output_file, "result.json")
    assert_equal(cmd.verbose, True)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------


def main() raises:
    print("=== New features tests ===")

    test_exclusive_min_pass()
    print("  PASS: test_exclusive_min_pass")
    test_exclusive_min_fail_equal()
    print("  PASS: test_exclusive_min_fail_equal")
    test_exclusive_min_fail_below()
    print("  PASS: test_exclusive_min_fail_below")
    test_exclusive_max_pass()
    print("  PASS: test_exclusive_max_pass")
    test_exclusive_max_fail_equal()
    print("  PASS: test_exclusive_max_fail_equal")
    test_exclusive_max_fail_above()
    print("  PASS: test_exclusive_max_fail_above")
    test_exclusive_min_float_pass()
    print("  PASS: test_exclusive_min_float_pass")
    test_exclusive_min_float_fail()
    print("  PASS: test_exclusive_min_float_fail")
    test_exclusive_max_float_pass()
    print("  PASS: test_exclusive_max_float_pass")
    test_exclusive_max_float_fail()
    print("  PASS: test_exclusive_max_float_fail")

    test_replace_string_field()
    print("  PASS: test_replace_string_field")
    test_replace_int_field()
    print("  PASS: test_replace_int_field")

    test_cli_optional_provided()
    print("  PASS: test_cli_optional_provided")
    test_cli_optional_defaults()
    print("  PASS: test_cli_optional_defaults")

    test_cli_list_strings()
    print("  PASS: test_cli_list_strings")
    test_cli_list_ints()
    print("  PASS: test_cli_list_ints")

    test_cli_short_flag_bool()
    print("  PASS: test_cli_short_flag_bool")
    test_cli_short_flag_value()
    print("  PASS: test_cli_short_flag_value")
    test_cli_mixed_short_long()
    print("  PASS: test_cli_mixed_short_long")

    test_cli_usage_optional_list()
    print("  PASS: test_cli_usage_optional_list")

    test_no_optionals_rejects_null()
    print("  PASS: test_no_optionals_rejects_null")
    test_no_optionals_accepts_values()
    print("  PASS: test_no_optionals_accepts_values")
    test_no_optionals_off_allows_null()
    print("  PASS: test_no_optionals_off_allows_null")

    test_write_flat_basic()
    print("  PASS: test_write_flat_basic")
    test_write_flat_roundtrip()
    print("  PASS: test_write_flat_roundtrip")
    test_read_flat_from_json()
    print("  PASS: test_read_flat_from_json")

    test_schema_described_basic()
    print("  PASS: test_schema_described_basic")
    test_schema_described_deprecated()
    print("  PASS: test_schema_described_deprecated")
    test_schema_described_with_title()
    print("  PASS: test_schema_described_with_title")

    test_cli_nested_basic()
    print("  PASS: test_cli_nested_basic")
    test_cli_nested_mixed()
    print("  PASS: test_cli_nested_mixed")

    test_cli_positional_basic()
    print("  PASS: test_cli_positional_basic")
    test_cli_positional_flags_only()
    print("  PASS: test_cli_positional_flags_only")
    test_cli_positional_mixed()
    print("  PASS: test_cli_positional_mixed")

    print("=== All 34 new feature tests passed ===")
