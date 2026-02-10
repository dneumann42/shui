## Comprehensive tests for Shui widget macro system
import unittest
import shui
import options

# Define all widgets at module level (required for export to work)

# Test 1: Basic widget with state
widget Counter:
  state:
    count: int = 0
  render(ui: var UI):
    discard

# Test 2: Widget without state
widget StatelessWidget:
  render(ui: var UI):
    discard

# Test 3: Widget with events
widget EventCounter:
  state:
    count: int = 0

  event:
    Increment
    Decrement
    SetValue(value: int)

  handle(evt):
    case evt.kind
    of Increment:
      state.count += 1
    of Decrement:
      state.count -= 1
    of SetValue:
      state.count = evt.value

  render(ui: var UI):
    discard

# Test 4: Parameterless render
widget SimpleWidget:
  state:
    value: int = 42

  render:
    discard  # ui should be automatically available

# Test 5: Render with multiple parameters
widget ParameterizedWidget:
  state:
    label: string = "test"

  render(ui: var UI, extra: int):
    discard

# Test 6: Widget with slot/children
widget Container:
  state:
    padding: int = 0

  render(ui: var UI, slot: untyped):
    discard

# Test 7: Stateless widget with slot
widget StatelessContainer:
  render(ui: var UI, slot: untyped):
    discard

# Test 8: Child widget event handling
widget ChildWidget:
  state:
    dummy: int = 0

  event:
    Clicked

  render(ui: var UI):
    discard

widget ParentWidget:
  state:
    child = ChildWidget(dummy: 0)
    clickCount: int = 0

  handle:
    onEvent state.child, Clicked:
      state.clickCount += 1

  render(ui: var UI):
    discard

# Test 9: Multiple child widgets
widget Button:
  state:
    label: string = ""

  event:
    Pressed

  render(ui: var UI):
    discard

widget Menu:
  state:
    button1 = Button(label: "")
    button2 = Button(label: "")
    totalPresses: int = 0

  handle:
    onEvent state.button1, Pressed:
      state.totalPresses += 1
    onEvent state.button2, Pressed:
      state.totalPresses += 10

  render(ui: var UI):
    discard

# Test 10: Events with data
widget DataWidget:
  state:
    lastValue: int = 0
    lastMessage: string = ""

  event:
    ValueChanged(newValue: int)
    MessageReceived(msg: string, priority: int)

  handle(evt):
    case evt.kind
    of ValueChanged:
      state.lastValue = evt.newValue
    of MessageReceived:
      state.lastMessage = evt.msg

  render(ui: var UI):
    discard

# Test 11: State field type inference
widget InferredTypes:
  state:
    intField = 42
    stringField = "hello"
    floatField = 3.14
    boolField = true

  render(ui: var UI):
    discard

# Test 12: State field with explicit type
widget ExplicitTypes:
  state:
    count: int = 0
    name: string = "test"
    value: float = 0.0

  render(ui: var UI):
    discard

# Test 13: Nested widget composition
widget InnerWidget:
  state:
    value: int = 1

  render(ui: var UI):
    discard

widget MiddleWidget:
  state:
    inner = InnerWidget(value: 1)
    multiplier: int = 2

  render(ui: var UI):
    discard

widget OuterWidget:
  state:
    middle = MiddleWidget(inner: InnerWidget(value: 1), multiplier: 2)
    offset: int = 10

  render(ui: var UI):
    discard

# Test 14: Widget with multiple events and child handling
widget ToggleButton:
  state:
    isOn: bool = false

  event:
    Toggled(newState: bool)

  render(ui: var UI):
    discard

widget Panel:
  state:
    toggle1 = ToggleButton(isOn: false)
    toggle2 = ToggleButton(isOn: false)
    activeCount: int = 0

  event:
    PanelChanged

  handle:
    onEvent state.toggle1, Toggled:
      if state.toggle1.isOn:
        state.activeCount += 1
      else:
        state.activeCount -= 1
      emit PanelChanged

    onEvent state.toggle2, Toggled:
      if state.toggle2.isOn:
        state.activeCount += 1
      else:
        state.activeCount -= 1
      emit PanelChanged

  render(ui: var UI):
    discard

# Test 15: Stateless widget with parameters
widget Label:
  render(ui: var UI, text: string, size: int):
    discard

# Test 16: Widget own events and child events
widget ChildButton:
  event:
    Click

  render(ui: var UI):
    discard

widget ContainerWidget:
  state:
    button = ChildButton()
    selfClickCount: int = 0
    childClickCount: int = 0

  event:
    SelfClick

  handle(evt):
    case evt.kind
    of SelfClick:
      state.selfClickCount += 1

  handle:
    onEvent state.button, Click:
      state.childClickCount += 1

  render(ui: var UI):
    discard

# Test 18: Type alias usage
widget MyWidget:
  state:
    value: int = 42

  render(ui: var UI):
    discard

# Test 19: Widget with complex state types
type
  CustomType = object
    x, y: int

widget ComplexWidget:
  state:
    simpleInt: int = 0
    customObj = CustomType(x: 0, y: 0)
    sequence: seq[int] = @[1, 2, 3]
    optional = none(string)

  render(ui: var UI):
    discard

# Test 20: Multiple widgets in same file
widget Widget1:
  state:
    value1: int = 1
  render(ui: var UI):
    discard

widget Widget2:
  state:
    value2: int = 2
  render(ui: var UI):
    discard

widget Widget3:
  state:
    value3: int = 3
  render(ui: var UI):
    discard

# Now the actual tests

test "widget with state - basic creation":
  var state = Counter(count: 5)
  check state.count == 5

test "widget with state - type alias":
  var state2: CounterState = Counter(count: 10)
  check state2.count == 10

test "stateless widget compiles":
  # StatelessWidget should exist and be callable
  # No state type should be required
  discard

test "widget with events - state creation":
  var state = EventCounter(count: 0)
  check state.count == 0

test "widget with events - event types exist":
  # EventCounterEvent and EventCounterEventKind should exist
  let evt = EventCounterEvent(kind: Increment)
  check evt.kind == Increment

test "widget with events - event with data":
  let evt = EventCounterEvent(kind: SetValue, value: 42)
  check evt.kind == SetValue
  check evt.value == 42

test "parameterless render - state creation":
  var state = SimpleWidget(value: 42)
  check state.value == 42

test "render with custom parameters - state creation":
  var state = ParameterizedWidget(label: "hello")
  check state.label == "hello"

test "widget with slot - state creation":
  var state = Container(padding: 10)
  check state.padding == 10

test "child widget events - parent state":
  var parent = ParentWidget(
    child: ChildWidget(),
    clickCount: 0
  )
  check parent.clickCount == 0

test "child widget events - child can have events":
  var parent = ParentWidget(
    child: ChildWidget(),
    clickCount: 0
  )
  parent.child.lastEvent = some(ChildWidgetEvent(kind: Clicked))
  check parent.child.lastEvent.isSome

test "multiple child widgets - initialization":
  var menu = Menu(
    button1: Button(label: "First"),
    button2: Button(label: "Second"),
    totalPresses: 0
  )
  check menu.button1.label == "First"
  check menu.button2.label == "Second"

test "events with data - event construction":
  let evt = DataWidgetEvent(
    kind: ValueChanged,
    newValue: 42
  )
  check evt.kind == ValueChanged
  check evt.newValue == 42

test "events with data - multiple fields":
  let evt = DataWidgetEvent(
    kind: MessageReceived,
    msg: "test",
    priority: 5
  )
  check evt.kind == MessageReceived
  check evt.msg == "test"
  check evt.priority == 5

test "state field type inference - integers":
  var state = InferredTypes()
  check state.intField == 42

test "state field type inference - strings":
  var state = InferredTypes()
  check state.stringField == "hello"

test "state field type inference - floats":
  var state = InferredTypes()
  check state.floatField == 3.14

test "state field type inference - booleans":
  var state = InferredTypes()
  check state.boolField == true

test "state field with explicit type - initialization":
  var state = ExplicitTypes(
    count: 5,
    name: "widget",
    value: 2.5
  )
  check state.count == 5
  check state.name == "widget"
  check state.value == 2.5

test "nested widget composition - three levels":
  var outer = OuterWidget(
    middle: MiddleWidget(
      inner: InnerWidget(value: 5),
      multiplier: 3
    ),
    offset: 20
  )
  check outer.middle.inner.value == 5
  check outer.middle.multiplier == 3
  check outer.offset == 20

test "complex event hierarchy - initialization":
  var panel = Panel(
    toggle1: ToggleButton(isOn: false),
    toggle2: ToggleButton(isOn: false),
    activeCount: 0
  )
  check panel.activeCount == 0
  check panel.toggle1.isOn == false
  check panel.toggle2.isOn == false

test "widget with own and child events - initialization":
  var container = ContainerWidget(
    button: ChildButton(),
    selfClickCount: 0,
    childClickCount: 0
  )
  check container.selfClickCount == 0
  check container.childClickCount == 0

test "widget with own and child events - own event":
  let evt = ContainerWidgetEvent(kind: SelfClick)
  check evt.kind == SelfClick

test "widget with own and child events - child event":
  let evt = ChildButtonEvent(kind: Click)
  check evt.kind == Click

test "type alias interchangeability - MyWidget":
  var state1: MyWidget = MyWidget(value: 1)
  check state1.value == 1

test "type alias interchangeability - MyWidgetState":
  var state2: MyWidgetState = MyWidgetState(value: 2)
  check state2.value == 2

test "type alias interchangeability - mixed 1":
  var state3: MyWidget = MyWidgetState(value: 3)
  check state3.value == 3

test "type alias interchangeability - mixed 2":
  var state4: MyWidgetState = MyWidget(value: 4)
  check state4.value == 4

test "widget with complex state types - custom object":
  var state = ComplexWidget(
    simpleInt: 42,
    customObj: CustomType(x: 10, y: 20),
    sequence: @[4, 5, 6],
    optional: some("test")
  )
  check state.simpleInt == 42
  check state.customObj.x == 10
  check state.customObj.y == 20

test "widget with complex state types - sequence":
  var state = ComplexWidget(
    simpleInt: 0,
    customObj: CustomType(x: 0, y: 0),
    sequence: @[4, 5, 6],
    optional: none(string)
  )
  check state.sequence == @[4, 5, 6]

test "widget with complex state types - option":
  var state = ComplexWidget(
    simpleInt: 0,
    customObj: CustomType(x: 0, y: 0),
    sequence: @[],
    optional: some("test")
  )
  check state.optional.isSome
  check state.optional.get() == "test"

test "multiple widgets in same scope - Widget1":
  var w1 = Widget1(value1: 10)
  check w1.value1 == 10

test "multiple widgets in same scope - Widget2":
  var w2 = Widget2(value2: 20)
  check w2.value2 == 20

test "multiple widgets in same scope - Widget3":
  var w3 = Widget3(value3: 30)
  check w3.value3 == 30

test "multiple widgets in same scope - all together":
  var w1 = Widget1(value1: 10)
  var w2 = Widget2(value2: 20)
  var w3 = Widget3(value3: 30)
  check w1.value1 == 10
  check w2.value2 == 20
  check w3.value3 == 30
