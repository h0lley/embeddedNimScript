# embeddedNimScript
Using NimScript as embedded scripting language, enabling hot loading among other neat things.

This can call procs with arguments and return values both ways (nim -> nims & nims -> nim).


## Shared state
I've added a type for shared state in ``state.nim`` to demonstrate how nimscript files that are compiled and exeuted on runtime can modify the state of the main application. This file is imported in ``test.nim`` (example), ``embeddedNimScript/apiImpl.nim`` and ``embeddedNimScript/enims.nim``, and due to that, ``embeddedNimScript`` cannot be treated as fully independent module.

## Assumptions
As mentioned above, the files in ``embeddedNimScript`` assume the existence of ``../state.nim`` where common types are defined.
They also assume these folders and files to be put alongside the binary:

* **scripts**
  * **stdlib** - a copy of Nim's lib directory (version 0.17.2)
  * **api.nim** - the declarations of the procs exposed to the scripts
  * **script1.nims** - the nimscript files, can have any name
  * ...

Furthermore, it is assumed that the shared state contains a ``IdentCache`` type initialized with ``newIdentCache()``.

Most of these assumptions should be pretty easily adjustable or removable though.

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

# The result is wrapped in a PNode so we need to use corresponding proc from compiler/ast to get the value
echo result.getInt() # -4
```

## Extending the API available to the scripts

Just declare new procs in ``scripts/api.nim`` with nothing in the body other than ``builtin``. Example:
```nim
proc add (a, b: int): int = builtin
```

And then implement them in ``embeddedNims/apiImpl.nim`` within the ``exposeScriptApi`` proc. Example:

```nim
expose add:
    # We need to use procs like getInt to retrieve the argument values from VmArgs
    let arg1 = getInt(a, 0)
    let arg2 = getInt(a, 1)
    # Instead of using the return statement we need to use setResult
    setResult(a, arg1 + arg2)
```
And now it can be called from nimscript.

There's no need to include the declarations into the nimscript file manually, this is already being done implicitly.

## Areas of improvement

One thing that's sad is that when you load an erroneous script, the main application terminates. It would be much nicer when the main application would just refuse the the script and keep running, ideally printing a error message / stack trace. For example, that would be great for rapid prototyping or for a plugin/mod system where users may want to toy around in more of a sandbox.

Another thing is that currently, you can only easily pass ints, floats, bools and strings between nim and nims, more complex types are tricky. We'd need additional <get type from VmArgs> and ``setResult`` procs (see ``compiler/vmhooks.nim``), as well as <get type from PNode> procs (see ``compiler/ast.nim``) for the more complex types.

## Version

This is build for the nim compiler version 0.17.0

You may want to replace the copy of the stdlib when there are updates, but keep in mind that only certain modules can be used in nimscript.
