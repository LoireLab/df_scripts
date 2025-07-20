chronicle
=========

.. dfhack-tool::
    :summary: Record fortress events like deaths, item creation, and invasions.
    :tags: fort gameplay

This tool automatically records notable events in a chronicle that is stored
with your save. Unit deaths now include the cause of death as well as any
titles, nicknames, or noble positions held by the fallen. Artifact creation
events, invasions, mission reports, and yearly totals of crafted items are also
recorded. Announcements for masterwork creations can be toggled on or off
and are enabled by default. Artifact entries include the full announcement text
from the game, and output text is sanitized so that any special characters are
replaced with simple Latin equivalents.

Usage
-----

::

    chronicle enable
    chronicle disable
    chronicle print [count]
    chronicle summary
    chronicle clear
    chronicle masterworks <enable|disable>
    chronicle export [filename]
    chronicle view

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
``chronicle masterworks``
    Enable or disable logging of masterwork creation announcements. When run
    with no argument, displays the current setting.
``chronicle export``
    Write all recorded events to a text file. If ``filename`` is omitted, the
    output is saved as ``chronicle.txt`` in your save folder.
``chronicle view``
    Display the full chronicle in a scrollable window.

Examples
--------

``chronicle print 10``
    Show the 10 most recent chronicle entries.
``chronicle summary``
    Display yearly summaries of items created in the fort.
