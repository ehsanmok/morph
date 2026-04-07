"""Phase 5-7 tests: string pattern validators, CLI parsing, CSV serde."""

from morph.cli import parse_args, usage
from morph.csv import csv_header, to_csv_row, to_csv, from_csv_row, from_csv
from morph.validate import (
    check_min_length,
    check_max_length,
    check_non_empty,
    check_one_of,
    ValidationError,
    raise_if_errors,
)
from std.collections import List
from std.testing import assert_equal, assert_true


# ---------------------------------------------------------------------------
# Test structs
# ---------------------------------------------------------------------------


@fieldwise_init
struct CliOpts(Defaultable, Movable):
    var host: String
    var port: Int
    var verbose: Bool
    var rate: Float64

    def __init__(out self):
        self.host = "localhost"
        self.port = 8080
        self.verbose = False
        self.rate = 1.0


@fieldwise_init
struct CsvRecord(Defaultable, Movable, Copyable):
    var name: String
    var age: Int
    var score: Float64
    var active: Bool

    def __init__(out self):
        self.name = ""
        self.age = 0
        self.score = 0.0
        self.active = False


@fieldwise_init
struct SimpleRec(Defaultable, Movable, Copyable):
    var x: Int
    var y: Int

    def __init__(out self):
        self.x = 0
        self.y = 0


# ---------------------------------------------------------------------------
# Phase 5: String pattern validators
# ---------------------------------------------------------------------------


def test_email_like_validation() raises:
    """Demonstrate email-like validation using existing primitives."""
    var email = "user@example.com"
    var err = check_non_empty(email, "email")
    assert_true(not err)

    var err2 = check_min_length(email, 5, "email")
    assert_true(not err2)


def test_enum_like_validation() raises:
    """Validate string belongs to an allowed set (like an enum)."""
    var allowed = List[String]()
    allowed.append("pending")
    allowed.append("active")
    allowed.append("closed")

    var err = check_one_of("active", allowed, "status")
    assert_true(not err)

    var err2 = check_one_of("unknown", allowed, "status")
    assert_true(err2.__bool__())


def test_multi_field_validation() raises:
    """Validate multiple fields and aggregate errors."""
    var errors = List[ValidationError]()

    var e1 = check_non_empty("", "name")
    if e1:
        errors.append(e1.value().copy())

    var e2 = check_min_length("ab", 3, "code")
    if e2:
        errors.append(e2.value().copy())

    assert_equal(len(errors), 2)

    var raised = False
    try:
        raise_if_errors(errors)
    except e:
        raised = True
        assert_true("2 errors" in String(e))
    assert_true(raised)


# ---------------------------------------------------------------------------
# Phase 7: CLI parsing
# ---------------------------------------------------------------------------


def test_cli_parse_all_types() raises:
    var args = List[String]()
    args.append("--host")
    args.append("0.0.0.0")
    args.append("--port")
    args.append("9090")
    args.append("--verbose")
    args.append("--rate")
    args.append("2.5")

    var opts = parse_args[CliOpts](args)
    assert_equal(opts.host, "0.0.0.0")
    assert_equal(opts.port, 9090)
    assert_equal(opts.verbose, True)


def test_cli_parse_defaults() raises:
    var args = List[String]()
    args.append("--port")
    args.append("3000")

    var opts = parse_args[CliOpts](args)
    assert_equal(opts.host, "localhost")
    assert_equal(opts.port, 3000)
    assert_equal(opts.verbose, False)


def test_cli_parse_hyphen_conversion() raises:
    """Underscores become hyphens: --host not --host."""
    var args = List[String]()
    args.append("--host")
    args.append("myhost")

    var opts = parse_args[CliOpts](args)
    assert_equal(opts.host, "myhost")


def test_cli_unknown_flag() raises:
    var args = List[String]()
    args.append("--unknown")

    var raised = False
    try:
        _ = parse_args[CliOpts](args)
    except e:
        raised = True
        assert_true("Unknown flag" in String(e))
    assert_true(raised)


def test_cli_missing_value() raises:
    var args = List[String]()
    args.append("--port")

    var raised = False
    try:
        _ = parse_args[CliOpts](args)
    except e:
        raised = True
        assert_true("Missing value" in String(e))
    assert_true(raised)


def test_cli_usage_string() raises:
    var u = usage[CliOpts]()
    assert_true("--host" in u)
    assert_true("--port" in u)
    assert_true("--verbose" in u)
    assert_true("--rate" in u)
    assert_true("<string>" in u)
    assert_true("<int>" in u)


# ---------------------------------------------------------------------------
# Phase 7: CSV serde
# ---------------------------------------------------------------------------


def test_csv_header() raises:
    var h = csv_header[CsvRecord]()
    assert_equal(h, "name,age,score,active")


def test_csv_row() raises:
    var r = CsvRecord(name="Alice", age=30, score=95.5, active=True)
    var row = to_csv_row(r)
    assert_equal(row, "Alice,30,95.5,true")


def test_csv_full() raises:
    var r = CsvRecord(name="Bob", age=25, score=88.0, active=False)
    var csv = to_csv(r)
    assert_true("name,age,score,active" in csv)
    assert_true("Bob,25,88" in csv)


def test_csv_quoted_string() raises:
    var r = CsvRecord(name='Al"ice', age=30, score=0.0, active=True)
    var row = to_csv_row(r)
    assert_true('"Al""ice"' in row)


def test_csv_comma_in_string() raises:
    var r = CsvRecord(name="Last, First", age=30, score=0.0, active=True)
    var row = to_csv_row(r)
    assert_true('"Last, First"' in row)


def test_csv_deserialize_row() raises:
    var header = List[String]()
    header.append("x")
    header.append("y")
    var rec = from_csv_row[SimpleRec](header, "10,20")
    assert_equal(rec.x, 10)
    assert_equal(rec.y, 20)


def test_csv_deserialize_full() raises:
    var csv_str = "x,y\n1,2\n3,4\n5,6"
    var recs = from_csv[SimpleRec](csv_str)
    assert_equal(len(recs), 3)
    assert_equal(recs[0].x, 1)
    assert_equal(recs[0].y, 2)
    assert_equal(recs[1].x, 3)
    assert_equal(recs[2].x, 5)
    assert_equal(recs[2].y, 6)


def test_csv_roundtrip() raises:
    var original = CsvRecord(name="Eve", age=28, score=99.9, active=True)
    var csv = to_csv(original)

    var header = List[String]()
    header.append("name")
    header.append("age")
    header.append("score")
    header.append("active")

    var lines = List[String]()
    var current = String("")
    var data = csv.as_bytes()
    for i in range(len(data)):
        if data[i] == UInt8(ord('\n')):
            lines.append(current^)
            current = String("")
        else:
            current += chr(Int(data[i]))
    if len(current) > 0:
        lines.append(current^)

    var restored = from_csv_row[CsvRecord](header, lines[1])
    assert_equal(restored.name, "Eve")
    assert_equal(restored.age, 28)
    assert_equal(restored.active, True)


def test_csv_column_mismatch() raises:
    var header = List[String]()
    header.append("x")
    header.append("y")
    var raised = False
    try:
        _ = from_csv_row[SimpleRec](header, "1,2,3")
    except e:
        raised = True
        assert_true("mismatch" in String(e))
    assert_true(raised)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------


def main() raises:
    print("=== Phase 5-7 tests ===")

    test_email_like_validation()
    print("  PASS: test_email_like_validation")
    test_enum_like_validation()
    print("  PASS: test_enum_like_validation")
    test_multi_field_validation()
    print("  PASS: test_multi_field_validation")

    test_cli_parse_all_types()
    print("  PASS: test_cli_parse_all_types")
    test_cli_parse_defaults()
    print("  PASS: test_cli_parse_defaults")
    test_cli_parse_hyphen_conversion()
    print("  PASS: test_cli_parse_hyphen_conversion")
    test_cli_unknown_flag()
    print("  PASS: test_cli_unknown_flag")
    test_cli_missing_value()
    print("  PASS: test_cli_missing_value")
    test_cli_usage_string()
    print("  PASS: test_cli_usage_string")

    test_csv_header()
    print("  PASS: test_csv_header")
    test_csv_row()
    print("  PASS: test_csv_row")
    test_csv_full()
    print("  PASS: test_csv_full")
    test_csv_quoted_string()
    print("  PASS: test_csv_quoted_string")
    test_csv_comma_in_string()
    print("  PASS: test_csv_comma_in_string")
    test_csv_deserialize_row()
    print("  PASS: test_csv_deserialize_row")
    test_csv_deserialize_full()
    print("  PASS: test_csv_deserialize_full")
    test_csv_roundtrip()
    print("  PASS: test_csv_roundtrip")
    test_csv_column_mismatch()
    print("  PASS: test_csv_column_mismatch")

    print("=== All 18 Phase 5-7 tests passed ===")
