"""Phase 4 tests: processor features (AddStructName, NoExtraFields,
combined processor scenarios).

Note: AddStructName is `add_type=True` and NoExtraFields is `strict=True`,
both already implemented in Phase 2. This suite verifies combined usage
and integration with other features.
"""

from morph.json import write, read
from morph.schema import json_schema
from morph.validate import check_min, check_non_empty, raise_if_errors, ValidationError
from std.collections import Optional, List
from std.testing import assert_equal, assert_true


# ---------------------------------------------------------------------------
# Test structs
# ---------------------------------------------------------------------------


@fieldwise_init
struct Config(Defaultable, Movable):
    var host: String
    var port: Int
    var debug: Bool

    def __init__(out self):
        self.host = "localhost"
        self.port = 8080
        self.debug = False


@fieldwise_init
struct Nested(Defaultable, Movable):
    var inner_name: String
    var inner_value: Int

    def __init__(out self):
        self.inner_name = ""
        self.inner_value = 0


@fieldwise_init
struct Outer(Defaultable, Movable):
    var label: String
    var nested: Nested

    def __init__(out self):
        self.label = ""
        self.nested = Nested()


@fieldwise_init
struct Tagged(Defaultable, Movable):
    var id: Int
    var status: String

    def __init__(out self):
        self.id = 0
        self.status = ""


@fieldwise_init
struct Mixed(Defaultable, Movable):
    var public_val: String
    var _private_val: Int

    def __init__(out self):
        self.public_val = ""
        self._private_val = 0


# ---------------------------------------------------------------------------
# AddStructName (add_type) tests
# ---------------------------------------------------------------------------


def test_add_type_config() raises:
    var c = Config(host="0.0.0.0", port=9090, debug=True)
    var json = write[add_type=True](c)
    assert_true('"type":"Config"' in json)
    assert_true('"host":"0.0.0.0"' in json)
    assert_true('"port":9090' in json)
    assert_true('"debug":true' in json)


def test_add_type_with_rename() raises:
    var c = Config(host="0.0.0.0", port=9090, debug=True)
    var json = write[add_type=True, rename="camelCase"](c)
    assert_true('"type":"Config"' in json)


def test_add_type_nested() raises:
    var o = Outer(label="test", nested=Nested(inner_name="x", inner_value=42))
    var json = write[add_type=True](o)
    assert_true('"type":"Outer"' in json)


# ---------------------------------------------------------------------------
# NoExtraFields (strict) tests
# ---------------------------------------------------------------------------


def test_strict_config() raises:
    var json = '{"host":"local","port":80,"debug":false}'
    var c = read[Config, strict=True](json)
    assert_equal(c.host, "local")
    assert_equal(c.port, 80)


def test_strict_rejects_unknown() raises:
    var json = '{"host":"local","port":80,"debug":false,"extra":"bad"}'
    var raised = False
    try:
        _ = read[Config, strict=True](json)
    except e:
        raised = True
        assert_true("Unknown JSON key" in String(e))
    assert_true(raised)


def test_strict_with_rename() raises:
    var json = '{"innerName":"test","innerValue":5}'
    var n = read[Nested, strict=True, rename="camelCase"](json)
    assert_equal(n.inner_name, "test")
    assert_equal(n.inner_value, 5)


# ---------------------------------------------------------------------------
# Combined processors
# ---------------------------------------------------------------------------


def test_full_pipeline_write() raises:
    """Test all write features combined."""
    var c = Config(host="prod", port=443, debug=False)
    var json = write[
        rename="camelCase",
        add_type=True,
    ](c)
    assert_true('"type":"Config"' in json)
    assert_true('"host":"prod"' in json)
    assert_true('"port":443' in json)


def test_full_pipeline_read_validate() raises:
    """Test read + validation pipeline."""
    var json = '{"host":"","port":-1,"debug":true}'
    var c = read[Config](json)

    var errors = List[ValidationError]()
    var e1 = check_non_empty(c.host, "host")
    if e1:
        errors.append(e1.value().copy())
    var e2 = check_min(c.port, 1, "port")
    if e2:
        errors.append(e2.value().copy())

    assert_equal(len(errors), 2)
    assert_equal(errors[0].field, "host")
    assert_equal(errors[1].field, "port")


def test_schema_and_validate_consistency() raises:
    """Schema and validation can describe the same constraints."""
    var schema = json_schema[Config, title="Config"]()
    assert_true('"title":"Config"' in schema)
    assert_true('"host":{"type":"string"}' in schema)
    assert_true('"port":{"type":"integer"}' in schema)
    assert_true('"debug":{"type":"boolean"}' in schema)
    assert_true('"required":[' in schema)


def test_roundtrip_with_all_features() raises:
    """Write with add_type + rename, then read back with rename + default."""
    var original = Config(host="prod.server.com", port=443, debug=False)
    var json = write[rename="camelCase", add_type=True](original)

    assert_true('"type":"Config"' in json)

    var restored = read[Config, rename="camelCase", default_if_missing=True](json)
    assert_equal(restored.host, "prod.server.com")
    assert_equal(restored.port, 443)
    assert_equal(restored.debug, False)


def test_as_array_and_read_back() raises:
    """Array mode write produces correct output."""
    var n = Nested(inner_name="test", inner_value=42)
    var json = write[as_array=True](n)
    assert_equal(json, '["test",42]')


def test_skip_private_with_strict() raises:
    """Skip private fields + strict mode should work together."""
    var json = '{"public_val":"hello"}'
    var m = read[Mixed, strict=True, skip_private=True](json)
    assert_equal(m.public_val, "hello")
    assert_equal(m._private_val, 0)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------


def main() raises:
    print("=== Phase 4 tests ===")

    test_add_type_config()
    print("  PASS: test_add_type_config")
    test_add_type_with_rename()
    print("  PASS: test_add_type_with_rename")
    test_add_type_nested()
    print("  PASS: test_add_type_nested")

    test_strict_config()
    print("  PASS: test_strict_config")
    test_strict_rejects_unknown()
    print("  PASS: test_strict_rejects_unknown")
    test_strict_with_rename()
    print("  PASS: test_strict_with_rename")

    test_full_pipeline_write()
    print("  PASS: test_full_pipeline_write")
    test_full_pipeline_read_validate()
    print("  PASS: test_full_pipeline_read_validate")
    test_schema_and_validate_consistency()
    print("  PASS: test_schema_and_validate_consistency")
    test_roundtrip_with_all_features()
    print("  PASS: test_roundtrip_with_all_features")
    test_as_array_and_read_back()
    print("  PASS: test_as_array_and_read_back")
    test_skip_private_with_strict()
    print("  PASS: test_skip_private_with_strict")

    print("=== All 12 Phase 4 tests passed ===")
