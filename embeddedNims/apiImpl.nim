
from compiler/vmdef import registerCallback, VmArgs
from compiler/vm import getInt, getString, setResult

from os import splitFile

# Assume location of shared state type in  in ../state
from ../state import State, Script


proc exposeScriptApi* (state: State, script: Script) =
    let moduleName = script.filename.splitFile.name
    template expose (procName, procBody: untyped) {.dirty.} =
        script.context.registerCallback moduleName & "." & astToStr(procName),
            proc (a: VmArgs) =
                procBody
    
    expose add:
        # We need to use procs like getInt to retrieve the argument values from VmArgs
        # Instead of using the return statement we need to use setResult
        setResult(a,
            getInt(a, 0) +
            getInt(a, 1))
    
    expose modifyState:
        state.modifyMe = getString(a, 0)
