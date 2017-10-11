
from compiler/ast import getInt, newIntNode, nkInt32Lit

import embeddedNims/enims
import state

from os import sleep


proc main =
    let state = new State
    state.vmIdCache = newIdentCache()
    state.modifyMe = "dogs"
    
    echo "\nInitial shared state:         ", state.modifyMe
    
    let
        # Calls the nim proc add (see apiImpl), printing the result of 8 + 12
        script1 = state.compileScript("script1.nims")
        
        # Calls the nim proc modifyState (see apiImpl), chaning state.modifyMe from dogs to cats
        script2 = state.compileScript("script2.nims")
    
    # Calls the nims proc sub with the arguments 8 and 12, and prints the result
    # We need to use procs like newIntNode and getInt since we're dealing with PNode types here
    echo "From NIM to NIMS and back:    8 - 12 = ", script1.call("sub",
        [newIntNode(nkInt32Lit, 8), newIntNode(nkInt32Lit, 12)]).getInt()
    
    # Try hot loading:
    when false:
        echo "quit via ctrl+c"
        while true:
            script1.reload()
            sleep(1000)
    
    echo "State after running scripts:  ", state.modifyMe, "\n"
        
main()
