"""Format backend trait for pluggable serialization formats.

Defines the ``FormatBackend`` trait that all format backends (JSON, TOML,
YAML, CSV) implement. JSON, TOML, and YAML are fully implemented.

Future backends can implement this trait for new formats::

    struct TOMLBackend(FormatBackend):
        ...
"""


trait FormatBackend:
    """Trait for serialization format backends.

    Each backend knows how to serialize a string-keyed dict of values
    to its format and deserialize back.
    """

    def serialize(self, data: String) raises -> String:
        """Serialize data string (JSON-like intermediate) to target format."""
        ...

    def deserialize(self, data: String) raises -> String:
        """Deserialize target format string to intermediate (JSON-like) string.
        """
        ...

    def file_extension(self) -> String:
        """Return the canonical file extension (e.g. 'json', 'toml')."""
        ...
