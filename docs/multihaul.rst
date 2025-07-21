multihaul
=========

.. dfhack-tool::
    :summary: Haulers gather multiple nearby items when using wheelbarrows.
    :tags: fort productivity items

This tool allows dwarves to collect several adjacent items at once when
performing hauling jobs with a wheelbarrow. When enabled, new
``StoreItemInStockpile`` jobs will automatically attach nearby items so
they can be hauled in a single trip. Which items qualify can be controlled
with the ``--mode`` option. The script only triggers when a wheelbarrow is
definitively attached to the job. By default, up to ten additional items within
10 tiles of the original item are collected.
Jobs with wheelbarrows that are not assigned as push vehicles are ignored and
any stuck hauling jobs are automatically cleared.
Only items that match the destination stockpile filters are added to the job.

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
    is ``10``.
``--max-items <count>``
    Attach at most this many additional items to each hauling job. Default is
    ``10``.
``--mode <any|sametype|samesubtype|identical>``
    Control which nearby items are attached. ``any`` collects any allowed items,
    ``sametype`` only matches the item type, ``samesubtype`` requires type and
    subtype to match, and ``identical`` additionally matches material. The
    default is ``sametype``.
``--debug``
    Show debug messages via ``dfhack.gui.showAnnouncement`` when items are
    attached. Use ``--no-debug`` to disable.
