"""Example 08: CLI argument parsing from struct definitions.

Demonstrates: parse_args[T]() to convert --flag arguments into a struct,
and usage[T]() to generate help text.
"""

from morph.cli import parse_args, usage
from std.collections import List


@fieldwise_init
struct ServerConfig(Defaultable, Movable):
    var host: String
    var port: Int
    var max_workers: Int
    var debug: Bool

    def __init__(out self):
        self.host = "127.0.0.1"
        self.port = 8080
        self.max_workers = 4
        self.debug = False


def main() raises:
    print("=== Usage String ===\n")
    print(usage[ServerConfig]())

    print("=== Parse CLI Arguments ===\n")

    var args = List[String]()
    args.append("--host")
    args.append("0.0.0.0")
    args.append("--port")
    args.append("9090")
    args.append("--max-workers")
    args.append("8")
    args.append("--debug")

    var config = parse_args[ServerConfig](args)
    print("host:        " + config.host)
    print("port:        " + String(config.port))
    print("max_workers: " + String(config.max_workers))
    print("debug:       " + String(config.debug))

    print("\n=== Defaults (no args) ===\n")

    var empty = List[String]()
    var defaults = parse_args[ServerConfig](empty)
    print("host:        " + defaults.host)
    print("port:        " + String(defaults.port))
    print("max_workers: " + String(defaults.max_workers))
    print("debug:       " + String(defaults.debug))

    print("\n=== Error Handling ===\n")

    var bad_args = List[String]()
    bad_args.append("--unknown-flag")
    try:
        _ = parse_args[ServerConfig](bad_args)
    except e:
        print("Unknown flag error: " + String(e))

    var missing_val = List[String]()
    missing_val.append("--port")
    try:
        _ = parse_args[ServerConfig](missing_val)
    except e:
        print("Missing value error: " + String(e))
