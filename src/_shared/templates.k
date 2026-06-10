# Shared template helpers
# Use these instead of raw {TEMPLATE_MARKER = "field"} dicts for clarity.

hb = lambda field: str -> {str: str} {
    {TEMPLATE_MARKER = field}
}
