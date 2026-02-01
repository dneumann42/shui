import widgets, containers, macros, strutils, macrocache

# Store the Painter type at compile time using macrocache
const painterTypeKey = "shuiPainterType"
const painterTypeCache = CacheTable(painterTypeKey)

macro setPainterType*(painterType: typed) =
  ## Call this from your app to set the Painter type at compile time
  ## Example: setPainterType(Drawing)
  painterTypeCache[painterTypeKey] = painterType
  result = newEmptyNode()

proc getPainterType(): NimNode =
  ## Get the cached Painter type, or use a default placeholder
  if painterTypeCache.hasKey(painterTypeKey):
    result = painterTypeCache[painterTypeKey]
  else:
    # Default to a generic ref object if not set
    result = ident("RootObj")

type
  Component*[T: tuple, E, P] = ref object of Widget
    state*: T
    when E isnot void:
      update*: proc(self: var T, event: E): void

proc childStmts*(blk: NimNode): NimNode =
  result = nnkStmtList.newTree()
  for child in blk:
    # Skip discard statements and empty nodes
    if child.kind == nnkDiscardStmt or child.kind == nnkEmpty:
      continue

    result.add(
      quote do:
        let childWidget = block:
          `child`
        if parent of Container:
          Container(parent).add(childWidget)
    )

macro doContainer(init, blk: untyped): untyped =
  quote do:
    block:
      var parent {.inject.} = `init`
      `blk`
      parent

proc buildContainerMacro(containerName: string, params: NimNode): NimNode =
  ## Helper to build container macros (row/column) with optional parameters
  let blk = params[^1]

  # Build the container constructor call with parameters (if any)
  var initCall = newCall(ident(containerName))
  if params.len > 1:
    # Has parameters before the block
    for i in 0 ..< params.len - 1:
      initCall.add(params[i])

  var stmts = blk.childStmts()
  result = quote do:
    doContainer(`initCall`, `stmts`)

macro row*(params: varargs[untyped]): untyped =
  buildContainerMacro("Row", params)

macro column*(params: varargs[untyped]): untyped =
  buildContainerMacro("Column", params)

macro component*(id, blk): untyped =
  expectKind(blk, nnkStmtList)
  let componentName = id
  let stateTypeName = ident(id.repr & "State")
  let initName = ident("init" & id.repr)
  let constructorName = ident(id.repr.toLowerAscii)  # lowercase constructor

  result = nnkStmtList.newTree()

  var ctor: NimNode = nil
  var drawProc: NimNode = nil
  var hasInit = false

  for stmt in blk:
    if stmt.kind == nnkCall and stmt[0].repr == "state":
      expectKind(stmt[1][0], nnkTupleTy)
      let tup = stmt[1][0]
      result.insert(0,
        quote do:
          type `stateTypeName`* = `tup`
      )
    elif stmt.kind == nnkProcDef and stmt[0].repr == "init":
      # Store the init proc
      ctor = stmt
      hasInit = true
    elif stmt.kind == nnkProcDef and stmt[0].repr == "update":
      discard
    elif stmt.kind == nnkProcDef and stmt[0].repr == "draw":
      drawProc = stmt
    else:
      error("Unexpected statement in component:\n" & stmt.treeRepr)

  # Generate Component type (without events for now)
  let painterType = getPainterType()
  result.add(quote do:
    type `componentName`* = ref object of Component[`stateTypeName`, void, `painterType`]
  )

  # Generate lowercase constructor from init proc
  if hasInit:
    let initParams = ctor[3]  # Formal params from init
    let initBody = ctor[6]    # Init body

    # Build constructor proc with same params as init
    let constructor = nnkProcDef.newTree(
      nnkPostfix.newTree(ident("*"), constructorName),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(componentName).add(initParams[1..^1]),  # Copy params from init
      newEmptyNode(),
      newEmptyNode(),
      nnkStmtList.newTree(
        nnkCall.newTree(ident("new"), ident("result")),
        nnkAsgn.newTree(
          nnkDotExpr.newTree(ident("result"), ident("state")),
          initBody
        )
      )
    )
    result.add(constructor)
  else:
    error("Component must have an init proc", blk)

  # Add draw method if present
  if not drawProc.isNil:
    let painterType = getPainterType()
    let drawBody = drawProc[6]
    let selfParam = drawProc[3][1][0]  # First param name
    let painterParam = drawProc[3][2][0]  # Second param name

    # Build the proc manually to avoid type checking in wrong context
    let drawProcDef = nnkProcDef.newTree(
      nnkPostfix.newTree(ident("*"), ident("draw")),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        newEmptyNode(),  # No return type
        nnkIdentDefs.newTree(ident("component"), componentName, newEmptyNode()),
        nnkIdentDefs.newTree(painterParam, painterType, newEmptyNode())
      ),
      newEmptyNode(),
      newEmptyNode(),
      nnkStmtList.newTree(
        nnkLetSection.newTree(
          nnkIdentDefs.newTree(
            selfParam,
            newEmptyNode(),
            nnkDotExpr.newTree(ident("component"), ident("state"))
          )
        ),
        drawBody
      )
    )
    result.add(drawProcDef)

# Label component moved to user code (corpotocracy.nim)
# 
# component Button:
#   state: 
#     tuple[title: string, onPress: proc(): void]
#   event:
#     Pressed
#   ui:
#     box:
#       label(state.title)
# 
#   proc init(title: string, onPress: proc(): void): ButtonState =
#     (title: title, onPress: onPress)
# 
#   proc update(self: var ButtonState, event: ButtonEvent) =
#     case event
#     of Pressed:
#       self.onPress()
# 
# component Counter:
#   state: tuple[count: int]
# 
#   event:
#     Increment
#     Decrement
#     Reset
# 
#   proc init(): CounterState =
#     (count: 1)
# 
#   proc update(self: var CounterState, event: CounterEvent) =
#     discard
# 
#   proc ui(self: CounterState) =
#     box:
#       button("Decrement") do():
#         emit(Decrement)
#       label($self.count)
#       button("Increment") do():
#         emit(Increment)
# 
