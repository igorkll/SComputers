dofile '$CONTENT_DATA/Scripts/Radars/RadarBase.lua'

Radar = class(nil)

Radar.maxParentCount = 1
Radar.maxChildCount = 0
Radar.connectionInput = sm.interactable.connectionType.composite
Radar.colorNormal = sm.color.new(0x7b139eff)
Radar.colorHighlight = sm.color.new(0xb81cedff)
Radar.componentType = "radar"


function Radar.server_onCreate(self)
	self.radar = sc.radar.createRadar(self, 128, 128, math.pi / 6, math.pi / 6, 1.5)
	sc.radar.server_onCreate(self.radar)
end

function Radar.server_onFixedUpdate(self)
	sc.creativeCheck(self, self.data and self.data.creative)
	sc.radar.server_onTick(self.radar)
end

function Radar.server_onDestroy(self)
	sc.radar.server_onDestroy(self.radar)
end