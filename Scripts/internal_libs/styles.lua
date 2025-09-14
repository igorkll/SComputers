function sc_reglib_styles()
local styles = {}

function styles:switch()
    local color1, color2, bg = self.fg, self.bg, self.bg
    if self.state then
        color1, color2, bg = self.bg_press, self.fg_press, self.bg_press
    end

    local sy = self.sizeY / 2
    local addX = sy - 1
    local py = self.y + sy

    self.display.fillRect(self.x + addX, self.y, self.sizeX - (addX * 2), self.sizeY + (self.sizeY % 2 == 0 and 0 or 1), bg)
    if self.state then
        self.display.fillCircle(self.x + addX, py, sy, color1)
        self.display.fillCircle(self.x + (self.sizeX - 1 - addX), py, sy, color2)
    else
        self.display.fillCircle(self.x + (self.sizeX - 1 - addX), py, sy, color2)
        self.display.fillCircle(self.x + addX, py, sy, color1)
    end
end

function styles:rounded()
    local bg, fg = self.bg, self.fg
    if self.state then
        bg, fg = self.bg_press, self.fg_press
    end
    if self.interactionCurrently then
        bg, fg = self.bg_interaction or bg, self.fg_interaction or fg
    end

    local cornerRadius = self.cornerRadius or (math.min(self.sizeX, self.sizeY) * 0.3)
    local strokeColor = self.state and self.stroke_press or self.stroke_color
    if self.interactionCurrently and self.stroke_interaction then
        strokeColor = self.stroke_interaction
    end
    self.display.fillEllipse(self.x, self.y, self.sizeX, self.sizeY, cornerRadius, bg or self.sceneinstance.color or 0)
    if strokeColor then
        self.display.drawEllipse(self.x, self.y, self.sizeX, self.sizeY, cornerRadius, strokeColor)
    end

    local graphic = sc.lib_require("graphic")
    if self.textBox then
        graphic.textBox(self.display, self.x + 1, self.y + 1, self.sizeX - 1, self.sizeY, self.text, fg, self.centerX, self.centerY, self.spacingY, self.autoNewline, self.tool)
    else
        graphic.textBox(self.display, self.x, self.y, self.sizeX, self.sizeY, self.text, fg, true, true)
    end
end

return styles
end