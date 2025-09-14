dofile '$CONTENT_DATA/Scripts/Radars/RadarBase.lua'

SmallRadar = class(nil)

SmallRadar.maxParentCount = 1
SmallRadar.maxChildCount = 0
SmallRadar.connectionInput = sm.interactable.connectionType.composite
SmallRadar.colorNormal = sm.color.new(0x7b139eff)
SmallRadar.colorHighlight = sm.color.new(0xb81cedff)
SmallRadar.componentType = "radar"


function SmallRadar.server_onCreate(self)
	self.radar = sc.radar.createRadar(self, 32, 32, math.pi / 6, math.pi / 6, 3.5)
	sc.radar.server_onCreate(self.radar)
end

function SmallRadar.server_onFixedUpdate(self)
	sc.creativeCheck(self, self.data and self.data.creative)
	sc.radar.server_onTick(self.radar)
end

function SmallRadar.server_onDestroy(self)
	sc.radar.server_onDestroy(self.radar)
end