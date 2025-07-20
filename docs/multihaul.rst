multihaul
=========

.. dfhack-tool::
    :summary: Haulers gather multiple nearby items when using bags or wheelbarrows.
    :tags: fort productivity items

This tool allows dwarves to collect several adjacent items at once when
performing hauling jobs with a bag or wheelbarrow. When enabled, new
``StoreItemInStockpile`` jobs will automatically attach up to four additional
items found within one tile of the original item so they can be hauled in a
single trip.

Usage
-----

::

    multihaul enable
    multihaul disable
    multihaul status

The script can also be enabled persistently with ``enable multihaul``.
