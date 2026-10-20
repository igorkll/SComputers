local rates = {1, 2, 4, 6, 8, 10}
local bigSize2 = 256 * 256
local bigSize1 = 128 * 128

function displays_lagCheck(self)
    local lagScore
    if self._getLagDetector then
        lagScore = self._getLagDetector()
    end

	local ctick = sm.game.getCurrentTick()
    if sc.restrictions.screenRate < 0 then
        if lagScore then
            local mathRateIndex = 1
            if lagScore > 8 then
                mathRateIndex = 5
            elseif lagScore > 6 then
                mathRateIndex = 4
            elseif lagScore > 4 then
                mathRateIndex = 3
            elseif lagScore > 2 then
                mathRateIndex = 2
            end
            if sc.restrictions.screenRate == -2 then
                mathRateIndex = mathRateIndex + 1
            end
            local newRate = rates[mathRateIndex] or 1
            if self.mulSize >= bigSize2 then
                if newRate < 4 then
                    newRate = 4
                end
            elseif self.mulSize >= bigSize1 then
                if newRate < 2 then
                    newRate = 2
                end
            end
            if self.allowDownRate or not self.mathRate or newRate > self.mathRate then
                self.allowDownRate = nil
                self.mathRate = newRate
            end
        elseif not self.mathRate then
            self.mathRate = 1
        end
        if ctick % self.mathRate == 0 then
            self.oldMathRate = self.mathRate
            self.allow_send = true
        elseif self.mathRate ~= self.oldMathRate then
            self.oldMathRate = self.mathRate
            self.allow_send = true
        end
    elseif ctick % sc.restrictions.screenRate == 0 then
        self.mathRate = nil
		self.allow_send = true
	end

    if ctick % (40 * 4) == 0 then
        self.tryPacket = nil
    end

    if ctick % 40 == 0 then
        self.allowDownRate = true
    end

    if self.lastComputer and self.lastComputer.lagScore and lagScore and type(sc.restrictions.lagDetector) == "number" then
        self.lastComputer.lagScore = self.lastComputer.lagScore + (lagScore * sc.restrictions.lagDetector)
    end
end