dofile '$CONTENT_DATA/Scripts/Radars/RadarBase.lua'

UnrestrictedRadar = class(nil)

UnrestrictedRadar.maxParentCount = 1
UnrestrictedRadar.maxChildCount = 0
UnrestrictedRadar.connectionInput = sm.interactable.connectionType.composite
UnrestrictedRadar.colorNormal = sm.color.new(0x7b139eff)
UnrestrictedRadar.colorHighlight = sm.color.new(0xb81cedff)
UnrestrictedRadar.componentType = "radar"


function UnrestrictedRadar.server_onCreate(self)
	self.unrestricted = true
	self.radar = sc.radar.createRadar(self, 2048, 2048, math.pi / 6, math.pi / 6, 0)
	sc.radar.server_onCreate(self.radar)
end

function UnrestrictedRadar.server_onFixedUpdate(self)
	sc.creativeCheck(self, true)
	sc.radar.server_onTick(self.radar)
end

function UnrestrictedRadar.server_onDestroy(self)
	sc.radar.server_onDestroy(self.radar)
end