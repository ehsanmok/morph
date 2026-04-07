"""TOML serialization/deserialization for Mojo structs.

Supports scalars, Optional, List, and nested structs.

Usage::

    from morph.toml import to_toml, from_toml

    var toml = to_toml(config)
    var cfg = from_toml[Config](toml_str)
"""

from .writer import to_toml
from .reader import from_toml
