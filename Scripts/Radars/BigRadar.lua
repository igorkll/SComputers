dofile '$CONTENT_DATA/Scripts/Radars/RadarBase.lua'

BigRadar = class(nil)

BigRadar.maxParentCount = 1
BigRadar.maxChildCount = 0
BigRadar.connectionInput = sm.interactable.connectionType.composite
BigRadar.colorNormal = sm.color.new(0x7b139eff)
BigRadar.colorHighlight = sm.color.new(0xb81cedff)
BigRadar.componentType = "radar"


function BigRadar.server_onCreate(self)
	self.radar = sc.radar.createRadar(self, 512, 512, math.pi / 6, math.pi / 6, 0.5)
	sc.radar.server_onCreate(self.radar)
end

function BigRadar.server_onFixedUpdate(self)
	sc.creativeCheck(self, self.data and self.data.creative)
	sc.radar.server_onTick(self.radar)
end

function BigRadar.server_onDestroy(self)
	sc.radar.server_onDestroy(self.radar)
end