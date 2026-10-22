dofile("$CONTENT_DATA/Scripts/Displays/GuiDisplay.lua")
HudDisplay = class(GuiDisplay)
HudDisplay.maxParentCount = 2
HudDisplay.maxChildCount = 0
HudDisplay.connectionInput = sm.interactable.connectionType.composite + sm.interactable.connectionType.power
