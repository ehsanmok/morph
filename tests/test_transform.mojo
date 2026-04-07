"""Phase 2 tests: rename integration, skip_private, default_if_missing,
strict mode, transform utilities (fields, as_type, field_names).
"""

from morph.json import write, read
from morph.transform import FieldInfo, fields, field_names, as_type
from std.collections import Optional, List
from std.testing import assert_equal, assert_true


# ---------------------------------------------------------------------------
# Test structs
# ---------------------------------------------------------------------------


@fieldwise_init
struct UserSnake(Defaultable, Movable):
    var first_name: String
    var last_name: String
    var is_active: Bool

    def __init__(out self):
        self.first_name = ""
        self.last_name = ""
        self.is_active = False


@fieldwise_init
struct WithPrivate(Defaultable, Movable):
    var name: String
    var _internal: Int
    var _cache: String

    def __init__(out self):
        self.name = ""
        self._internal = 0
        self._cache = ""


@fieldwise_init
struct Defaults(Defaultable, Movable):
    var name: String
    var age: Int
    var score: Float64

    def __init__(out self):
        self.name = "unknown"
        self.age = 0
        self.score = 0.0


@fieldwise_init
struct SourceA(Defaultable, Movable):
    var name: String
    var age: Int
    var email: String

    def __init__(out self):
        self.name = ""
        self.age = 0
        self.email = ""


@fieldwise_init
struct TargetB(Defaultable, Movable):
    var name: String
    var age: Int
    var role: String

    def __init__(out self):
        self.name = ""
        self.age = 0
        self.role = "member"


@fieldwise_init
struct Point(Defaultable, Movable):
    var x: Int
    var y: Int

    def __init__(out self):
        self.x = 0
        self.y = 0


@fieldwise_init
struct WithOptDefaults(Defaultable, Movable):
    var name: String
    var opt_val: Optional[Int]

    def __init__(out self):
        self.name = ""
        self.opt_val = None


# ---------------------------------------------------------------------------
# Rename write tests
# ---------------------------------------------------------------------------


def test_write_camel_case() raises:
    var u = UserSnake(first_name="Ada", last_name="Lovelace", is_active=True)
    var json = write[rename="camelCase"](u)
    assert_true('"firstName":"Ada"' in json)
    assert_true('"lastName":"Lovelace"' in json)
    assert_true('"isActive":true' in json)


def test_write_pascal_case() raises:
    var u = UserSnake(first_name="Ada", last_name="Lovelace", is_active=True)
    var json = write[rename="PascalCase"](u)
    assert_true('"FirstName":"Ada"' in json)
    assert_true('"LastName":"Lovelace"' in json)
    assert_true('"IsActive":true' in json)


def test_write_screaming_snake() raises:
    var u = UserSnake(first_name="Ada", last_name="Lovelace", is_active=True)
    var json = write[rename="SCREAMING_SNAKE_CASE"](u)
    assert_true('"FIRST_NAME":"Ada"' in json)
    assert_true('"LAST_NAME":"Lovelace"' in json)
    assert_true('"IS_ACTIVE":true' in json)


def test_write_rename_none() raises:
    var u = UserSnake(first_name="Ada", last_name="Lovelace", is_active=True)
    var json = write[rename="none"](u)
    assert_true('"first_name":"Ada"' in json)
    assert_true('"last_name":"Lovelace"' in json)


# ---------------------------------------------------------------------------
# Rename read tests
# ---------------------------------------------------------------------------


def test_read_camel_case() raises:
    var json = '{"firstName":"Grace","lastName":"Hopper","isActive":true}'
    var u = read[UserSnake, rename="camelCase"](json)
    assert_equal(u.first_name, "Grace")
    assert_equal(u.last_name, "Hopper")
    assert_equal(u.is_active, True)


def test_rename_roundtrip() raises:
    var original = UserSnake(
        first_name="Marie", last_name="Curie", is_active=True
    )
    var json = write[rename="camelCase"](original)
    var restored = read[UserSnake, rename="camelCase"](json)
    assert_equal(restored.first_name, "Marie")
    assert_equal(restored.last_name, "Curie")
    assert_equal(restored.is_active, True)


# ---------------------------------------------------------------------------
# Skip private tests
# ---------------------------------------------------------------------------


def test_skip_private_write() raises:
    var w = WithPrivate(name="visible", _internal=42, _cache="secret")
    var json = write[skip_private=True](w)
    assert_true('"name":"visible"' in json)
    assert_true("_internal" not in json)
    assert_true("_cache" not in json)


def test_skip_private_read() raises:
    var json = '{"name":"test"}'
    var w = read[WithPrivate, skip_private=True](json)
    assert_equal(w.name, "test")
    assert_equal(w._internal, 0)
    assert_equal(w._cache, "")


def test_skip_private_roundtrip() raises:
    var original = WithPrivate(name="test", _internal=99, _cache="data")
    var json = write[skip_private=True](original)
    var restored = read[WithPrivate, skip_private=True](json)
    assert_equal(restored.name, "test")
    assert_equal(restored._internal, 0)


# ---------------------------------------------------------------------------
# Default-if-missing tests
# ---------------------------------------------------------------------------


def test_default_if_missing() raises:
    var json = '{"name":"Alice"}'
    var d = read[Defaults, default_if_missing=True](json)
    assert_equal(d.name, "Alice")
    assert_equal(d.age, 0)
    assert_equal(d.score, 0.0)


def test_default_if_missing_empty_object() raises:
    var d = read[Defaults, default_if_missing=True]("{}")
    assert_equal(d.name, "unknown")
    assert_equal(d.age, 0)


def test_default_if_missing_opt() raises:
    var json = '{"name":"Bob"}'
    var w = read[WithOptDefaults, default_if_missing=True](json)
    assert_equal(w.name, "Bob")
    assert_true(not w.opt_val)


# ---------------------------------------------------------------------------
# Strict mode tests
# ---------------------------------------------------------------------------


def test_strict_rejects_extra_keys() raises:
    var json = '{"x":1,"y":2,"z":3}'
    var raised = False
    try:
        _ = read[Point, strict=True](json)
    except e:
        raised = True
        assert_true("Unknown JSON key 'z'" in String(e))
    assert_true(raised, "should raise on extra keys")


def test_strict_allows_exact_keys() raises:
    var json = '{"x":5,"y":10}'
    var p = read[Point, strict=True](json)
    assert_equal(p.x, 5)
    assert_equal(p.y, 10)


# ---------------------------------------------------------------------------
# AddStructName tests
# ---------------------------------------------------------------------------


def test_add_type_name() raises:
    var p = Point(x=1, y=2)
    var json = write[add_type=True](p)
    assert_true('"type":"Point"' in json)
    assert_true('"x":1' in json)
    assert_true('"y":2' in json)


# ---------------------------------------------------------------------------
# NoFieldNames (array mode) tests
# ---------------------------------------------------------------------------


def test_as_array() raises:
    var p = Point(x=3, y=7)
    var json = write[as_array=True](p)
    assert_equal(json, "[3,7]")


def test_as_array_with_strings() raises:
    var u = UserSnake(first_name="A", last_name="B", is_active=True)
    var json = write[as_array=True](u)
    assert_equal(json, '["A","B",true]')


# ---------------------------------------------------------------------------
# Transform: fields()
# ---------------------------------------------------------------------------


def test_fields_count() raises:
    var f = fields[Point]()
    assert_equal(len(f), 2)


def test_fields_names_and_types() raises:
    var f = fields[Point]()
    assert_equal(f[0].name, "x")
    assert_equal(f[1].name, "y")


def test_field_names_list() raises:
    var names = field_names[Point]()
    assert_equal(len(names), 2)
    assert_equal(names[0], "x")
    assert_equal(names[1], "y")


def test_fields_user_struct() raises:
    var f = fields[UserSnake]()
    assert_equal(len(f), 3)
    assert_equal(f[0].name, "first_name")
    assert_equal(f[1].name, "last_name")
    assert_equal(f[2].name, "is_active")


# ---------------------------------------------------------------------------
# Transform: as_type()
# ---------------------------------------------------------------------------


def test_as_type_matching_fields() raises:
    var src = SourceA(name="Alice", age=30, email="alice@test.com")
    var tgt = as_type[TargetB, SourceA](src)
    assert_equal(tgt.name, "Alice")
    assert_equal(tgt.age, 30)
    assert_equal(tgt.role, "member")


def test_as_type_no_matching_fields() raises:
    var p = Point(x=1, y=2)
    var d = as_type[Defaults, Point](p)
    assert_equal(d.name, "unknown")
    assert_equal(d.age, 0)


# ---------------------------------------------------------------------------
# Combined features
# ---------------------------------------------------------------------------


def test_rename_and_skip_private() raises:
    var w = WithPrivate(name="test", _internal=42, _cache="x")
    var json = write[rename="camelCase", skip_private=True](w)
    assert_true('"name":"test"' in json)
    assert_true("_internal" not in json)
    assert_true("_cache" not in json)


def test_rename_and_default_if_missing() raises:
    var json = '{"firstName":"Bob"}'
    var u = read[UserSnake, rename="camelCase", default_if_missing=True](json)
    assert_equal(u.first_name, "Bob")
    assert_equal(u.last_name, "")
    assert_equal(u.is_active, False)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------


def main() raises:
    print("=== Phase 2 tests ===")

    test_write_camel_case()
    print("  PASS: test_write_camel_case")

    test_write_pascal_case()
    print("  PASS: test_write_pascal_case")

    test_write_screaming_snake()
    print("  PASS: test_write_screaming_snake")

    test_write_rename_none()
    print("  PASS: test_write_rename_none")

    test_read_camel_case()
    print("  PASS: test_read_camel_case")

    test_rename_roundtrip()
    print("  PASS: test_rename_roundtrip")

    test_skip_private_write()
    print("  PASS: test_skip_private_write")

    test_skip_private_read()
    print("  PASS: test_skip_private_read")

    test_skip_private_roundtrip()
    print("  PASS: test_skip_private_roundtrip")

    test_default_if_missing()
    print("  PASS: test_default_if_missing")

    test_default_if_missing_empty_object()
    print("  PASS: test_default_if_missing_empty_object")

    test_default_if_missing_opt()
    print("  PASS: test_default_if_missing_opt")

    test_strict_rejects_extra_keys()
    print("  PASS: test_strict_rejects_extra_keys")

    test_strict_allows_exact_keys()
    print("  PASS: test_strict_allows_exact_keys")

    test_add_type_name()
    print("  PASS: test_add_type_name")

    test_as_array()
    print("  PASS: test_as_array")

    test_as_array_with_strings()
    print("  PASS: test_as_array_with_strings")

    test_fields_count()
    print("  PASS: test_fields_count")

    test_fields_names_and_types()
    print("  PASS: test_fields_names_and_types")

    test_field_names_list()
    print("  PASS: test_field_names_list")

    test_fields_user_struct()
    print("  PASS: test_fields_user_struct")

    test_as_type_matching_fields()
    print("  PASS: test_as_type_matching_fields")

    test_as_type_no_matching_fields()
    print("  PASS: test_as_type_no_matching_fields")

    test_rename_and_skip_private()
    print("  PASS: test_rename_and_skip_private")

    test_rename_and_default_if_missing()
    print("  PASS: test_rename_and_default_if_missing")

    print("=== All 25 Phase 2 tests passed ===")
