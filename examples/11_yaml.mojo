"""Example 11: YAML serialization/deserialization.

Demonstrates to_yaml() and from_yaml() for structs with scalars,
Optional fields, List fields, and nested structs.
"""

from morph.yaml import to_yaml, from_yaml


@fieldwise_init
struct Address(Defaultable, Movable):
    var street: String
    var city: String

    def __init__(out self):
        self.street = ""
        self.city = ""


@fieldwise_init
struct Person(Defaultable, Movable):
    var name: String
    var age: Int
    var active: Bool
    var score: Float64
    var nickname: Optional[String]
    var hobbies: List[String]
    var address: Address

    def __init__(out self):
        self.name = ""
        self.age = 0
        self.active = False
        self.score = 0.0
        self.nickname = None
        self.hobbies = List[String]()
        self.address = Address()


def main() raises:
    print("=== Example 11: YAML ===\n")

    var p = Person(
        name="Alice",
        age=30,
        active=True,
        score=9.5,
        nickname=String("Ali"),
        hobbies=List[String](),
        address=Address(street="123 Main St", city="Springfield"),
    )
    p.hobbies.append("reading")
    p.hobbies.append("hiking")

    var yaml = to_yaml(p)
    print("Serialized YAML:")
    print(yaml)

    var restored = from_yaml[Person](yaml)
    print("Round-trip values:")
    print("  name:", restored.name)
    print("  age:", restored.age)
    print("  active:", restored.active)
    print("  nickname:", restored.nickname.value())
    print("  hobbies count:", len(restored.hobbies))
    print("  address.city:", restored.address.city)

    print("\nParse handwritten YAML:")
    var hand = from_yaml[Person](
        "name: Bob\nage: 25\nactive: false\nscore: 7.2\nnickname: null\nhobbies:\n  - chess\n  - cooking\naddress:\n  street: 456 Oak Ave\n  city: Shelbyville\n"
    )
    print("  name:", hand.name)
    print("  active:", hand.active)
    print("  address.city:", hand.address.city)

    print("\n  PASS: example 11 YAML")
