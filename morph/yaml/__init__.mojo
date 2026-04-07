"""YAML serialization/deserialization for Mojo structs.

Supports scalars, Optional, List, and nested structs using indentation-based
YAML subset (no anchors, aliases, tags, or multi-document streams).

Usage::

    from morph.yaml import to_yaml, from_yaml

    var yaml = to_yaml(config)
    var cfg = from_yaml[Config](yaml_str)
"""

from .writer import to_yaml
from .reader import from_yaml
