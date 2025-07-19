holy-war
========

.. dfhack-tool::
    :summary: Start wars when religions clash.
    :tags: fort gameplay diplomacy

This tool compares the spheres of influence represented by the gods of
nearby civilizations with those worshipped by your civilization and
represented in fortress temples. If no spheres overlap, or if the
historical record shows a ``religious_persecution_grudge`` between the
two peoples, the civilization is set to war.

Usage
-----

::

    holy-war [--dry-run]

When run without options, wars are declared immediately on all
qualifying civilizations and an announcement is displayed.  With
``--dry-run``, the tool only reports which civilizations would be
affected without actually changing diplomacy.
