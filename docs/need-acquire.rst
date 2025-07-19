need-acquire
============

.. dfhack-tool::
    :summary: Give trinkets to citizens to satisfy the Acquire Object need.
    :tags: fort gameplay happiness

Assigns free jewelry items to dwarves who have a strong ``Acquire Object`` need.
The script searches for unowned earrings, rings, amulets, and bracelets and
assigns them to dwarves whose focus level for the need falls below a configurable
threshold.

Usage
-----

``need-acquire [-t <focus_threshold>]``
    Give trinkets to all dwarves whose focus level is below ``-<focus_threshold>``.
    The default threshold is ``-3000``.

Examples
--------

``need-acquire``
    Use the default focus threshold of ``-3000``.
``need-acquire -t 2000``
    Fulfill the need for dwarves whose focus drops below ``-2000``.

Options
-------

``-t`` ``<threshold>``
    Focus level below which the need is considered unmet.
``-help``
    Show the help text.
