"""Tests for TOML and YAML serialization/deserialization.

Covers all supported types: Int, Bool, Float64, String, Optional, List,
nested structs for both formats.
"""

from std.testing import assert_equal, assert_true
from std.collections import Optional, List

from morph.toml import to_toml, from_toml
from morph.yaml import to_yaml, from_yaml


# ---------------------------------------------------------------------------
# Test structs
# ---------------------------------------------------------------------------


@fieldwise_init
struct Scalars(Defaultable, Movable):
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
struct WithOptional(Defaultable, Movable):
    var label: String
    var count: Optional[Int]
    var tag: Optional[String]
    var ratio: Optional[Float64]
    var flag: Optional[Bool]

    def __init__(out self):
        self.label = ""
        self.count = Optional[Int](None)
        self.tag = Optional[String](None)
        self.ratio = Optional[Float64](None)
        self.flag = Optional[Bool](None)


@fieldwise_init
struct WithList(Defaultable, Movable):
    var title: String
    var ids: List[Int]
    var tags: List[String]
    var scores: List[Float64]
    var flags: List[Bool]

    def __init__(out self):
        self.title = ""
        self.ids = List[Int]()
        self.tags = List[String]()
        self.scores = List[Float64]()
        self.flags = List[Bool]()


@fieldwise_init
struct Address(Defaultable, Movable):
    var city: String
    var zip_code: Int

    def __init__(out self):
        self.city = ""
        self.zip_code = 0


@fieldwise_init
struct Person(Defaultable, Movable):
    var name: String
    var age: Int
    var address: Address

    def __init__(out self):
        self.name = ""
        self.age = 0
        self.address = Address()


@fieldwise_init
struct ServerConfig(Defaultable, Movable):
    var host: String
    var port: Int
    var debug: Bool
    var workers: Int

    def __init__(out self):
        self.host = "localhost"
        self.port = 8080
        self.debug = False
        self.workers = 4


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_with_list() -> WithList:
    var w = WithList()
    w.title = "data"
    w.ids.append(1)
    w.ids.append(2)
    w.ids.append(3)
    w.tags.append("a")
    w.tags.append("b")
    w.scores.append(1.1)
    w.scores.append(2.2)
    w.flags.append(True)
    w.flags.append(False)
    return w^


# ---------------------------------------------------------------------------
# TOML Writer Tests
# ---------------------------------------------------------------------------


def test_toml_write_scalars() raises:
    var s = Scalars(name="Alice", age=30, score=95.5, active=True)
    var toml = to_toml(s)
    assert_true('name = "Alice"' in toml, "toml has name")
    assert_true("age = 30" in toml, "toml has age")
    assert_true("score = 95.5" in toml, "toml has score")
    assert_true("active = true" in toml, "toml has active")
    print("  PASS: test_toml_write_scalars (4 assertions)")


def test_toml_write_optional_some() raises:
    var w = WithOptional(
        label="test",
        count=Optional[Int](42),
        tag=Optional[String]("hi"),
        ratio=Optional[Float64](3.14),
        flag=Optional[Bool](True),
    )
    var toml = to_toml(w)
    assert_true('label = "test"' in toml, "toml has label")
    assert_true("count = 42" in toml, "toml has count")
    assert_true('tag = "hi"' in toml, "toml has tag")
    assert_true("flag = true" in toml, "toml has flag")
    print("  PASS: test_toml_write_optional_some (4 assertions)")


def test_toml_write_optional_none() raises:
    var w = WithOptional()
    w.label = "empty"
    var toml = to_toml(w)
    assert_true('label = "empty"' in toml, "toml has label")
    print("  PASS: test_toml_write_optional_none (1 assertion)")


def test_toml_write_list() raises:
    var w = _make_with_list()
    var toml = to_toml(w)
    assert_true('title = "data"' in toml, "toml has title")
    assert_true("ids = [1, 2, 3]" in toml, "toml has ids array")
    assert_true('tags = ["a", "b"]' in toml, "toml has tags array")
    assert_true("flags = [true, false]" in toml, "toml has flags array")
    print("  PASS: test_toml_write_list (4 assertions)")


def test_toml_write_nested() raises:
    var p = Person(name="Bob", age=25, address=Address(city="NYC", zip_code=10001))
    var toml = to_toml(p)
    assert_true('name = "Bob"' in toml, "toml has name")
    assert_true("[address]" in toml, "toml has [address] section")
    assert_true('city = "NYC"' in toml, "toml has city")
    assert_true("zip_code = 10001" in toml, "toml has zip")
    print("  PASS: test_toml_write_nested (4 assertions)")


# ---------------------------------------------------------------------------
# TOML Roundtrip Tests
# ---------------------------------------------------------------------------


def test_toml_roundtrip_scalars() raises:
    var s = Scalars(name="Alice", age=30, score=95.5, active=True)
    var toml = to_toml(s)
    var r = from_toml[Scalars](toml)
    assert_equal(r.name, "Alice")
    assert_equal(r.age, 30)
    assert_equal(r.score, 95.5)
    assert_equal(r.active, True)
    print("  PASS: test_toml_roundtrip_scalars (4 assertions)")


def test_toml_roundtrip_optional() raises:
    var w = WithOptional(
        label="test",
        count=Optional[Int](42),
        tag=Optional[String]("hello"),
        ratio=Optional[Float64](3.14),
        flag=Optional[Bool](False),
    )
    var toml = to_toml(w)
    var r = from_toml[WithOptional](toml)
    assert_equal(r.label, "test")
    assert_equal(r.count.value(), 42)
    assert_equal(r.tag.value(), "hello")
    assert_equal(r.flag.value(), False)
    print("  PASS: test_toml_roundtrip_optional (4 assertions)")


def test_toml_roundtrip_list() raises:
    var w = _make_with_list()
    var toml = to_toml(w)
    var r = from_toml[WithList](toml)
    assert_equal(r.title, "data")
    assert_equal(len(r.ids), 3)
    assert_equal(r.ids[0], 1)
    assert_equal(r.ids[2], 3)
    assert_equal(len(r.tags), 2)
    assert_equal(r.tags[0], "a")
    assert_equal(len(r.flags), 2)
    assert_equal(r.flags[1], False)
    print("  PASS: test_toml_roundtrip_list (8 assertions)")


def test_toml_roundtrip_nested() raises:
    var p = Person(name="Carol", age=40, address=Address(city="LA", zip_code=90001))
    var toml = to_toml(p)
    var r = from_toml[Person](toml)
    assert_equal(r.name, "Carol")
    assert_equal(r.age, 40)
    assert_equal(r.address.city, "LA")
    assert_equal(r.address.zip_code, 90001)
    print("  PASS: test_toml_roundtrip_nested (4 assertions)")


def test_toml_from_handwritten() raises:
    var toml = 'host = "0.0.0.0"\nport = 3000\ndebug = true\nworkers = 8\n'
    var cfg = from_toml[ServerConfig](toml)
    assert_equal(cfg.host, "0.0.0.0")
    assert_equal(cfg.port, 3000)
    assert_equal(cfg.debug, True)
    assert_equal(cfg.workers, 8)
    print("  PASS: test_toml_from_handwritten (4 assertions)")


def test_toml_string_escapes() raises:
    var s = Scalars(name='say "hello"', age=1, score=0.0, active=False)
    var toml = to_toml(s)
    var r = from_toml[Scalars](toml)
    assert_equal(r.name, 'say "hello"')
    print("  PASS: test_toml_string_escapes (1 assertion)")


# ---------------------------------------------------------------------------
# YAML Writer Tests
# ---------------------------------------------------------------------------


def test_yaml_write_scalars() raises:
    var s = Scalars(name="Alice", age=30, score=95.5, active=True)
    var yaml = to_yaml(s)
    assert_true("name: Alice" in yaml, "yaml has name")
    assert_true("age: 30" in yaml, "yaml has age")
    assert_true("active: true" in yaml, "yaml has active")
    print("  PASS: test_yaml_write_scalars (3 assertions)")


def test_yaml_write_optional_some() raises:
    var w = WithOptional(
        label="test",
        count=Optional[Int](42),
        tag=Optional[String]("hi"),
        ratio=Optional[Float64](3.14),
        flag=Optional[Bool](True),
    )
    var yaml = to_yaml(w)
    assert_true("label: test" in yaml, "yaml has label")
    assert_true("count: 42" in yaml, "yaml has count")
    assert_true("flag: true" in yaml, "yaml has flag")
    print("  PASS: test_yaml_write_optional_some (3 assertions)")


def test_yaml_write_optional_none() raises:
    var w = WithOptional()
    w.label = "empty"
    var yaml = to_yaml(w)
    assert_true("count: null" in yaml, "yaml has null count")
    assert_true("tag: null" in yaml, "yaml has null tag")
    print("  PASS: test_yaml_write_optional_none (2 assertions)")


def test_yaml_write_list() raises:
    var w = _make_with_list()
    var yaml = to_yaml(w)
    assert_true("title: data" in yaml, "yaml has title")
    assert_true("- 1" in yaml, "yaml has - 1")
    assert_true("- 3" in yaml, "yaml has - 3")
    assert_true("- true" in yaml, "yaml has - true")
    print("  PASS: test_yaml_write_list (4 assertions)")


def test_yaml_write_nested() raises:
    var p = Person(name="Bob", age=25, address=Address(city="NYC", zip_code=10001))
    var yaml = to_yaml(p)
    assert_true("name: Bob" in yaml, "yaml has name")
    assert_true("address:" in yaml, "yaml has address:")
    assert_true("city: NYC" in yaml, "yaml has city")
    assert_true("zip_code: 10001" in yaml, "yaml has zip")
    print("  PASS: test_yaml_write_nested (4 assertions)")


# ---------------------------------------------------------------------------
# YAML Roundtrip Tests
# ---------------------------------------------------------------------------


def test_yaml_roundtrip_scalars() raises:
    var s = Scalars(name="Alice", age=30, score=95.5, active=True)
    var yaml = to_yaml(s)
    var r = from_yaml[Scalars](yaml)
    assert_equal(r.name, "Alice")
    assert_equal(r.age, 30)
    assert_equal(r.score, 95.5)
    assert_equal(r.active, True)
    print("  PASS: test_yaml_roundtrip_scalars (4 assertions)")


def test_yaml_roundtrip_optional() raises:
    var w = WithOptional(
        label="test",
        count=Optional[Int](42),
        tag=Optional[String]("hello"),
        ratio=Optional[Float64](3.14),
        flag=Optional[Bool](False),
    )
    var yaml = to_yaml(w)
    var r = from_yaml[WithOptional](yaml)
    assert_equal(r.label, "test")
    assert_equal(r.count.value(), 42)
    assert_equal(r.tag.value(), "hello")
    assert_equal(r.flag.value(), False)
    print("  PASS: test_yaml_roundtrip_optional (4 assertions)")


def test_yaml_roundtrip_list() raises:
    var w = _make_with_list()
    var yaml = to_yaml(w)
    var r = from_yaml[WithList](yaml)
    assert_equal(r.title, "data")
    assert_equal(len(r.ids), 3)
    assert_equal(r.ids[0], 1)
    assert_equal(r.ids[2], 3)
    assert_equal(len(r.tags), 2)
    assert_equal(r.tags[0], "a")
    assert_equal(len(r.flags), 2)
    assert_equal(r.flags[1], False)
    print("  PASS: test_yaml_roundtrip_list (8 assertions)")


def test_yaml_roundtrip_nested() raises:
    var p = Person(name="Carol", age=40, address=Address(city="LA", zip_code=90001))
    var yaml = to_yaml(p)
    var r = from_yaml[Person](yaml)
    assert_equal(r.name, "Carol")
    assert_equal(r.age, 40)
    assert_equal(r.address.city, "LA")
    assert_equal(r.address.zip_code, 90001)
    print("  PASS: test_yaml_roundtrip_nested (4 assertions)")


def test_yaml_from_handwritten() raises:
    var yaml = "host: 0.0.0.0\nport: 3000\ndebug: true\nworkers: 8\n"
    var cfg = from_yaml[ServerConfig](yaml)
    assert_equal(cfg.host, "0.0.0.0")
    assert_equal(cfg.port, 3000)
    assert_equal(cfg.debug, True)
    assert_equal(cfg.workers, 8)
    print("  PASS: test_yaml_from_handwritten (4 assertions)")


def test_yaml_string_quoting() raises:
    var s = Scalars(name="value: with colon", age=1, score=0.0, active=False)
    var yaml = to_yaml(s)
    assert_true('"value: with colon"' in yaml, "colon string quoted")
    var r = from_yaml[Scalars](yaml)
    assert_equal(r.name, "value: with colon")
    print("  PASS: test_yaml_string_quoting (2 assertions)")


def test_yaml_null_handling() raises:
    var w = WithOptional()
    w.label = "test"
    var yaml = to_yaml(w)
    assert_true("count: null" in yaml, "null count")
    assert_true("tag: null" in yaml, "null tag")
    print("  PASS: test_yaml_null_handling (2 assertions)")


def test_yaml_bool_variants() raises:
    var yaml_yes = "name: test\nage: 0\nscore: 0.0\nactive: yes\n"
    var r1 = from_yaml[Scalars](yaml_yes)
    assert_equal(r1.active, True)

    var yaml_no = "name: test\nage: 0\nscore: 0.0\nactive: no\n"
    var r2 = from_yaml[Scalars](yaml_no)
    assert_equal(r2.active, False)
    print("  PASS: test_yaml_bool_variants (2 assertions)")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() raises:
    print("=== TOML Tests ===")
    test_toml_write_scalars()
    test_toml_write_optional_some()
    test_toml_write_optional_none()
    test_toml_write_list()
    test_toml_write_nested()
    test_toml_roundtrip_scalars()
    test_toml_roundtrip_optional()
    test_toml_roundtrip_list()
    test_toml_roundtrip_nested()
    test_toml_from_handwritten()
    test_toml_string_escapes()

    print("\n=== YAML Tests ===")
    test_yaml_write_scalars()
    test_yaml_write_optional_some()
    test_yaml_write_optional_none()
    test_yaml_write_list()
    test_yaml_write_nested()
    test_yaml_roundtrip_scalars()
    test_yaml_roundtrip_optional()
    test_yaml_roundtrip_list()
    test_yaml_roundtrip_nested()
    test_yaml_from_handwritten()
    test_yaml_string_quoting()
    test_yaml_null_handling()
    test_yaml_bool_variants()

    print("\nAll 24 TOML/YAML tests passed!")
