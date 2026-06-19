"""Core reflection utilities for morph.

Compile-time type matching, field iteration helpers, and type name constants
These utilities form the foundation
for format-agnostic serialization and deserialization.

Supported scalar types:
    Int, Int64, Bool, Float64, Float32, String

Supported container types (hardcoded until GAP-3 is resolved):
    Optional[Int], Optional[String], Optional[Float64], Optional[Bool]
    List[Int], List[String], List[Float64], List[Bool]
"""

from std.builtin.rebind import trait_downcast, downcast
from std.collections import Optional, List


# ---------------------------------------------------------------------------
# Compile-time type name constants
# ---------------------------------------------------------------------------

comptime INT_NAME = reflect[Int].name()
comptime INT64_NAME = reflect[Int64].name()
comptime BOOL_NAME = reflect[Bool].name()
comptime STRING_NAME = reflect[String].name()
comptime FLOAT64_NAME = reflect[Float64].name()
comptime FLOAT32_NAME = reflect[Float32].name()

comptime OPT_INT_NAME = reflect[Optional[Int]].name()
comptime OPT_STRING_NAME = reflect[Optional[String]].name()
comptime OPT_FLOAT64_NAME = reflect[Optional[Float64]].name()
comptime OPT_BOOL_NAME = reflect[Optional[Bool]].name()

comptime LIST_INT_NAME = reflect[List[Int]].name()
comptime LIST_STRING_NAME = reflect[List[String]].name()
comptime LIST_FLOAT64_NAME = reflect[List[Float64]].name()
comptime LIST_BOOL_NAME = reflect[List[Bool]].name()

comptime _FLOAT64_SIMD_PREFIX = "SIMD[DType.float64"
comptime _FLOAT32_SIMD_PREFIX = "SIMD[DType.float32"


# ---------------------------------------------------------------------------
# Trait bound aliases
# ---------------------------------------------------------------------------

comptime _Base = ImplicitlyDestructible & Movable
comptime Morphable = Defaultable & Movable & ImplicitlyDestructible


# ---------------------------------------------------------------------------
# Compile-time type classification
# ---------------------------------------------------------------------------


@always_inline
def is_int_type[T: AnyType]() -> Bool:
    comptime tname = reflect[T].name()
    return tname == INT_NAME


@always_inline
def is_int64_type[T: AnyType]() -> Bool:
    comptime tname = reflect[T].name()
    return tname == INT64_NAME


@always_inline
def is_bool_type[T: AnyType]() -> Bool:
    comptime tname = reflect[T].name()
    return tname == BOOL_NAME


@always_inline
def is_string_type[T: AnyType]() -> Bool:
    comptime tname = reflect[T].name()
    return tname == STRING_NAME


@always_inline
def is_float64_type[T: AnyType]() -> Bool:
    comptime tname = reflect[T].name()
    return tname == FLOAT64_NAME or _FLOAT64_SIMD_PREFIX in tname


@always_inline
def is_float32_type[T: AnyType]() -> Bool:
    comptime tname = reflect[T].name()
    return tname == FLOAT32_NAME or _FLOAT32_SIMD_PREFIX in tname


@always_inline
def is_scalar_type[T: AnyType]() -> Bool:
    """True if T is a primitive scalar: Int, Int64, Bool, Float64, Float32, String.
    """
    comptime tname = reflect[T].name()
    return (
        tname == INT_NAME
        or tname == INT64_NAME
        or tname == BOOL_NAME
        or tname == STRING_NAME
        or tname == FLOAT64_NAME
        or tname == FLOAT32_NAME
        or _FLOAT64_SIMD_PREFIX in tname
        or _FLOAT32_SIMD_PREFIX in tname
    )


@always_inline
def is_optional_type[T: AnyType]() -> Bool:
    """True if T is one of the supported Optional[Scalar] types."""
    comptime base = reflect[T].base_name()
    return base == "Optional"


@always_inline
def is_list_type[T: AnyType]() -> Bool:
    """True if T is one of the supported List[Scalar] types."""
    comptime base = reflect[T].base_name()
    return base == "List"


@always_inline
def is_container_type[T: AnyType]() -> Bool:
    """True if T is a recognized container (Optional or List)."""
    return is_optional_type[T]() or is_list_type[T]()
