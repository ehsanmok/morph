"""Runtime validation utilities for struct fields.

Provides standalone validators and a ``validate_struct`` function that
collects all field errors before raising.

Usage::

    from morph.validate import validate, min_val, max_val, non_empty

    @fieldwise_init
    struct Config(Defaultable, Movable):
        var port: Int
        var host: String
        def __init__(out self):
            self.port = 0
            self.host = ""

    var c = Config(port=99999, host="")
    var errors = validate(c, Dict[String, Validator]())
"""

from std.collections import List


# ---------------------------------------------------------------------------
# ValidationError
# ---------------------------------------------------------------------------


@fieldwise_init
struct ValidationError(Copyable, Movable, Writable):
    """One validation failure for a named field."""

    var field: String
    var message: String

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.field, ": ", self.message)


# ---------------------------------------------------------------------------
# Standalone validator functions (operate on values directly)
# ---------------------------------------------------------------------------


def check_min(
    value: Int, minimum: Int, field_name: String
) -> Optional[ValidationError]:
    """Check value >= minimum."""
    if value < minimum:
        return ValidationError(
            field=field_name,
            message="must be >= " + String(minimum) + ", got " + String(value),
        )
    return None


def check_max(
    value: Int, maximum: Int, field_name: String
) -> Optional[ValidationError]:
    """Check value <= maximum."""
    if value > maximum:
        return ValidationError(
            field=field_name,
            message="must be <= " + String(maximum) + ", got " + String(value),
        )
    return None


def check_range(
    value: Int, minimum: Int, maximum: Int, field_name: String
) -> Optional[ValidationError]:
    """Check minimum <= value <= maximum."""
    if value < minimum or value > maximum:
        return ValidationError(
            field=field_name,
            message="must be in ["
            + String(minimum)
            + ", "
            + String(maximum)
            + "], got "
            + String(value),
        )
    return None


def check_min_float(
    value: Float64, minimum: Float64, field_name: String
) -> Optional[ValidationError]:
    """Check float value >= minimum."""
    if value < minimum:
        return ValidationError(
            field=field_name,
            message="must be >= " + String(minimum) + ", got " + String(value),
        )
    return None


def check_max_float(
    value: Float64, maximum: Float64, field_name: String
) -> Optional[ValidationError]:
    """Check float value <= maximum."""
    if value > maximum:
        return ValidationError(
            field=field_name,
            message="must be <= " + String(maximum) + ", got " + String(value),
        )
    return None


def check_exclusive_min(
    value: Int, minimum: Int, field_name: String
) -> Optional[ValidationError]:
    """Check value > minimum (exclusive)."""
    if value <= minimum:
        return ValidationError(
            field=field_name,
            message="must be > " + String(minimum) + ", got " + String(value),
        )
    return None


def check_exclusive_max(
    value: Int, maximum: Int, field_name: String
) -> Optional[ValidationError]:
    """Check value < maximum (exclusive)."""
    if value >= maximum:
        return ValidationError(
            field=field_name,
            message="must be < " + String(maximum) + ", got " + String(value),
        )
    return None


def check_exclusive_min_float(
    value: Float64, minimum: Float64, field_name: String
) -> Optional[ValidationError]:
    """Check float value > minimum (exclusive)."""
    if value <= minimum:
        return ValidationError(
            field=field_name,
            message="must be > " + String(minimum) + ", got " + String(value),
        )
    return None


def check_exclusive_max_float(
    value: Float64, maximum: Float64, field_name: String
) -> Optional[ValidationError]:
    """Check float value < maximum (exclusive)."""
    if value >= maximum:
        return ValidationError(
            field=field_name,
            message="must be < " + String(maximum) + ", got " + String(value),
        )
    return None


def check_non_empty(
    value: String, field_name: String
) -> Optional[ValidationError]:
    """Check string is non-empty."""
    if value.byte_length() == 0:
        return ValidationError(
            field=field_name,
            message="must not be empty",
        )
    return None


def check_min_length(
    value: String, min_len: Int, field_name: String
) -> Optional[ValidationError]:
    """Check string length >= min_len."""
    if value.byte_length() < min_len:
        return ValidationError(
            field=field_name,
            message="length must be >= "
            + String(min_len)
            + ", got "
            + String(value.byte_length()),
        )
    return None


def check_max_length(
    value: String, max_len: Int, field_name: String
) -> Optional[ValidationError]:
    """Check string length <= max_len."""
    if value.byte_length() > max_len:
        return ValidationError(
            field=field_name,
            message="length must be <= "
            + String(max_len)
            + ", got "
            + String(value.byte_length()),
        )
    return None


def check_equal(
    value: Int, expected: Int, field_name: String
) -> Optional[ValidationError]:
    """Check value == expected."""
    if value != expected:
        return ValidationError(
            field=field_name,
            message="must equal " + String(expected) + ", got " + String(value),
        )
    return None


def check_not_equal(
    value: Int, forbidden: Int, field_name: String
) -> Optional[ValidationError]:
    """Check value != forbidden."""
    if value == forbidden:
        return ValidationError(
            field=field_name,
            message="must not equal " + String(forbidden),
        )
    return None


def check_one_of(
    value: String, allowed: List[String], field_name: String
) -> Optional[ValidationError]:
    """Check value is one of the allowed strings."""
    for i in range(len(allowed)):
        if value == allowed[i]:
            return None
    var msg = String("must be one of [")
    for i in range(len(allowed)):
        if i > 0:
            msg += ", "
        msg += "'" + allowed[i] + "'"
    msg += "], got '" + value + "'"
    return ValidationError(field=field_name, message=msg)


# ---------------------------------------------------------------------------
# Validation result helpers
# ---------------------------------------------------------------------------


def raise_if_errors(errors: List[ValidationError]) raises:
    """Raise an Error with all validation messages if errors exist."""
    if len(errors) == 0:
        return

    var msg = String("Validation failed (")
    msg += String(len(errors)) + " error"
    if len(errors) > 1:
        msg += "s"
    msg += "):\n"
    for i in range(len(errors)):
        msg += "  - " + errors[i].field + ": " + errors[i].message
        if i < len(errors) - 1:
            msg += "\n"
    raise Error(msg)
