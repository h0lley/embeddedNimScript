
from compiler/astalgo import strTableGet
from compiler/modulegraphs import ModuleGraph, newModuleGraph
from compiler/idents import IdentCache, newIdentCache, getIdent
from compiler/vmdef import PCtx, newCtx, TEvalMode
from compiler/sem import semPass
from compiler/vm import evalPass, registerAdditionalOps, execProc
from compiler/llstream import llStreamOpen
from compiler/options import searchPaths
from compiler/condsyms import initDefines, defineSymbol, undefSymbol
from compiler/passes import registerPass, clearPasses, processModule
from compiler/modules import makeModule, compileSystemModule, includeModule, importModule
from compiler/ast import PSym, PNode, TSymFlag, initStrTable

export idents.newIdentCache

import os


# Assume location of shared types in ../state
from ../state import State, Script
import apiImpl


# The path to the directory that contains the scripts, api declaration, and stdlib source
let scriptsDir = getAppDir() / "scripts"
options.libpath = scriptsDir & "/stdlib"
options.implicitIncludes.add(scriptsDir / "api.nim")


proc setupNimscript =
    passes.gIncludeFile = includeModule
    passes.gImportModule = importModule
    
    initDefines()
    defineSymbol("nimscript")
    defineSymbol("nimconfig")
    registerPass(semPass)
    registerPass(evalPass)


proc cleanupNimscript =
    # resetSystemArtifacts()
    initDefines()
    undefSymbol("nimscript")
    undefSymbol("nimconfig")
    clearPasses()


proc compileScript* (state: State, filename: string): Script =
    setupNimscript()
    
    # Populate result
    result.filename = scriptsDir / filename
    result.graph = newModuleGraph()
    result.cache = state.vmIdCache # A ref to shared identification cache
    result.mainModule = makeModule(result.graph, result.filename)
    incl(result.mainModule.flags, sfMainModule)
    result.context = newCtx(result.mainModule, result.cache)
    result.context.mode = emRepl
    
    # Expose API
    exposeScriptApi(state, result)
    
    # Set context
    vm.globalCtx = result.context
    registerAdditionalOps(vm.globalCtx)
    
    # Compile standard library
    searchPaths.add(options.libpath)
    searchPaths.add(options.libpath / "pure")
    compileSystemModule(result.graph, result.cache)
    
    # Compile script as module
    if not processModule(result.graph, result.mainModule,
        llStreamOpen(result.filename, fmRead), nil, result.cache):
        echo "Failed to process `", result.filename, "`"
    
    # Cleanup
    vm.globalCtx = nil
    cleanupNimscript()


proc reload* (script: Script) =
    setupNimscript()
    
    initStrTable(script.mainModule.tab)
    vm.globalCtx = script.context
    
    if not processModule(script.graph, script.mainModule,
        llStreamOpen(script.filename, fmRead), nil, script.cache):
        echo "Failed to process `", script.filename, "`"
    
    cleanupNimscript()


proc call* (script: Script, procName: string,
    args: openArray[PNode] = []): PNode {.discardable.} =
    vm.globalCtx = script.context
    
    let prc = strTableGet(script.mainModule.tab, getIdent(script.cache, procName))
    assert(not prc.isNil, "\nUnable to locate proc `" & procName & "` in `" & script.filename & "`")    
    
    result = vm.globalCtx.execProc(prc, args)
