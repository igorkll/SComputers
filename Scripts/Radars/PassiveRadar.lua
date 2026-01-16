dofile '$CONTENT_DATA/Scripts/Radars/RadarBase.lua'

PassiveRadar = class(nil)

PassiveRadar.maxParentCount = 1
PassiveRadar.maxChildCount = 0
PassiveRadar.connectionInput = sm.interactable.connectionType.composite
PassiveRadar.colorNormal = sm.color.new(0x7b139eff)
PassiveRadar.colorHighlight = sm.color.new(0xb81cedff)
PassiveRadar.componentType = "radar"


function PassiveRadar.server_onCreate(self)
    self.passive = true
	self.radar = sc.radar.createRadar(self, nil, nil, math.pi / 6, math.pi / 6)
	sc.radar.server_onCreate(self.radar)
end

function PassiveRadar.server_onFixedUpdate(self)
	sc.creativeCheck(self, self.data and self.data.creative)
	sc.radar.server_onTick(self.radar)
end

function PassiveRadar.server_onDestroy(self)
	sc.radar.server_onDestroy(self.radar)
end