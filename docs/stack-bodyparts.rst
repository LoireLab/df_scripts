stack-bodyparts
===============

.. dfhack-tool::
    :summary: Make teeth and other body parts stackable.
    :tags: fort items corpsepieces

This script toggles stacking for corpse pieces (e.g. teeth, bones, hair) so they
can be hauled in boxes or bags. It works by marking corpse piece items as
stackable in memory.

Usage
-----

::

    stack-bodyparts enable
    stack-bodyparts disable
    stack-bodyparts status

When enabled, newly created corpse pieces will automatically be stackable until
the script is disabled.
