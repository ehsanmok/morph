"""Struct transformation utilities via compile-time reflection.

Provides introspection and transformation operations on structs:

- ``fields[T]()`` -- list field names and type names
- ``field_names[T]()`` -- list field names only
- ``as_type[Target, Source]()`` -- copy matching fields between structs
"""

from std.reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
    get_type_name,
)
from std.builtin.rebind import trait_downcast, rebind
from morph.reflect import _Base, Morphable

comptime _Copy = Copyable & ImplicitlyDestructible


# ---------------------------------------------------------------------------
# Field info
# ---------------------------------------------------------------------------


@fieldwise_init
struct FieldInfo(Copyable, Movable, Writable):
    """Metadata about a single struct field."""

    var name: String
    var type_name: String

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.name, ": ", self.type_name)


def fields[T: AnyType]() -> List[FieldInfo]:
    """Return a list of FieldInfo for every field in T.

    Parameters:
        T: A struct type.

    Returns:
        List of (name, type_name) pairs.
    """
    comptime count = struct_field_count[T]()
    comptime names = struct_field_names[T]()
    comptime types = struct_field_types[T]()

    var result = List[FieldInfo]()

    comptime
    for idx in range(count):
        comptime fname = names[idx]
        comptime ftype = types[idx]
        comptime tname = get_type_name[ftype]()
        result.append(FieldInfo(name=String(fname), type_name=String(tname)))

    return result^


def field_names[T: AnyType]() -> List[String]:
    """Return field names of T as a List[String].

    Parameters:
        T: A struct type.
    """
    comptime count = struct_field_count[T]()
    comptime names = struct_field_names[T]()

    var result = List[String]()

    comptime
    for idx in range(count):
        comptime fname = names[idx]
        result.append(String(fname))

    return result^


# ---------------------------------------------------------------------------
# Struct composition
# ---------------------------------------------------------------------------


def as_type[Target: Morphable, Source: AnyType](source: Source) raises -> Target:
    """Create a Target struct by copying fields with matching names from Source.

    Serializes source to JSON and deserializes into Target with
    ``default_if_missing=True``, so fields in Target not present in Source
    keep their default values, and extra Source fields are ignored.

    Parameters:
        Target: The destination struct type (Defaultable & Movable).
        Source: The source struct type.

    Args:
        source: The source struct instance.

    Returns:
        A new Target with matching fields copied from source.
    """
    from morph.json.writer import write as _write
    from morph.json.reader import read as _read

    var json = _write(source)
    return _read[Target, default_if_missing=True](json)
