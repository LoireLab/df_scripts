holy-war
========

.. dfhack-tool::
    :summary: Start wars when religions clash.
    :tags: fort gameplay diplomacy

This tool compares the spheres of influence represented by the gods of
nearby civilizations with those worshipped by your civilization and
represented in fortress temples. If no spheres overlap, or if the
historical record shows a ``religious_persecution_grudge`` between the
two peoples, the civilization is set to war. Both your stance toward
the other civilization and their stance toward you are set to war,
ensuring a mutual declaration.

Civilizations without proper names are ignored, and the reported sphere
lists contain only the spheres unique to each civilization.

Usage
-----

::

    holy-war [--dry-run]

When run without options, wars are declared immediately on all
qualifying civilizations and an announcement is displayed.  With
``--dry-run``, the tool only reports which civilizations would be
affected without actually changing diplomacy. Each message also notes
whether the conflict arises from disjoint spheres of influence or a
religious persecution grudge and lists the conflicting spheres when
appropriate.
