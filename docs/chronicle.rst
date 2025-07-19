chronicle
=========

.. dfhack-tool::
    :summary: Record fortress events like deaths. Artifact and invasion tracking disabled.
    :tags: fort gameplay

This tool automatically records notable events in a chronicle that is stored
with your save. Currently only unit deaths are recorded since artifact and
invasion tracking has been disabled due to performance issues.

Usage
-----

::

    chronicle enable
    chronicle disable
    chronicle print
    chronicle clear

``chronicle enable``
    Start recording events in the current fortress.
``chronicle disable``
    Stop recording events.
``chronicle print``
    Print all recorded events.
``chronicle clear``
    Delete the chronicle.
