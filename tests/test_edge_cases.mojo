"""Tests for edge cases and boundary conditions.

Covers: zero values, large numbers, empty containers, whitespace in JSON,
extra whitespace, deeply nested structures, many fields.
"""

from morph.json import write, read
from std.collections import Optional, List
from std.testing import assert_equal, assert_true


# ---------------------------------------------------------------------------
# Test structs
# ---------------------------------------------------------------------------


@fieldwise_init
struct SingleField(Defaultable, Movable):
    var value: Int

    def __init__(out self):
        self.value = 0


@fieldwise_init
struct ManyFields(Defaultable, Movable):
    var a: Int
    var b: Int
    var c: Int
    var d: String
    var e: Bool
    var f: Float64

    def __init__(out self):
        self.a = 0
        self.b = 0
        self.c = 0
        self.d = ""
        self.e = False
        self.f = 0.0


@fieldwise_init
struct Point(Defaultable, Movable):
    var x: Int
    var y: Int

    def __init__(out self):
        self.x = 0
        self.y = 0


@fieldwise_init
struct Wrapper(Defaultable, Movable):
    var inner: Point

    def __init__(out self):
        self.inner = Point()


@fieldwise_init
struct Deep(Defaultable, Movable):
    var w: Wrapper

    def __init__(out self):
        self.w = Wrapper()


@fieldwise_init
struct StringHolder(Defaultable, Movable):
    var v: String

    def __init__(out self):
        self.v = ""


@fieldwise_init
struct OptStringHolder(Defaultable, Movable):
    var v: Optional[String]

    def __init__(out self):
        self.v = None


# ---------------------------------------------------------------------------
# Zero / default value tests
# ---------------------------------------------------------------------------


def test_all_zeros() raises:
    var s = ManyFields()
    var json = write(s)
    assert_true('"a":0' in json)
    assert_true('"d":""' in json)
    assert_true('"e":false' in json)


def test_zero_roundtrip() raises:
    var s = ManyFields()
    var r = read[ManyFields](write(s))
    assert_equal(r.a, 0)
    assert_equal(r.d, "")
    assert_equal(r.e, False)


# ---------------------------------------------------------------------------
# Large numbers
# ---------------------------------------------------------------------------


def test_large_int() raises:
    var s = SingleField(value=999999999)
    var r = read[SingleField](write(s))
    assert_equal(r.value, 999999999)


def test_negative_int() raises:
    var s = SingleField(value=-999999999)
    var r = read[SingleField](write(s))
    assert_equal(r.value, -999999999)


# ---------------------------------------------------------------------------
# JSON with whitespace
# ---------------------------------------------------------------------------


def test_json_with_spaces() raises:
    var p = read[Point]('{ "x" : 10 , "y" : 20 }')
    assert_equal(p.x, 10)
    assert_equal(p.y, 20)


def test_json_with_newlines() raises:
    var p = read[Point]('{\n  "x": 1,\n  "y": 2\n}')
    assert_equal(p.x, 1)
    assert_equal(p.y, 2)


# ---------------------------------------------------------------------------
# Single field struct
# ---------------------------------------------------------------------------


def test_single_field_write() raises:
    assert_equal(write(SingleField(value=42)), '{"value":42}')


def test_single_field_read() raises:
    var s = read[SingleField]('{"value":42}')
    assert_equal(s.value, 42)


# ---------------------------------------------------------------------------
# Many fields struct
# ---------------------------------------------------------------------------


def test_many_fields_roundtrip() raises:
    var s = ManyFields(a=1, b=2, c=3, d="test", e=True, f=9.99)
    var r = read[ManyFields](write(s))
    assert_equal(r.a, 1)
    assert_equal(r.b, 2)
    assert_equal(r.c, 3)
    assert_equal(r.d, "test")
    assert_equal(r.e, True)


# ---------------------------------------------------------------------------
# Deep nesting
# ---------------------------------------------------------------------------


def test_deep_nesting() raises:
    var d = Deep(w=Wrapper(inner=Point(x=7, y=8)))
    var json = write(d)
    assert_true('"x":7' in json)
    assert_true('"y":8' in json)

    var r = read[Deep](json)
    assert_equal(r.w.inner.x, 7)
    assert_equal(r.w.inner.y, 8)


# ---------------------------------------------------------------------------
# String edge cases
# ---------------------------------------------------------------------------


def test_empty_string_field() raises:
    var s = StringHolder(v="")
    var r = read[StringHolder](write(s))
    assert_equal(r.v, "")


def test_long_string_field() raises:
    var long = String("a") * 1000
    var s = StringHolder(v=long)
    var r = read[StringHolder](write(s))
    assert_equal(r.v.byte_length(), 1000)


# ---------------------------------------------------------------------------
# Optional edge cases
# ---------------------------------------------------------------------------


def test_optional_with_empty_string() raises:
    var s = OptStringHolder(v=String(""))
    var r = read[OptStringHolder](write(s))
    assert_true(r.v.__bool__(), "empty string optional should be present")
    assert_equal(r.v.value(), "")


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------


def main() raises:
    print("=== morph edge case tests ===")

    test_all_zeros()
    print("  PASS: test_all_zeros")

    test_zero_roundtrip()
    print("  PASS: test_zero_roundtrip")

    test_large_int()
    print("  PASS: test_large_int")

    test_negative_int()
    print("  PASS: test_negative_int")

    test_json_with_spaces()
    print("  PASS: test_json_with_spaces")

    test_json_with_newlines()
    print("  PASS: test_json_with_newlines")

    test_single_field_write()
    print("  PASS: test_single_field_write")

    test_single_field_read()
    print("  PASS: test_single_field_read")

    test_many_fields_roundtrip()
    print("  PASS: test_many_fields_roundtrip")

    test_deep_nesting()
    print("  PASS: test_deep_nesting")

    test_empty_string_field()
    print("  PASS: test_empty_string_field")

    test_long_string_field()
    print("  PASS: test_long_string_field")

    test_optional_with_empty_string()
    print("  PASS: test_optional_with_empty_string")

    print("=== All 13 edge case tests passed ===")
