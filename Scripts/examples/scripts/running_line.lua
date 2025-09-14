if not start then
    text = "hello, world! abcdefghijklmnopqrstuvwxyz  ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    display = getComponents("display")[1]
    display.reset()
    display.clear()
    display.setSkipAtNotSight(true)
    --display.setUtf8Support(true) --call to print Russian characters

    startPos = display.getWidth()
    textPos = startPos
    start = true
end

if _endtick then
    display.clear()
    display.forceFlush()
    return
end

display.clear("0076a1")
display.drawText(textPos, 1, text, "05a4dc")
display.flush()

textPos = textPos - 1 - getSkippedTicks()
if textPos < -(utf8.len(text) * (display.getFontWidth() + 1)) then
    textPos = startPos
end