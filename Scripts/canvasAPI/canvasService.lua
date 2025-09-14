canvasService = class()

function canvasService:sv_n_canvasService_request(state, player)
    if not self._audienceData then
        self._audienceData = {}
        self._getAudienceCount = function()
            local count = 0
            local ctick = sm.game.getCurrentTick()
            for id, updateTick in pairs(self._audienceData) do
                if ctick - updateTick <= 80 then
                    count = count + 1
                end
            end
            return count
        end
    end
    if state then
        self._audienceData[player.id] = sm.game.getCurrentTick()
    else
        self._audienceData[player.id] = nil
    end
end

function canvasService:canvasService(state)
    if self.old_canvasService_state ~= state or sm.game.getCurrentTick() % 40 == 0 then
        self.network:sendToServer("sv_n_canvasService_request", state)
        self.old_canvasService_state = state
    end
end

--------------------------------------------------

function canvasService:sv_n_lagDetector_request(score)
    self._lagDetector = (self._lagDetector or 0) + score
    if not self._getLagDetector then
        self._getLagDetector = function()
            local result
            if self._getAudienceCount then
                result = self._lagDetector / math.max(self._getAudienceCount(), 1)
            else
                result = self._lagDetector
            end
            self._lagDetector = 0
            return result or 0
        end
    end
end

function canvasService:lagDetector(execTime, mul)
    local lagScore = execTime * mul
    self._clLagDetector = (self._clLagDetector or 0) + lagScore
    if self._clLagDetector >= 0.5 then
        self.network:sendToServer("sv_n_lagDetector_request", self._clLagDetector)
        self._clLagDetector = 0
    end
end