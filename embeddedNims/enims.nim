
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

import os, threadpool, times

import apiImpl


# The path to the directory that contains the scripts, api declaration, and stdlib source
let scriptsDir = getAppDir() / "scripts"
options.libpath = scriptsDir & "/stdlib"
options.implicitIncludes.add(scriptsDir / "api.nim")

# Identifer cache
let identCache = newIdentCache()


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


proc watch (filename: string): int =
    var writeTime: Time
    var info: FileInfo
    while true:
        info = getFileInfo(filename)
        writeTime = info.lastWriteTime
        sleep(100)
        info = getFileInfo(filename)
        if writeTime != info.lastWriteTime and info.size > 0:
            break


proc compileScript* (filename: string, watch = true): Script =
    setupNimscript()

    # Populate result
    result.new()
    result.filename = scriptsDir / filename
    result.moduleName = filename.splitFile.name
    result.graph = newModuleGraph()
    result.mainModule = makeModule(result.graph, result.filename)
    incl(result.mainModule.flags, sfMainModule)
    result.context = newCtx(result.mainModule, identCache)
    result.context.mode = emRepl

    # Expose API
    result.exposeScriptApi()

    # Set context
    vm.globalCtx = result.context
    registerAdditionalOps(vm.globalCtx)

    # Compile standard library
    searchPaths.add(options.libpath)
    searchPaths.add(options.libpath / "pure")
    compileSystemModule(result.graph, identCache)

    # Compile script as module
    if not processModule(result.graph, result.mainModule,
        llStreamOpen(result.filename, fmRead), nil, identCache):
        echo "Failed to process `", result.filename, "`"

    # Cleanup
    vm.globalCtx = nil
    cleanupNimscript()

    # Watch the script file for changes
    if watch: result.watcher = spawn watch result.filename


proc reload* (script: Script) =
    setupNimscript()

    initStrTable(script.mainModule.tab)
    vm.globalCtx = script.context

    if not processModule(script.graph, script.mainModule,
        llStreamOpen(script.filename, fmRead), nil, identCache):
        echo "Failed to process `", script.filename, "`"

    cleanupNimscript()


proc getProc (script: Script, procName: string): PSym =
    strTableGet(script.mainModule.tab, getIdent(identCache, procName))


proc hasProc* (script: Script, procName: string): bool =
    not script.getProc(procName).isNil


proc call* (script: Script, procName: string,
    args: openArray[PNode] = []): PNode {.discardable.} =
    # Check the watcher
    if not script.watcher.isNil and script.watcher.isReady:
        echo script.moduleName, " changed - reloading"
        script.reload()
        script.watcher = spawn watch script.filename

    vm.globalCtx = script.context

    let prc = script.getProc(procName)
    assert(not prc.isNil, "\nUnable to locate proc `" & procName & "` in `" & script.filename & "`")

    result = vm.globalCtx.execProc(prc, args)
