"""Phase 3 tests: validation and JSON Schema generation."""

from morph.validate import (
    ValidationError,
    check_min,
    check_max,
    check_range,
    check_min_float,
    check_max_float,
    check_non_empty,
    check_min_length,
    check_max_length,
    check_equal,
    check_not_equal,
    check_one_of,
    raise_if_errors,
)
from morph.schema import json_schema
from std.collections import List, Optional
from std.testing import assert_equal, assert_true


# ---------------------------------------------------------------------------
# Test structs
# ---------------------------------------------------------------------------


@fieldwise_init
struct PersonSchema(Defaultable, Movable):
    var name: String
    var age: Int

    def __init__(out self):
        self.name = ""
        self.age = 0


@fieldwise_init
struct WithOptional(Defaultable, Movable):
    var required_field: String
    var optional_field: Optional[Int]

    def __init__(out self):
        self.required_field = ""
        self.optional_field = None


@fieldwise_init
struct WithList(Defaultable, Movable):
    var tags: List[String]
    var scores: List[Int]

    def __init__(out self):
        self.tags = List[String]()
        self.scores = List[Int]()


@fieldwise_init
struct FullTypes(Defaultable, Movable):
    var name: String
    var count: Int
    var score: Float64
    var active: Bool
    var opt_name: Optional[String]
    var items: List[String]

    def __init__(out self):
        self.name = ""
        self.count = 0
        self.score = 0.0
        self.active = False
        self.opt_name = None
        self.items = List[String]()


# ---------------------------------------------------------------------------
# Validation tests: check_min / check_max
# ---------------------------------------------------------------------------


def test_check_min_pass() raises:
    var err = check_min(10, 5, "port")
    assert_true(not err)


def test_check_min_fail() raises:
    var err = check_min(3, 5, "port")
    assert_true(err.__bool__())
    assert_equal(err.value().field, "port")
    assert_true(">= 5" in err.value().message)


def test_check_max_pass() raises:
    var err = check_max(10, 100, "port")
    assert_true(not err)


def test_check_max_fail() raises:
    var err = check_max(200, 100, "port")
    assert_true(err.__bool__())
    assert_true("<= 100" in err.value().message)


def test_check_range_pass() raises:
    var err = check_range(50, 1, 100, "score")
    assert_true(not err)


def test_check_range_fail_low() raises:
    var err = check_range(-1, 0, 100, "score")
    assert_true(err.__bool__())
    assert_true("[0, 100]" in err.value().message)


def test_check_range_fail_high() raises:
    var err = check_range(150, 0, 100, "score")
    assert_true(err.__bool__())


# ---------------------------------------------------------------------------
# Float validators
# ---------------------------------------------------------------------------


def test_check_min_float_pass() raises:
    var err = check_min_float(3.14, 0.0, "temp")
    assert_true(not err)


def test_check_min_float_fail() raises:
    var err = check_min_float(-1.5, 0.0, "temp")
    assert_true(err.__bool__())
    assert_true(">= 0" in err.value().message)


def test_check_max_float_pass() raises:
    var err = check_max_float(50.0, 100.0, "pct")
    assert_true(not err)


def test_check_max_float_fail() raises:
    var err = check_max_float(150.0, 100.0, "pct")
    assert_true(err.__bool__())


# ---------------------------------------------------------------------------
# String validators
# ---------------------------------------------------------------------------


def test_check_non_empty_pass() raises:
    var err = check_non_empty("hello", "name")
    assert_true(not err)


def test_check_non_empty_fail() raises:
    var err = check_non_empty("", "name")
    assert_true(err.__bool__())
    assert_true("not be empty" in err.value().message)


def test_check_min_length_pass() raises:
    var err = check_min_length("hello", 3, "name")
    assert_true(not err)


def test_check_min_length_fail() raises:
    var err = check_min_length("hi", 3, "name")
    assert_true(err.__bool__())
    assert_true(">= 3" in err.value().message)


def test_check_max_length_pass() raises:
    var err = check_max_length("hi", 10, "name")
    assert_true(not err)


def test_check_max_length_fail() raises:
    var err = check_max_length("a very long string", 5, "name")
    assert_true(err.__bool__())
    assert_true("<= 5" in err.value().message)


# ---------------------------------------------------------------------------
# Equality validators
# ---------------------------------------------------------------------------


def test_check_equal_pass() raises:
    var err = check_equal(42, 42, "answer")
    assert_true(not err)


def test_check_equal_fail() raises:
    var err = check_equal(43, 42, "answer")
    assert_true(err.__bool__())
    assert_true("must equal 42" in err.value().message)


def test_check_not_equal_pass() raises:
    var err = check_not_equal(5, 0, "divisor")
    assert_true(not err)


def test_check_not_equal_fail() raises:
    var err = check_not_equal(0, 0, "divisor")
    assert_true(err.__bool__())
    assert_true("must not equal 0" in err.value().message)


# ---------------------------------------------------------------------------
# One-of validator
# ---------------------------------------------------------------------------


def _make_levels() -> List[String]:
    var lst = List[String]()
    lst.append("debug")
    lst.append("info")
    lst.append("warn")
    lst.append("error")
    return lst^


def test_check_one_of_pass() raises:
    var allowed = _make_levels()
    var err = check_one_of("info", allowed, "level")
    assert_true(not err)


def test_check_one_of_fail() raises:
    var allowed = _make_levels()
    var err = check_one_of("trace", allowed, "level")
    assert_true(err.__bool__())
    assert_true("must be one of" in err.value().message)
    assert_true("'trace'" in err.value().message)


# ---------------------------------------------------------------------------
# Multi-error aggregation
# ---------------------------------------------------------------------------


def test_raise_if_errors_no_errors() raises:
    var errors = List[ValidationError]()
    raise_if_errors(errors)


def test_raise_if_errors_with_errors() raises:
    var errors = List[ValidationError]()
    errors.append(ValidationError(field="name", message="empty"))
    errors.append(ValidationError(field="age", message="negative"))
    var raised = False
    try:
        raise_if_errors(errors)
    except e:
        raised = True
        assert_true("2 errors" in String(e))
        assert_true("name: empty" in String(e))
        assert_true("age: negative" in String(e))
    assert_true(raised)


# ---------------------------------------------------------------------------
# JSON Schema tests
# ---------------------------------------------------------------------------


def test_schema_basic_struct() raises:
    var s = json_schema[PersonSchema]()
    assert_true('"type":"object"' in s)
    assert_true('"name":{"type":"string"}' in s)
    assert_true('"age":{"type":"integer"}' in s)
    assert_true('"required":[' in s)
    assert_true('"name"' in s)
    assert_true('"age"' in s)


def test_schema_with_optional() raises:
    var s = json_schema[WithOptional]()
    assert_true('"required_field":{"type":"string"}' in s)
    assert_true('"optional_field":{"type":["integer","null"]}' in s)
    assert_true('"required_field"' in s)


def test_schema_with_list() raises:
    var s = json_schema[WithList]()
    assert_true('"tags":{"type":"array","items":{"type":"string"}}' in s)
    assert_true('"scores":{"type":"array","items":{"type":"integer"}}' in s)


def test_schema_full_types() raises:
    var s = json_schema[FullTypes]()
    assert_true('"type":"object"' in s)
    assert_true('"name":{"type":"string"}' in s)
    assert_true('"count":{"type":"integer"}' in s)
    assert_true('"score":{"type":"number"}' in s)
    assert_true('"active":{"type":"boolean"}' in s)
    assert_true('"opt_name":{"type":["string","null"]}' in s)
    assert_true('"items":{"type":"array","items":{"type":"string"}}' in s)


def test_schema_with_title() raises:
    var s = json_schema[PersonSchema, title="Person"]()
    assert_true('"title":"Person"' in s)


def test_schema_with_rename() raises:
    var s = json_schema[PersonSchema, rename="camelCase"]()
    assert_true('"name":' in s)  # 'name' stays same
    assert_true('"age":' in s)  # 'age' stays same (no underscores)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------


def main() raises:
    print("=== Phase 3 tests ===")

    test_check_min_pass()
    print("  PASS: test_check_min_pass")
    test_check_min_fail()
    print("  PASS: test_check_min_fail")
    test_check_max_pass()
    print("  PASS: test_check_max_pass")
    test_check_max_fail()
    print("  PASS: test_check_max_fail")
    test_check_range_pass()
    print("  PASS: test_check_range_pass")
    test_check_range_fail_low()
    print("  PASS: test_check_range_fail_low")
    test_check_range_fail_high()
    print("  PASS: test_check_range_fail_high")

    test_check_min_float_pass()
    print("  PASS: test_check_min_float_pass")
    test_check_min_float_fail()
    print("  PASS: test_check_min_float_fail")
    test_check_max_float_pass()
    print("  PASS: test_check_max_float_pass")
    test_check_max_float_fail()
    print("  PASS: test_check_max_float_fail")

    test_check_non_empty_pass()
    print("  PASS: test_check_non_empty_pass")
    test_check_non_empty_fail()
    print("  PASS: test_check_non_empty_fail")
    test_check_min_length_pass()
    print("  PASS: test_check_min_length_pass")
    test_check_min_length_fail()
    print("  PASS: test_check_min_length_fail")
    test_check_max_length_pass()
    print("  PASS: test_check_max_length_pass")
    test_check_max_length_fail()
    print("  PASS: test_check_max_length_fail")

    test_check_equal_pass()
    print("  PASS: test_check_equal_pass")
    test_check_equal_fail()
    print("  PASS: test_check_equal_fail")
    test_check_not_equal_pass()
    print("  PASS: test_check_not_equal_pass")
    test_check_not_equal_fail()
    print("  PASS: test_check_not_equal_fail")

    test_check_one_of_pass()
    print("  PASS: test_check_one_of_pass")
    test_check_one_of_fail()
    print("  PASS: test_check_one_of_fail")

    test_raise_if_errors_no_errors()
    print("  PASS: test_raise_if_errors_no_errors")
    test_raise_if_errors_with_errors()
    print("  PASS: test_raise_if_errors_with_errors")

    test_schema_basic_struct()
    print("  PASS: test_schema_basic_struct")
    test_schema_with_optional()
    print("  PASS: test_schema_with_optional")
    test_schema_with_list()
    print("  PASS: test_schema_with_list")
    test_schema_full_types()
    print("  PASS: test_schema_full_types")
    test_schema_with_title()
    print("  PASS: test_schema_with_title")
    test_schema_with_rename()
    print("  PASS: test_schema_with_rename")

    print("=== All 30 Phase 3 tests passed ===")
