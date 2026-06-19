"""CLI argument parsing from struct definitions via reflection.

Generates ``--flag`` style arguments from struct fields and parses
command-line argument lists into struct instances.

Usage::

    from morph.cli import parse_args

    @fieldwise_init
    struct Options(Defaultable, Movable):
        var host: String
        var port: Int
        var verbose: Bool
        def __init__(out self):
            self.host = "localhost"
            self.port = 8080
            self.verbose = False

    var args = List[String]()
    args.append("--host")
    args.append("0.0.0.0")
    var opts = parse_args[Options](args)
"""

from std.collections import List, Dict
from std.builtin.rebind import trait_downcast
from morph.json.value import Value
from morph.reflect import (
    _Base,
    Morphable,
    INT_NAME,
    INT64_NAME,
    BOOL_NAME,
    STRING_NAME,
    FLOAT64_NAME,
    FLOAT32_NAME,
    OPT_INT_NAME,
    OPT_STRING_NAME,
    OPT_FLOAT64_NAME,
    OPT_BOOL_NAME,
    LIST_INT_NAME,
    LIST_STRING_NAME,
    LIST_FLOAT64_NAME,
    LIST_BOOL_NAME,
)


def parse_args[T: Morphable](args: List[String]) raises -> T:
    """Parse CLI arguments into a struct T.

    Arguments are ``--field_name value`` pairs. Bool fields are flags
    (``--verbose`` toggles to True, no value needed). Underscores in
    field names are converted to hyphens for CLI args (``my_field``
    becomes ``--my-field``).

    Parameters:
        T: The struct type to populate.

    Args:
        args: The argument list (without program name).

    Returns:
        A populated struct instance.
    """
    var result = T()

    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()

    var i = 0
    while i < len(args):
        var arg = args[i]
        var is_long = arg.startswith("--")
        var is_short = not is_long and arg.startswith("-") and len(arg) == 2

        if not is_long and not is_short:
            raise Error("Expected --flag or -x, got: " + arg)

        var flag: String
        if is_long:
            flag = String(arg.removeprefix("--"))
        else:
            flag = String(arg.removeprefix("-"))

        var matched = False

        comptime
        for idx in range(count):
            comptime field_name = names[idx]
            comptime field_type = types[idx]
            comptime type_name = reflect[field_type].name()

            var cli_name = String(field_name).replace("_", "-")
            var fn_str = String(field_name)
            var short_name = chr(Int(fn_str.as_bytes()[0]))
            if flag == cli_name or (is_short and flag == short_name):
                matched = True
                ref field = trait_downcast[_Base](reflect[T].field_ref[idx](result))
                var ptr = UnsafePointer(to=field)

                comptime
                if type_name == BOOL_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Bool]().init_pointee_move(True)
                elif type_name == OPT_BOOL_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Optional[Bool]]().init_pointee_move(True)
                elif type_name == INT_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var val = atol(args[i])
                    ptr.destroy_pointee()
                    ptr.bitcast[Int]().init_pointee_move(val)
                elif type_name == OPT_INT_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var val = atol(args[i])
                    ptr.destroy_pointee()
                    ptr.bitcast[Optional[Int]]().init_pointee_move(val)
                elif type_name == INT64_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var val = atol(args[i])
                    ptr.destroy_pointee()
                    ptr.bitcast[Int64]().init_pointee_move(Int64(val))
                elif type_name == FLOAT64_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var val = atof(args[i])
                    ptr.destroy_pointee()
                    ptr.bitcast[Float64]().init_pointee_move(val)
                elif type_name == OPT_FLOAT64_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var val = atof(args[i])
                    ptr.destroy_pointee()
                    ptr.bitcast[Optional[Float64]]().init_pointee_move(val)
                elif type_name == STRING_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var val = args[i]
                    ptr.destroy_pointee()
                    ptr.bitcast[String]().init_pointee_move(val)
                elif type_name == OPT_STRING_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var val = args[i]
                    ptr.destroy_pointee()
                    ptr.bitcast[Optional[String]]().init_pointee_move(val)
                elif type_name == LIST_STRING_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var parts = _split_comma(args[i])
                    ptr.destroy_pointee()
                    ptr.bitcast[List[String]]().init_pointee_move(parts^)
                elif type_name == LIST_INT_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var parts = _split_comma(args[i])
                    var int_list = List[Int]()
                    for pi in range(len(parts)):
                        int_list.append(atol(parts[pi]))
                    ptr.destroy_pointee()
                    ptr.bitcast[List[Int]]().init_pointee_move(int_list^)

        if not matched:
            raise Error("Unknown flag: --" + flag)

        i += 1

    return result^


def usage[T: AnyType]() -> String:
    """Generate a usage string showing available flags for struct T.

    Parameters:
        T: The struct type.

    Returns:
        A usage/help string.
    """
    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()

    var out = String("Options:\n")

    comptime
    for idx in range(count):
        comptime field_name = names[idx]
        comptime field_type = types[idx]
        comptime type_name = reflect[field_type].name()

        var cli_name = String(field_name).replace("_", "-")

        comptime
        if type_name == BOOL_NAME or type_name == OPT_BOOL_NAME:
            out += "  --" + cli_name + "  (flag)\n"
        elif type_name == INT_NAME or type_name == INT64_NAME or type_name == OPT_INT_NAME:
            out += "  --" + cli_name + " <int>\n"
        elif type_name == FLOAT64_NAME or type_name == OPT_FLOAT64_NAME:
            out += "  --" + cli_name + " <float>\n"
        elif type_name == STRING_NAME or type_name == OPT_STRING_NAME:
            out += "  --" + cli_name + " <string>\n"
        elif type_name == LIST_STRING_NAME:
            out += "  --" + cli_name + " <a,b,c>\n"
        elif type_name == LIST_INT_NAME:
            out += "  --" + cli_name + " <1,2,3>\n"
        else:
            out += "  --" + cli_name + " <value>\n"

    return out^


def parse_args_positional[T: Morphable](args: List[String]) raises -> T:
    """Parse CLI arguments with positional arg support.

    Arguments that don't start with ``--`` or ``-`` are treated as positional
    arguments and assigned to String fields in declaration order. Flags work
    the same as ``parse_args``.

    Parameters:
        T: The struct type to populate.

    Args:
        args: The argument list.

    Returns:
        A populated struct with positional and flag-based fields set.
    """
    var result = T()

    comptime count = reflect[T].field_count()
    comptime names = reflect[T].field_names()
    comptime types = reflect[T].field_types()

    var positional_idx = 0
    var i = 0
    while i < len(args):
        var arg = args[i]
        var is_long = arg.startswith("--")
        var is_short = not is_long and arg.startswith("-") and len(arg) == 2

        if not is_long and not is_short:
            var pos_matched = False
            var pos_count = 0
            comptime
            for idx in range(count):
                comptime field_name = names[idx]
                comptime field_type = types[idx]
                comptime type_name = reflect[field_type].name()

                comptime
                if type_name == STRING_NAME:
                    if pos_count == positional_idx:
                        pos_matched = True
                        ref field = trait_downcast[_Base](
                            reflect[T].field_ref[idx](result)
                        )
                        var ptr = UnsafePointer(to=field)
                        ptr.destroy_pointee()
                        ptr.bitcast[String]().init_pointee_move(arg)
                    pos_count += 1

            if not pos_matched:
                raise Error("Too many positional arguments")
            positional_idx += 1
            i += 1
            continue

        var flag: String
        if is_long:
            flag = String(arg.removeprefix("--"))
        else:
            flag = String(arg.removeprefix("-"))

        var matched = False

        comptime
        for idx in range(count):
            comptime field_name = names[idx]
            comptime field_type = types[idx]
            comptime type_name = reflect[field_type].name()

            var cli_name = String(field_name).replace("_", "-")
            var fn_str = String(field_name)
            var short_name = chr(Int(fn_str.as_bytes()[0]))
            if flag == cli_name or (is_short and flag == short_name):
                matched = True
                ref field = trait_downcast[_Base](
                    reflect[T].field_ref[idx](result)
                )
                var ptr = UnsafePointer(to=field)

                comptime
                if type_name == BOOL_NAME:
                    ptr.destroy_pointee()
                    ptr.bitcast[Bool]().init_pointee_move(True)
                elif type_name == INT_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    ptr.destroy_pointee()
                    ptr.bitcast[Int]().init_pointee_move(atol(args[i]))
                elif type_name == STRING_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    ptr.destroy_pointee()
                    ptr.bitcast[String]().init_pointee_move(args[i])
                elif type_name == FLOAT64_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    ptr.destroy_pointee()
                    ptr.bitcast[Float64]().init_pointee_move(atof(args[i]))
                elif type_name == LIST_STRING_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var parts = _split_comma(args[i])
                    ptr.destroy_pointee()
                    ptr.bitcast[List[String]]().init_pointee_move(parts^)
                elif type_name == LIST_INT_NAME:
                    i += 1
                    if i >= len(args):
                        raise Error("Missing value for --" + cli_name)
                    var parts = _split_comma(args[i])
                    var int_list = List[Int]()
                    for pi in range(len(parts)):
                        int_list.append(atol(parts[pi]))
                    ptr.destroy_pointee()
                    ptr.bitcast[List[Int]]().init_pointee_move(int_list^)

        if not matched:
            raise Error("Unknown flag: --" + flag)

        i += 1

    return result^


def parse_args_nested[T: Morphable](args: List[String]) raises -> T:
    """Parse CLI arguments with dot-notation for nested structs.

    Supports ``--parent.child value`` syntax where ``parent`` is a nested
    struct field and ``child`` is a field within that struct.
    Top-level flags work the same as ``parse_args``. Uses JSON roundtrip
    internally to handle nested struct field assignment.

    Parameters:
        T: The struct type to populate.

    Args:
        args: The argument list.

    Returns:
        A populated struct with nested fields set.
    """
    from morph.json.writer import write as _write
    from morph.json.reader import read as _read
    from morph.json.value import loads as _loads, dumps as _dumps

    var result = T()
    var json_str = _write(result)
    var json_val = _loads(json_str)

    var patches = Dict[String, String]()
    var nested_patches = Dict[String, Dict[String, String]]()

    var i = 0
    while i < len(args):
        var arg = args[i]
        if not arg.startswith("--"):
            raise Error("Expected --flag, got: " + arg)
        var flag = String(arg.removeprefix("--"))

        var dot_pos = _find_char(flag, ".")
        if dot_pos >= 0:
            var parent = _substr(flag, 0, dot_pos).replace("-", "_")
            var child = _substr(flag, dot_pos + 1, len(flag)).replace("-", "_")
            i += 1
            if i >= len(args):
                raise Error("Missing value for --" + flag)
            if parent not in nested_patches:
                nested_patches[parent] = Dict[String, String]()
            nested_patches[parent][child] = args[i]
        else:
            var field_key = flag.replace("-", "_")
            var is_bool = _is_bool_field(json_val, field_key)
            if is_bool:
                patches[field_key] = "true"
            else:
                i += 1
                if i >= len(args):
                    raise Error("Missing value for --" + flag)
                patches[field_key] = args[i]
        i += 1

    var out = String("{")
    var keys = json_val.object_keys()
    var first = True
    for ki in range(len(keys)):
        var k = keys[ki]
        if not first:
            out += ","
        first = False
        out += '"' + k + '":'

        if k in nested_patches:
            var inner_raw = json_val.get(k)
            var inner_json = _loads(inner_raw)
            if inner_json.is_object():
                var inner_out = String("{")
                var inner_keys = inner_json.object_keys()
                var ifirst = True
                for ik in range(len(inner_keys)):
                    var ik_name = inner_keys[ik]
                    if not ifirst:
                        inner_out += ","
                    ifirst = False
                    inner_out += '"' + ik_name + '":'
                    if ik_name in nested_patches[k]:
                        var pv = nested_patches[k][ik_name]
                        inner_out += _maybe_quote(inner_json, ik_name, pv)
                    else:
                        inner_out += inner_json.get(ik_name)
                inner_out += "}"
                out += inner_out^
            else:
                out += inner_raw
        elif k in patches:
            out += _maybe_quote(json_val, k, patches[k])
        else:
            out += json_val.get(k)

    out += "}"
    return _read[T, default_if_missing=True](out)


def _is_bool_field(json: Value, key: String) -> Bool:
    """Check if a field in the JSON object is a boolean."""
    try:
        var raw = json.get(key)
        return raw == "true" or raw == "false"
    except:
        return False


def _maybe_quote(json: Value, key: String, val: String) -> String:
    """Quote the value as a JSON string if the original field is a string type."""
    from morph.json.value import escape_string as _escape_string

    try:
        var raw = json.get(key)
        if len(raw) > 0 and raw.as_bytes()[0] == UInt8(ord('"')):
            return _escape_string(val)
    except:
        pass
    return val


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _split_comma(s: String) -> List[String]:
    """Split a string by commas, returning a list of trimmed parts."""
    var result = List[String]()
    var current = String("")
    var data = s.as_bytes()
    for i in range(len(data)):
        if data[i] == UInt8(ord(",")):
            result.append(current^)
            current = String("")
        else:
            current += chr(Int(data[i]))
    if len(current) > 0:
        result.append(current^)
    return result^


def _find_char(s: String, c: String) -> Int:
    """Find the first occurrence of a character in a string. Returns -1 if not found."""
    var data = s.as_bytes()
    var target = UInt8(ord(c))
    for i in range(len(data)):
        if data[i] == target:
            return i
    return -1


def _substr(s: String, start: Int, end: Int) -> String:
    """Extract a substring from start to end (exclusive)."""
    var out = String("")
    var data = s.as_bytes()
    for i in range(start, end):
        out += chr(Int(data[i]))
    return out^
