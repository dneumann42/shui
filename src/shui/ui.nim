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
  AbstractComponentState = ref object of RootObj
  ComponentState*[T] = ref object of AbstractComponentState
    state*: T
  Component* = ref object of Widget
    abstractState*: AbstractComponentState

method draw*(self: Component) {.base.} =
  discard

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

macro renderWidget*(widget, painter: typed): untyped =
  ## Recursively render a widget tree with the given painter
  ## Automatically calls draw() on all components and descends into containers
  result = quote do:
    proc renderImpl(w: Widget, p: auto) =
      # Try to call draw if it exists (for components)
      when compiles(w.draw(p)):
        w.draw(p)

      # Recurse into containers
      if w of Container:
        for child in Container(w).children:
          renderImpl(child, p)

    renderImpl(`widget`, `painter`)

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
    type `componentName`* = ref object of Component
      painter: `painterType`
  )

  # Generate lowercase constructor from init proc
  if hasInit:
    let initParams = ctor[3]  # Formal params from init
    let initBody = ctor[6]    # Init body

    # Build constructor proc with same params as init
    let abstractState = quote do:
      AbstractComponentState(ComponentState[`stateTypeName`](
        state: 
          block: 
            `initBody`))
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
          nnkDotExpr.newTree(ident("result"), ident("abstractState")),
          abstractState
        )
      )
    )
    echo constructor.repr
    result.add(constructor)
  else:
    error("Component must have an init proc", blk)

  # Add draw method if present
  if not drawProc.isNil:
    let body = drawProc[6]
    result.add(quote do:
      method draw* (self: `componentName`) = `body`)

