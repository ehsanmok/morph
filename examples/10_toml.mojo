"""Example 10: TOML serialization/deserialization.

Demonstrates to_toml() and from_toml() for structs with scalars,
Optional fields, List fields, and nested structs.
"""

from morph.toml import to_toml, from_toml


@fieldwise_init
struct Database(Defaultable, Movable):
    var host: String
    var port: Int
    var name: String

    def __init__(out self):
        self.host = ""
        self.port = 0
        self.name = ""


@fieldwise_init
struct AppConfig(Defaultable, Movable):
    var title: String
    var debug: Bool
    var version: Float64
    var owner: Optional[String]
    var tags: List[String]
    var database: Database

    def __init__(out self):
        self.title = ""
        self.debug = False
        self.version = 0.0
        self.owner = None
        self.tags = List[String]()
        self.database = Database()


def main() raises:
    print("=== Example 10: TOML ===\n")

    var cfg = AppConfig(
        title="MyApp",
        debug=True,
        version=1.5,
        owner=String("Alice"),
        tags=List[String](),
        database=Database(host="localhost", port=5432, name="mydb"),
    )
    cfg.tags.append("web")
    cfg.tags.append("api")

    var toml = to_toml(cfg)
    print("Serialized TOML:")
    print(toml)

    var restored = from_toml[AppConfig](toml)
    print("Round-trip values:")
    print("  title:", restored.title)
    print("  debug:", restored.debug)
    print("  database.host:", restored.database.host)
    print("  database.port:", restored.database.port)
    print("  tags count:", len(restored.tags))

    print("\nParse handwritten TOML:")
    var hand = from_toml[AppConfig](
        'title = "FromFile"\ndebug = false\nversion = 2.0\ntags = ["prod"]\n\n[database]\nhost = "db.example.com"\nport = 3306\nname = "prod_db"\n'
    )
    print("  title:", hand.title)
    print("  database.host:", hand.database.host)

    print("\n  PASS: example 10 TOML")
