chronicle
=========

.. dfhack-tool::
    :summary: Record fortress events like deaths, item creation, and invasions.
    :tags: fort gameplay

This tool automatically records notable events in a chronicle that is stored
with your save. Unit deaths, all item creation events, and invasions are
recorded.

Usage
-----

::

    chronicle enable
    chronicle disable
    chronicle print [count]
    chronicle clear

``chronicle enable``
    Start recording events in the current fortress.
``chronicle disable``
    Stop recording events.
``chronicle print``
    Print the most recent recorded events. Takes an optional ``count``
    argument (default ``25``) that specifies how many events to show. Prints
    a notice if the chronicle is empty.
``chronicle clear``
    Delete the chronicle.
