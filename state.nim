
from compiler/idents import IdentCache
from compiler/ast import PSym
from compiler/modulegraphs import ModuleGraph
from compiler/vmdef import PCtx


type
    Script* = tuple[
        filename: string,
        mainModule: PSym,
        graph: ModuleGraph,
        cache: IdentCache,
        context: PCtx]
    
    State* = ref tuple[
        modifyMe: string,
        vmIdCache: IdentCache,
        ]
