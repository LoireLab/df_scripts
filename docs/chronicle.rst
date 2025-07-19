chronicle
=========

.. dfhack-tool::
    :summary: Record fortress events like deaths, item creation, and invasions.
    :tags: fort gameplay

This tool automatically records notable events in a chronicle that is stored
with your save. Unit deaths, artifact creation events, invasions, and yearly
totals of crafted items are recorded. Artifact entries now include the full
announcement text from the game, complete with item descriptions and special
characters rendered just as they appear in the in-game logs.

Usage
-----

::

    chronicle enable
    chronicle disable
    chronicle print [count]
    chronicle summary
    chronicle clear

``chronicle enable``
    Start recording events in the current fortress.
``chronicle disable``
    Stop recording events.
``chronicle print``
    Print the most recent recorded events. Takes an optional ``count``
    argument (default ``25``) that specifies how many events to show. Prints
    a notice if the chronicle is empty.
``chronicle summary``
    Show yearly totals of created items by category (non-artifact items only).
``chronicle clear``
    Delete the chronicle.
