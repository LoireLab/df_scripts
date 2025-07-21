multihaul
=========

.. dfhack-tool::
    :summary: Haulers gather multiple nearby items when using wheelbarrows.
    :tags: fort productivity items

This tool allows dwarves to collect several adjacent items at once when
performing hauling jobs with a wheelbarrow. When enabled, new
``StoreItemInStockpile`` jobs will automatically attach identical nearby items so
they can be hauled in a single trip. The script only triggers when a
wheelbarrow is definitively attached to the job. By default, up to four
additional items within one tile of the original item are collected.

Usage
-----

::

    multihaul enable [<options>]
    multihaul disable
    multihaul status
    multihaul config [<options>]

The script can also be enabled persistently with ``enable multihaul``.

Options
-------

``--radius <tiles>``
    Search this many tiles around the target item for additional items. Default
    is ``1``.
``--max-items <count>``
    Attach at most this many additional items to each hauling job. Default is
    ``4``.
``--debug``
    Show debug messages via ``dfhack.gui.showAnnouncement`` when items are
    attached. Use ``--no-debug`` to disable.
