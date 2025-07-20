stack-bodyparts
===============

.. dfhack-tool::
    :summary: Stack teeth and other body parts so they can be stored in containers.
    :tags: fort productivity items

This tool enables stacking for corpse pieces (teeth, horns, etc.) so they can be gathered in bins or bags. Existing parts in stockpiles are combined automatically.

Usage
-----

::

    stack-bodyparts [all|here] [--dry-run]

Run with ``here`` to process only the selected stockpile. ``all`` (the default) processes every stockpile on the map. The ``--dry-run`` option shows what would be combined without modifying any items.
