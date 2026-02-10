## Stateful Widget Macro
##
## Provides a macro for defining stateful UI widgets with local event handling.
## This allows creating reusable, self-contained UI components with their own
## state management and event handling logic.
##
## Includes a simple signal system for widget-to-widget communication.

import macros

# Simple signal type for widget communication
type
  Signal*[T] = object
    callbacks: seq[proc(args: T) {.gcsafe.}]

  Signal0* = object
    callbacks: seq[proc() {.gcsafe.}]

proc emit*[T](signal: var Signal[T], args: T) {.inline.} =
  for cb in signal.callbacks:
    cb(args)

proc emit*(signal: var Signal0) {.inline.} =
  for cb in signal.callbacks:
    cb()

proc connect*[T](signal: var Signal[T], callback: proc(args: T) {.gcsafe.}) =
  signal.callbacks.add(callback)

proc connect*(signal: var Signal0, callback: proc() {.gcsafe.}) =
  signal.callbacks.add(callback)

proc transformEmitCalls(node: NimNode, eventName: NimNode): NimNode =
  ## Transform `emit EventKind` into `emit(Event(kind: EventKind))`
  ## and `emit EventKind(field: value)` into `emit(Event(kind: EventKind, field: value))`
  case node.kind:
  of nnkCommand:
    if node.len >= 2 and node[0].eqIdent("emit"):
      # emit EventKind or emit EventKind(args)
      let eventKind = node[1]
      if eventKind.kind == nnkIdent:
        # Simple: emit EventKind -> emit(Event(kind: EventKind))
        return newCall(
          ident("emit"),
          nnkObjConstr.newTree(
            eventName,
            nnkExprColonExpr.newTree(
              ident("kind"),
              eventKind
            )
          )
        )
      elif eventKind.kind == nnkCall or eventKind.kind == nnkObjConstr:
        # With params: emit EventKind(args) -> emit(Event(kind: EventKind, args...))
        let kind = if eventKind.kind == nnkCall: eventKind[0] else: eventKind[0]
        var objConstr = nnkObjConstr.newTree(eventName)
        objConstr.add(
          nnkExprColonExpr.newTree(
            ident("kind"),
            kind
          )
        )
        # Add all the fields from the event constructor
        for i in 1 ..< eventKind.len:
          objConstr.add(eventKind[i])
        return newCall(ident("emit"), objConstr)
  else:
    discard

  # Recursively transform children
  result = copyNimNode(node)
  for child in node:
    result.add(transformEmitCalls(child, eventName))

macro widget*(args: varargs[untyped]): untyped =
  ## Define a stateful Shui widget with local event handling and signals
  ##
  ## Example:
  ##   widget Counter:
  ##     state:
  ##       count: int = 0
  ##       childWidget: ChildWidgetState
  ##     signals:
  ##       onIncrement(amount: int)
  ##       onDecrement
  ##     event:
  ##       Increment
  ##       Decrement
  ##       SetValue(value: int)
  ##     handle(evt):
  ##       case evt.kind
  ##       of Increment: state.count += 1
  ##       of Decrement: state.count -= 1
  ##       of SetValue: state.count = evt.value
  ##     init:
  ##       # Initialize child widgets and connect signals
  ##       state.childWidget.onClicked.connect(proc() = emit Increment)
  ##     render(ui: var UI):
  ##       button("Click"):
  ##         onClick:
  ##           emit Increment
  ##           state.onIncrement.emit(1)

  # Parse: widget Name: body
  # args[0] is the name, args[1] is the body
  if args.len != 2:
    error("widget expects: widget Name: <body>")

  let name = args[0]
  let body = args[1]

  expectKind(body, nnkStmtList)

  var stateSection, signalsSection, eventSection, handleSection, handleChildrenSection, initSection, renderSection: NimNode

  # Parse the widget definition sections
  for stmt in body:
    if stmt.kind == nnkCall and stmt.len >= 2:
      let sectionName = stmt[0]
      if sectionName.eqIdent("state"):
        stateSection = stmt[1]
      elif sectionName.eqIdent("signals"):
        signalsSection = stmt[1]
      elif sectionName.eqIdent("event"):
        eventSection = stmt[1]
      elif sectionName.eqIdent("handle"):
        # Distinguish between handle(evt): and handle:
        if stmt.len == 3 and stmt[1].kind == nnkIdent:
          # handle(evt): - handles widget's own events
          handleSection = stmt
        elif stmt.len == 2 and stmt[1].kind == nnkStmtList:
          # handle: - handles child events
          handleChildrenSection = stmt[1]
      elif sectionName.eqIdent("init"):
        initSection = stmt
      elif sectionName.eqIdent("render"):
        # render: body (no params) is parsed as Call(Ident("render"), StmtList(body))
        renderSection = stmt
      elif sectionName.kind == nnkObjConstr and sectionName[0].eqIdent("render"):
        # render(params): body is parsed as Call(ObjConstr(render, params...), body)
        renderSection = stmt

  # Generate type names
  let stateName = ident($name & "State")
  let eventKindName = ident($name & "EventKind")
  let eventName = ident($name & "Event")
  # Simplified render name: just lowercase widget name
  let renderProcName = block:
    let nameStr = $name
    var lowerName = nameStr
    if lowerName.len > 0:
      lowerName[0] = chr(ord(lowerName[0]) + 32)  # Convert first char to lowercase
    ident(lowerName)

  result = newStmtList()

  # 1. Generate event types first (if needed by state)
  if eventSection != nil:
    var eventKinds = nnkEnumTy.newTree(newEmptyNode())
    var eventRecCase = nnkRecCase.newTree(
      nnkIdentDefs.newTree(ident("kind"), eventKindName, newEmptyNode())
    )

    for eventDef in eventSection:
      case eventDef.kind:
      of nnkIdent:
        # Simple event with no data: EventName
        eventKinds.add(eventDef)
        eventRecCase.add(
          nnkOfBranch.newTree(eventDef, nnkRecList.newTree())
        )
      of nnkCall, nnkObjConstr:
        # Event with data: EventName(field: Type) or EventName(field: Type, field2: Type2)
        let eventKind = eventDef[0]
        eventKinds.add(eventKind)
        var fieldList = nnkRecList.newTree()
        for i in 1 ..< eventDef.len:
          let param = eventDef[i]
          case param.kind:
          of nnkExprColonExpr:
            # field: Type format
            let fieldName = param[0]
            let fieldType = param[1]
            fieldList.add(
              nnkIdentDefs.newTree(
                nnkPostfix.newTree(ident("*"), fieldName),
                fieldType,
                newEmptyNode()
              )
            )
          of nnkIdentDefs:
            # Already in the right format
            fieldList.add(param)
          else:
            error("Invalid event parameter: " & repr(param), param)
        eventRecCase.add(
          nnkOfBranch.newTree(eventKind, fieldList)
        )
      else:
        error("Invalid event definition kind " & $eventDef.kind & ": " & repr(eventDef), eventDef)

    let eventKindTypeDef = nnkTypeDef.newTree(
      nnkPostfix.newTree(ident("*"), eventKindName),
      newEmptyNode(),
      eventKinds
    )
    result.add(nnkTypeSection.newTree(eventKindTypeDef))

    let eventTypeDef = nnkTypeDef.newTree(
      nnkPostfix.newTree(ident("*"), eventName),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree(eventRecCase)
      )
    )
    result.add(nnkTypeSection.newTree(eventTypeDef))

  # 2. Generate state type (only if state section exists or widget has events)
  let hasState = stateSection != nil or eventSection != nil

  if hasState:
    var stateFields = nnkRecList.newTree()

    # Add lastEvent field if widget has events
    if eventSection != nil:
      stateFields.add(
        nnkIdentDefs.newTree(
          nnkPostfix.newTree(ident("*"), ident("lastEvent")),
          nnkBracketExpr.newTree(ident("Option"), eventName),
          newEmptyNode()
        )
      )

    if stateSection != nil:
      for field in stateSection:
        case field.kind:
          of nnkCall:
            # This is: fieldName: Type = value
            # Structure: Call(Ident fieldName, StmtList(Asgn(Type, value)))
            if field.len == 2 and field[0].kind == nnkIdent and field[1].kind == nnkStmtList:
              # fieldName: Type = value format
              let fieldName = field[0]
              let stmtList = field[1]
              if stmtList.len > 0 and stmtList[0].kind == nnkAsgn:
                let fieldType = stmtList[0][0]
                let defaultValue = stmtList[0][1]
                stateFields.add(
                  nnkIdentDefs.newTree(
                    nnkPostfix.newTree(ident("*"), fieldName),
                    fieldType,
                    defaultValue
                  )
                )
              else:
                error("Invalid state field format: " & repr(field), field)
            else:
              error("Invalid state field structure: " & repr(field), field)
          of nnkAsgn:
            # fieldName: Type = defaultValue OR fieldName = value (type inferred)
            let lhs = field[0]
            let defaultValue = field[1]
            if lhs.kind == nnkExprColonExpr:
              # fieldName: Type = value
              let fieldName = lhs[0]
              let fieldType = lhs[1]
              stateFields.add(
                nnkIdentDefs.newTree(
                  nnkPostfix.newTree(ident("*"), fieldName),
                  fieldType,
                  defaultValue
                )
              )
            elif lhs.kind == nnkIdent:
              # fieldName = value (infer type)
              let fieldName = lhs
              stateFields.add(
                nnkIdentDefs.newTree(
                  nnkPostfix.newTree(ident("*"), fieldName),
                  newEmptyNode(),  # Empty type = infer from value
                  defaultValue
                )
              )
            else:
              error("Invalid state field format: " & repr(field), field)
          of nnkExprColonExpr:
              # fieldName: Type (no default value)
              let fieldName = field[0]
              let fieldType = field[1]
              stateFields.add(
                nnkIdentDefs.newTree(
                  nnkPostfix.newTree(ident("*"), fieldName),
                  fieldType,
                  newEmptyNode()  # No default value
                )
              )
          of nnkIdentDefs:
            # Already in correct format
            stateFields.add(field)
          else:
            error("Invalid state field kind " & $field.kind & ": " & repr(field), field)

    # Add signal fields to state
    if signalsSection != nil:
      for signalDef in signalsSection:
        case signalDef.kind:
        of nnkIdent:
          # Simple signal: SignalName (no parameters)
          let signalName = signalDef
          stateFields.add(
            nnkIdentDefs.newTree(
              nnkPostfix.newTree(ident("*"), signalName),
              ident("Signal0"),
              newEmptyNode()
            )
          )
        of nnkCall, nnkObjConstr:
          # Signal with parameters: SignalName(param: Type, ...)
          let signalName = signalDef[0]
          var paramTypes = newSeq[NimNode]()
          for i in 1 ..< signalDef.len:
            let param = signalDef[i]
            if param.kind == nnkExprColonExpr:
              paramTypes.add(param[1])  # Just the type
            else:
              error("Invalid signal parameter: " & repr(param), param)

          # If single parameter, use Signal[Type], otherwise use Signal[tuple[...]]
          let signalType =
            if paramTypes.len == 1:
              nnkBracketExpr.newTree(ident("Signal"), paramTypes[0])
            else:
              var tupleType = nnkTupleConstr.newTree()
              for pt in paramTypes:
                tupleType.add(pt)
              nnkBracketExpr.newTree(ident("Signal"), tupleType)

          stateFields.add(
            nnkIdentDefs.newTree(
              nnkPostfix.newTree(ident("*"), signalName),
              signalType,
              newEmptyNode()
            )
          )
        else:
          error("Invalid signal definition: " & repr(signalDef), signalDef)

    let stateTypeDef = nnkTypeDef.newTree(
      nnkPostfix.newTree(ident("*"), stateName),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        stateFields
      )
    )

    # Also create a type alias using the widget name (without "State" suffix)
    let typeAlias = nnkTypeDef.newTree(
      nnkPostfix.newTree(ident("*"), name),
      newEmptyNode(),
      stateName
    )

    result.add(nnkTypeSection.newTree(stateTypeDef, typeAlias))

  # 3. Generate render proc with emit and handle
  if renderSection != nil:
    # Build the parameter list for render proc/template
    var procParams = nnkFormalParams.newTree(newEmptyNode())
    var hasChildrenSlot = false
    var childrenParams = newSeq[NimNode]()

    # Determine if this is parameterless render or has parameters
    let renderBody = renderSection[1]
    let hasRenderParams = renderSection[0].kind == nnkObjConstr

    if hasRenderParams:
      # render(params): body - has ObjConstr with parameters
      let objConstr = renderSection[0]

      # Add custom parameters from ObjConstr
      for i in 1 ..< objConstr.len:
        let paramExpr = objConstr[i]
        if paramExpr.kind == nnkExprColonExpr:
          let paramName = paramExpr[0]
          let paramType = paramExpr[1]

          # Check if this is a children: untyped parameter
          if paramName.eqIdent("slot") and paramType.eqIdent("untyped"):
            hasChildrenSlot = true
            # Don't add to procParams yet - will add after state
          else:
            procParams.add(
              nnkIdentDefs.newTree(
                paramName,
                paramType,
                newEmptyNode()
              )
            )
            childrenParams.add(paramName)  # Track params for template
    else:
      # render: body - no parameters specified, add default ui: var UI
      procParams.add(
        nnkIdentDefs.newTree(
          ident("ui"),
          nnkVarTy.newTree(ident("UI")),
          newEmptyNode()
        )
      )

    # Add state parameter (only if widget has state)
    if hasState:
      procParams.add(
        nnkIdentDefs.newTree(
          ident("state"),
          nnkVarTy.newTree(stateName),
          newEmptyNode()
        )
      )

    # Add children parameter last if detected
    if hasChildrenSlot:
      procParams.add(
        nnkIdentDefs.newTree(
          ident("slot"),
          ident("untyped"),
          newEmptyNode()
        )
      )

    # Build the render proc body
    let renderProcBody = newStmtList()

    # Add container template for auto-parenting child widgets
    let containerTemplate = quote do:
      template container(body: untyped) =
        ui.withParent(elemIndex):
          body
    renderProcBody.add(containerTemplate)

    # Add onEvent template for child events (always available)
    let onEventTemplate = quote do:
      template onEvent(childState: var auto, eventKind: typed, body: untyped) =
        if childState.lastEvent.isSome:
          let evt = childState.lastEvent.get()
          if ord(evt.kind) == ord(eventKind):
            body
            childState.lastEvent.reset()
    renderProcBody.add(onEventTemplate)

    # Only create emit template and transform emit calls if events are defined
    let transformedRenderBody =
      if eventSection != nil:
        # Build the emit template (not a proc, to avoid closure capture issues)
        let emitTemplateBody = newStmtList()

        # Store event in lastEvent for parent checking
        emitTemplateBody.add(quote do:
          state.lastEvent = some(event)
        )

        if handleSection != nil and handleSection.len >= 3:
          # handleSection is Call(Ident "handle", Ident "evt", StmtList(body))
          let handleParam = handleSection[1]  # evt parameter name
          let handleCode = handleSection[2]    # body
          let eventParam = ident("event")

          # Build: let evt = event; <handleCode>
          emitTemplateBody.add(
            nnkLetSection.newTree(
              nnkIdentDefs.newTree(
                handleParam,
                newEmptyNode(),
                eventParam
              )
            )
          )
          emitTemplateBody.add(handleCode)

        let emitTemplate = nnkTemplateDef.newTree(
          ident("emit"),
          newEmptyNode(),
          newEmptyNode(),
          nnkFormalParams.newTree(
            newEmptyNode(),
            nnkIdentDefs.newTree(
              ident("event"),
              eventName,
              newEmptyNode()
            )
          ),
          newEmptyNode(),
          newEmptyNode(),
          emitTemplateBody
        )

        renderProcBody.add(emitTemplate)

        # Transform emit calls in render body
        transformEmitCalls(renderBody, eventName)
      else:
        # No events, use render body as-is
        renderBody

    # Unpack render body statements into proc body
    if transformedRenderBody.kind == nnkStmtList:
      for stmt in transformedRenderBody:
        renderProcBody.add(stmt)
    else:
      renderProcBody.add(transformedRenderBody)

    # Inject handleChildren code AFTER render (with transformed emit calls)
    # This ensures the UI is rendered before events are processed
    if eventSection != nil and handleChildrenSection != nil:
      let transformedHandleChildren = transformEmitCalls(handleChildrenSection, eventName)
      # Wrap in a block to isolate from UI building context
      let handleBlock = newStmtList(
        nnkBlockStmt.newTree(
          newEmptyNode(),
          transformedHandleChildren
        )
      )
      renderProcBody.add(handleBlock)

    # Build render proc or template
    if hasChildrenSlot:
      # Generate as template for children slot support
      # Use dirty pragma to avoid hygiene issues with elem syntax
      result.add(
        nnkTemplateDef.newTree(
          nnkPostfix.newTree(ident("*"), renderProcName),
          newEmptyNode(),  # term rewriting
          newEmptyNode(),  # generic params
          procParams,
          nnkPragma.newTree(ident("dirty")),  # dirty pragma
          newEmptyNode(),  # reserved
          renderProcBody
        )
      )
    else:
      # Generate as proc
      result.add(
        nnkProcDef.newTree(
          nnkPostfix.newTree(ident("*"), renderProcName),
          newEmptyNode(),
          newEmptyNode(),
          procParams,
          nnkPragma.newTree(ident("gcsafe")),
          newEmptyNode(),
          renderProcBody
        )
      )

  # 4. Generate init proc if init section exists
  if initSection != nil and initSection.len >= 2:
    let initProcName = ident("init" & $name)

    # Parse init section: init(params): body or just init: body
    var initParams = nnkFormalParams.newTree(newEmptyNode())
    var initBody: NimNode

    if initSection[0].kind == nnkObjConstr:
      # init(params): body
      let objConstr = initSection[0]
      initBody = initSection[1]

      # Add custom parameters from ObjConstr
      for i in 1 ..< objConstr.len:
        let paramExpr = objConstr[i]
        if paramExpr.kind == nnkExprColonExpr:
          let paramName = paramExpr[0]
          let paramType = paramExpr[1]
          initParams.add(
            nnkIdentDefs.newTree(
              paramName,
              paramType,
              newEmptyNode()
            )
          )
    else:
      # init: body (no parameters)
      initBody = initSection[1]

    # Add state parameter
    initParams.add(
      nnkIdentDefs.newTree(
        ident("state"),
        nnkVarTy.newTree(stateName),
        newEmptyNode()
      )
    )

    # Build init proc
    result.add(
      nnkProcDef.newTree(
        nnkPostfix.newTree(ident("*"), initProcName),
        newEmptyNode(),
        newEmptyNode(),
        initParams,
        nnkPragma.newTree(ident("gcsafe")),
        newEmptyNode(),
        initBody
      )
    )
