import unittest
import std/os
import std/strutils

import shui/elements

suite "layout calculations":
  test "text size includes padding":
    var ui = UI()
    ui.onMeasureText = proc(text: string): tuple[w, h: int] =
      (w: 60, h: 12)
    elem:
      size = (
        w: Sizing(kind: Fixed, min: 200, max: 200),
        h: Sizing(kind: Fixed, min: 100, max: 100),
      )
      style = Style(padding: 0, gap: 0)
      dir = Col
      align = Start
      crossAlign = Start
      elem:
        text = "Wide"
        style = Style(padding: 8)
    ui.updateLayout((0, 0, 200, 100))
    let textBox = ui.get(ElemIndex(1)).box
    check textBox.w == 60 + 16
    check textBox.h == 12 + 16

  test "row uses gap between children":
    var ui = UI()
    ui.onMeasureText = proc(text: string): tuple[w, h: int] =
      (w: 20, h: 12)
    elem:
      size = (
        w: Sizing(kind: Fixed, min: 200, max: 200),
        h: Sizing(kind: Fixed, min: 100, max: 100),
      )
      style = Style(padding: 0, gap: 10)
      dir = Row
      align = Start
      crossAlign = Start
      elem:
        text = "One"
        style = Style(padding: 8)
      elem:
        text = "Two"
        style = Style(padding: 8)
    ui.updateLayout((0, 0, 200, 100))
    let firstBox = ui.get(ElemIndex(1)).box
    let secondBox = ui.get(ElemIndex(2)).box
    check firstBox.x == 0
    check secondBox.x == firstBox.x + firstBox.w + 10

  test "padding offsets child content":
    var ui = UI()
    ui.onMeasureText = proc(text: string): tuple[w, h: int] =
      (w: 20, h: 12)
    elem:
      size = (
        w: Sizing(kind: Fixed, min: 200, max: 200),
        h: Sizing(kind: Fixed, min: 100, max: 100),
      )
      style = Style(padding: 12, gap: 0)
      dir = Col
      align = Start
      crossAlign = Start
      elem:
        text = "Child"
        style = Style(padding: 8)
    ui.updateLayout((0, 0, 200, 100))
    let parentBox = ui.get(ElemIndex(0)).box
    let childBox = ui.get(ElemIndex(1)).box
    check childBox.x == parentBox.x + 12
    check childBox.y == parentBox.y + 12

  test "cross align centers child vertically":
    var ui = UI()
    ui.onMeasureText = proc(text: string): tuple[w, h: int] =
      (w: 20, h: 12)
    elem:
      size = (
        w: Sizing(kind: Fixed, min: 200, max: 200),
        h: Sizing(kind: Fixed, min: 100, max: 100),
      )
      style = Style(padding: 0, gap: 0)
      dir = Row
      align = Start
      crossAlign = Center
      elem:
        text = "Tall"
        style = Style(padding: 8)
    ui.updateLayout((0, 0, 200, 100))
    let parentBox = ui.get(ElemIndex(0)).box
    let childBox = ui.get(ElemIndex(1)).box
    let expectedY = parentBox.y + ((parentBox.h - childBox.h) div 2)
    check childBox.y == expectedY

  test "writeLayout exports elem info":
    var ui = UI()
    ui.onMeasureText = proc(text: string): tuple[w, h: int] =
      (w: 20, h: 12)
    elem:
      size = (
        w: Sizing(kind: Fixed, min: 100, max: 100),
        h: Sizing(kind: Fixed, min: 100, max: 100),
      )
      style = Style(padding: 8, gap: 0)
      dir = Col
      align = Start
      crossAlign = Start
      elem:
        text = "Export"
        style = Style(padding: 8)
    ui.updateLayout((0, 0, 100, 100))
    let path = "tests/layout_output.txt"
    ui.writeLayout(path)
    let contents = readFile(path)
    removeFile(path)
    check contents.contains("elem 0 parent -1")
    check contents.contains("elem 1 parent 0")
    check contents.contains("text \"Export\"")
