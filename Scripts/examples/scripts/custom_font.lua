local display = getComponents("display")[1]

display.reset()
display.clear()
display.setFont(
    {
        width = 3,
        height = 3,
        chars = {
            error = {
                "111",
                "1.1",
                "111"
            },
            a = {
                ".1.",
                "111",
                "1.1"
            },
            b = {
                "1..",
                "111",
                "111"
            },
            c = {
                "111",
                "1..",
                "111"
            }
        }
    }
)
display.drawText(1, 1, "abcdef", "ff0000")
display.flush()

function callback_loop()
    if _endtick then
        display.clear()
        display.forceFlush()
    end
end