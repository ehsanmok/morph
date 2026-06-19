"""Field renaming strategies for serialization/deserialization.

Provides functions to convert between naming conventions:
- snake_case (Mojo/Python style)
- camelCase (JavaScript/JSON style)
- PascalCase (C#/Go style)
- SCREAMING_SNAKE_CASE (constants)

Example:

    from morph.rename import snake_to_camel, camel_to_snake

    print(snake_to_camel("first_name"))     # "firstName"
    print(camel_to_snake("firstName"))       # "first_name"
    print(snake_to_pascal("first_name"))     # "FirstName"
"""


def snake_to_camel(name: String) -> String:
    """Convert snake_case to camelCase.

    Args:
        name: A snake_case string.

    Returns:
        The camelCase equivalent.
    """
    var result = String("")
    var capitalize_next = False
    var bytes = name.as_bytes()
    for i in range(len(bytes)):
        var b = bytes[i]
        if b == UInt8(ord("_")):
            capitalize_next = True
        elif capitalize_next:
            result += _upper_byte(b)
            capitalize_next = False
        else:
            result += chr(Int(b))
    return result^


def camel_to_snake(name: String) -> String:
    """Convert camelCase or PascalCase to snake_case.

    Args:
        name: A camelCase or PascalCase string.

    Returns:
        The snake_case equivalent.
    """
    var result = String("")
    var bytes = name.as_bytes()
    for i in range(len(bytes)):
        var b = bytes[i]
        if _is_upper_byte(b):
            if result.byte_length() > 0:
                result += "_"
            result += _lower_byte(b)
        else:
            result += chr(Int(b))
    return result^


def snake_to_pascal(name: String) -> String:
    """Convert snake_case to PascalCase.

    Args:
        name: A snake_case string.

    Returns:
        The PascalCase equivalent.
    """
    var result = String("")
    var capitalize_next = True
    var bytes = name.as_bytes()
    for i in range(len(bytes)):
        var b = bytes[i]
        if b == UInt8(ord("_")):
            capitalize_next = True
        elif capitalize_next:
            result += _upper_byte(b)
            capitalize_next = False
        else:
            result += chr(Int(b))
    return result^


def snake_to_screaming(name: String) -> String:
    """Convert snake_case to SCREAMING_SNAKE_CASE.

    Args:
        name: A snake_case string.

    Returns:
        The SCREAMING_SNAKE_CASE equivalent.
    """
    var result = String("")
    var bytes = name.as_bytes()
    for i in range(len(bytes)):
        result += _upper_byte(bytes[i])
    return result^


def apply_rename(name: String, strategy: String) raises -> String:
    """Apply a named renaming strategy to a field name.

    Args:
        name: The original field name (typically snake_case).
        strategy: One of "camelCase", "PascalCase", "SCREAMING_SNAKE_CASE",
                  "snake_case" (identity), or "none" (identity).

    Returns:
        The renamed field name.

    Raises:
        Error for unknown strategy names.
    """
    if strategy == "camelCase":
        return snake_to_camel(name)
    elif strategy == "PascalCase":
        return snake_to_pascal(name)
    elif strategy == "SCREAMING_SNAKE_CASE":
        return snake_to_screaming(name)
    elif strategy == "snake_case" or strategy == "none":
        return name
    else:
        raise Error("Unknown rename strategy: " + strategy)


# ---------------------------------------------------------------------------
# Internal byte-level helpers
# ---------------------------------------------------------------------------

comptime _A = ord("A")
comptime _Z = ord("Z")
comptime _a = ord("a")
comptime _z = ord("z")


@always_inline
def _is_upper_byte(b: UInt8) -> Bool:
    return Int(b) >= _A and Int(b) <= _Z


@always_inline
def _lower_byte(b: UInt8) -> String:
    if _is_upper_byte(b):
        return chr(Int(b) + 32)
    return chr(Int(b))


@always_inline
def _upper_byte(b: UInt8) -> String:
    if Int(b) >= _a and Int(b) <= _z:
        return chr(Int(b) - 32)
    return chr(Int(b))
