wheelbarrow-multi
=================

.. dfhack-tool::
    :summary: Load multiple items into wheelbarrows with one job.
    :tags: fort productivity items

This tool allows dwarves to gather several adjacent items at once when
loading wheelbarrows. When enabled, new ``StoreItemInVehicle`` jobs will
automatically attach nearby items so they can be hauled in a single trip.
By default, up to four additional items within one tile of the original
item are collected.

Usage
-----

::

    wheelbarrow-multi enable [<options>]
    wheelbarrow-multi disable
    wheelbarrow-multi status
    wheelbarrow-multi config [<options>]

Options
-------

``--radius <tiles>``
    Search this many tiles around the target item for additional items. Default
    is ``1``.
``--max-items <count>``
    Attach at most this many additional items to each job. Default is ``4``.
``--debug``
    Show debug messages via ``dfhack.gui.showAnnouncement`` when items are
    attached. Use ``--no-debug`` to disable.
