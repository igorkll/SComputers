dofile '$CONTENT_DATA/Scripts/Radars/RadarBase.lua'

ExtraBigRadar = class(nil)

ExtraBigRadar.maxParentCount = 1
ExtraBigRadar.maxChildCount = 0
ExtraBigRadar.connectionInput = sm.interactable.connectionType.composite
ExtraBigRadar.colorNormal = sm.color.new(0x7b139eff)
ExtraBigRadar.colorHighlight = sm.color.new(0xb81cedff)
ExtraBigRadar.componentType = "radar"


function ExtraBigRadar.server_onCreate(self)
	self.radar = sc.radar.createRadar(self, 2048, 2048, math.pi / 6, math.pi / 6, 0.05)
	sc.radar.server_onCreate(self.radar)
end

function ExtraBigRadar.server_onFixedUpdate(self)
	sc.creativeCheck(self, self.data and self.data.creative)
	sc.radar.server_onTick(self.radar)
end

function ExtraBigRadar.server_onDestroy(self)
	sc.radar.server_onDestroy(self.radar)
end