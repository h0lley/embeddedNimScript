# embeddedNimScript
Using NimScript as embedded scripting language, enabling hot loading among other neat things.



## Shared state
I've added a type for shared state in ``state.nim`` to demonstrate how nimscript files that are compiled and exeuted on runtime can modify the state of the main application. This file is imported in ``main.nim`` (example), ``embeddedNimScript/apiImpl.nim`` and ``embeddedNimScript/enims.nim``, and due to that, ``embeddedNimScript`` cannot be treated as independent module.

## Assumptions
As mentioned above, the files in ``embeddedNimScript`` assume the existence of ``../state.nim`` where common types are defined.
They also assume these folders and files to be put alongside the binary:

* **scripts**
  * **stdlib** - a copy of Nim's lib directory
  * **api.nim** - the declarations of the procs exposed to the scripts
  * **script1.nims** - the nimscript files, can have any name
  * ...

Furthermore, it is assumed that the shared state contains a ``IdentCache`` type initialized with ``newIdentCache()``.

All of these assumptions should be pretty easily adjustable or removable though.

## Usage

```nim
# Create shared state as described above
let state = new State
state.vmIdCache = newIdentCache()

# Load a script - this will automatically look in the scripts folder mentioned above
# This will also immediately run the script
let script1 = state.compileScript("script1.nims")

# After changing the nimscript file, reload it
# This will also immediately run the script
script1.reload()

# Call a proc that's defined in the nimscript file
# We need to use those newIntNode procs to pass the arguments as PNodes
let result = script1.call("sub", [newIntNode(nkInt32Lit, 8), newIntNode(nkInt32Lit, 12)])

# The result is wrapped in a PNode so we need to use corresponding proc from ``compiler/ast`` to get the value
echo result.getInt()
```

## Version

This is build for the nim compiler version 0.17.2

You may want to replace the copy of the stdlib when there are updates, but keep in mind that only certain modules can be used in nimscript.
