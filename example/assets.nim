import std/[os, math, streams]

type Px = tuple[r, g, b: uint8]

proc writeBmp(path: string; w, h: int; shade: proc(x, y: int): Px) =
  let rowRaw = w * 3
  let pad = (4 - (rowRaw mod 4)) mod 4
  let dataSize = (rowRaw + pad) * h
  var s = newFileStream(path, fmWrite)
  doAssert s != nil, "cannot open " & path
  s.write("BM")
  s.write(uint32(54 + dataSize))
  s.write(uint32(0))
  s.write(uint32(54))
  s.write(uint32(40))
  s.write(int32(w))
  s.write(int32(h))
  s.write(uint16(1))
  s.write(uint16(24))
  s.write(uint32(0))
  s.write(uint32(dataSize))
  s.write(int32(2835))
  s.write(int32(2835))
  s.write(uint32(0))
  s.write(uint32(0))
  for row in 0 ..< h:
    let y = h - 1 - row
    for x in 0 ..< w:
      let p = shade(x, y)
      s.write(p.b); s.write(p.g); s.write(p.r)
    for _ in 0 ..< pad:
      s.write(uint8(0))
  s.close()

proc clampU8(v: float): uint8 =
  uint8(max(0.0, min(255.0, v)))

proc generateAssets*(dir: string) =
  createDir(dir)

  writeBmp(dir / "banner.bmp", 200, 44, proc(x, y: int): Px =
    let tx = x / 199
    let ty = y / 43
    (clampU8(46 + tx * 70 - ty * 18),
     clampU8(96 + tx * 70),
     clampU8(150 + tx * 80 + ty * 20)))

  writeBmp(dir / "glyph.bmp", 28, 28, proc(x, y: int): Px =
    let dx = abs(x.float - 13.5)
    let dy = abs(y.float - 13.5)
    if dx + dy < 10.0:
      (clampU8(252), clampU8(206), clampU8(86))
    elif dx + dy < 12.0:
      (clampU8(168), clampU8(132), clampU8(48))
    else:
      (clampU8(34), clampU8(40), clampU8(58)))
