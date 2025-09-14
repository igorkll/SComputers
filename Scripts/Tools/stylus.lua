local rend = {"$CONTENT_DATA/Tools/Renderables/stylus.rend"}

stylus = class()
sm.tool.preloadRenderables(rend)

function stylus:client_onEquippedUpdate(primaryState, secondaryState)
    if primaryState == sm.tool.interactState.start then
        _G.stylus_left = true
    end
    if primaryState == sm.tool.interactState.stop then
        _G.stylus_left = nil
    end

    if secondaryState == sm.tool.interactState.start then
        _G.stylus_right = true
    end
    if secondaryState == sm.tool.interactState.stop then
        _G.stylus_right = nil
    end

    self.tool:updateFpAnimation("connecttool_use_connect", 1, 1)
    return true, true
end

function stylus:client_onEquip()
    self.tool:setTpRenderables(rend)
    self.tool:setFpRenderables(rend)

    _G.stylus_left = nil
    _G.stylus_right = nil
end

function stylus:client_onUnequip()
    _G.stylus_left = nil
    _G.stylus_right = nil
end

function stylus:client_onDestroy()
    _G.stylus_left = nil
    _G.stylus_right = nil
end