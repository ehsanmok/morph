"""Example 06: Struct introspection, serde options, and type conversion.

Demonstrates: fields(), field_names(), as_type(), rename in write/read,
skip_private, default_if_missing, strict, add_type, as_array.
"""

from morph.json import write, read
from morph.transform import fields, field_names, as_type


@fieldwise_init
struct User(Defaultable, Movable):
    var first_name: String
    var last_name: String
    var age: Int
    var _internal: String

    def __init__(out self):
        self.first_name = ""
        self.last_name = ""
        self.age = 0
        self._internal = ""


@fieldwise_init
struct Profile(Defaultable, Movable):
    var first_name: String
    var age: Int
    var bio: String

    def __init__(out self):
        self.first_name = ""
        self.age = 0
        self.bio = ""


def main() raises:
    print("=== Struct Introspection ===\n")

    var info = fields[User]()
    for i in range(len(info)):
        print("  " + info[i].name + ": " + info[i].type_name)

    var names = field_names[User]()
    print("Field names: ", end="")
    for i in range(len(names)):
        if i > 0:
            print(", ", end="")
        print(names[i], end="")
    print()

    print("\n=== Rename in Serde ===\n")

    var user = User(
        first_name="Alice", last_name="Smith", age=30, _internal="secret"
    )
    print("camelCase: " + write[rename="camelCase"](user))
    print("PascalCase: " + write[rename="PascalCase"](user))

    var json = '{"firstName":"Bob","lastName":"Jones","age":25,"Internal":"x"}'
    var u = read[User, rename="camelCase", default_if_missing=True](json)
    print("Read back: " + u.first_name + " " + u.last_name)

    print("\n=== Skip Private Fields ===\n")

    print("With _internal: " + write(user))
    print("Without:        " + write[skip_private=True](user))

    print("\n=== Default If Missing ===\n")

    var partial = '{"first_name":"Eve"}'
    var filled = read[User, default_if_missing=True](partial)
    print(
        "From partial JSON: "
        + filled.first_name
        + " age="
        + String(filled.age)
    )

    print("\n=== Strict Mode ===\n")

    var exact = '{"first_name":"A","last_name":"B","age":1,"_internal":"x"}'
    var s = read[User, strict=True](exact)
    print("Strict OK: " + s.first_name)

    try:
        var bad = '{"first_name":"A","last_name":"B","age":1,"_internal":"x","extra":true}'
        _ = read[User, strict=True](bad)
    except e:
        print("Strict rejected extra key: " + String(e))

    print("\n=== Add Type Discriminator ===\n")

    print("add_type: " + write[add_type=True](user))

    print("\n=== Array Output ===\n")

    print("as_array: " + write[as_array=True](user))

    print("\n=== as_type: Convert Between Structs ===\n")

    var profile = as_type[Profile](user)
    print(
        "User -> Profile: "
        + profile.first_name
        + " age="
        + String(profile.age)
        + " bio='"
        + profile.bio
        + "'"
    )
