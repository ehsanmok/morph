"""Struct transformation utilities via compile-time reflection.

Provides introspection and transformation operations on structs:

- ``fields[T]()``: list field names and type names
- ``field_names[T]()``: list field names only
- ``as_type[Target, Source]()``: copy matching fields between structs
- ``replace[T]()``: copy struct with one field changed (by name)
"""

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
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()

    var result = List[FieldInfo]()

    comptime
    for idx in range(count):
        comptime fname = names[idx]
        comptime ftype = types[idx]
        comptime tname = reflect[ftype].name()
        result.append(FieldInfo(name=String(fname), type_name=String(tname)))

    return result^


def field_names[T: AnyType]() -> List[String]:
    """Return field names of T as a List[String].

    Parameters:
        T: A struct type.
    """
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()

    var result = List[String]()

    comptime
    for idx in range(count):
        comptime fname = names[idx]
        result.append(String(fname))

    return result^


# ---------------------------------------------------------------------------
# Struct composition
# ---------------------------------------------------------------------------


def replace[
    T: Morphable, field_name: StaticString
](source: T, new_value: String) raises -> T:
    """Create a copy of source with the named String field replaced.

    Parameters:
        T: The struct type.
        field_name: The field to replace (compile-time string).

    Args:
        source: The original struct.
        new_value: The new String value for the field.

    Returns:
        A new struct with the field replaced.
    """
    from morph.json.writer import write as _write
    from morph.json.reader import read as _read

    var json_str = _write(source)
    var result = _read[T, default_if_missing=True](json_str)

    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()

    comptime
    for idx in range(count):
        comptime fname = names[idx]
        comptime
        if fname == field_name:
            ref field = trait_downcast[_Base](reflect[T].field_ref[idx](result))
            var ptr = UnsafePointer(to=field)
            ptr.destroy_pointee()
            ptr.bitcast[String]().init_pointee_move(new_value)

    return result^


def replace_int[
    T: Morphable, field_name: StaticString
](source: T, new_value: Int) raises -> T:
    """Create a copy of source with the named Int field replaced.

    Parameters:
        T: The struct type.
        field_name: The field to replace (compile-time string).

    Args:
        source: The original struct.
        new_value: The new Int value for the field.

    Returns:
        A new struct with the field replaced.
    """
    from morph.json.writer import write as _write
    from morph.json.reader import read as _read

    var json_str = _write(source)
    var result = _read[T, default_if_missing=True](json_str)

    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()

    comptime
    for idx in range(count):
        comptime fname = names[idx]
        comptime
        if fname == field_name:
            ref field = trait_downcast[_Base](reflect[T].field_ref[idx](result))
            var ptr = UnsafePointer(to=field)
            ptr.destroy_pointee()
            ptr.bitcast[Int]().init_pointee_move(new_value)

    return result^


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
