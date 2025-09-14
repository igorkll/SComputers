dofile("$CONTENT_DATA/Scripts/Config.lua")
dofile("$CONTENT_DATA/Scripts/FileSystem.lua")

hdd = class(nil)
hdd.maxParentCount = 1
hdd.maxChildCount = 0
hdd.connectionInput = sm.interactable.connectionType.composite
hdd.colorNormal = sm.color.new(0xbf1996ff)
hdd.colorHighlight = sm.color.new(0xec1db9ff)
hdd.componentType = "disk"

worldDisksLoaded = worldDisksLoaded or {}

function hdd.server_onCreate(self)
	local id = self.interactable:getId()
	
	local data
	print("loading disk content", pcall(function()
		data = self.storage:load()
	end))
	print("disk content type:", type(data))

	if self.data and self.data.world then
		local fsdata = sm.storage.load(data and data.key or "*")
		if data and data.key and fsdata then
			print("deserialize world disk data")
			self.worldKey = data.key
			self.fs = FileSystem.deserialize(fsdata)
			if worldDisksLoaded[self.worldKey] then
				local oldKey = self.worldKey
				self.worldKey = tostring(sm.uuid.new())
				self.storage:save({key = self.worldKey})
				sm.storage.save(self.worldKey, self.fs:serialize())
				print("two world disks with the same uuid exist simultaneously, automatic cloning", oldKey, ">", self.worldKey)
			end
			if self.data then
				local newsize = math.floor(self.data.size)
				if math.floor(self.fs.maxSize) ~= newsize then
					print("old disk size", math.floor(self.fs.maxSize))
					print("new disk size", newsize)
					self.fs.maxSize = newsize
				else
					print("disk size:", newsize)
				end
			end
		else
			print("new image created")
			self.worldKey = tostring(sm.uuid.new())
			self.fs = FileSystem.new(math.floor(self.data.size))
			self.storage:save({key = self.worldKey})
		end

		worldDisksLoaded[self.worldKey] = true
	else
		if data then
			print("deserialize disk")
			self.fs = FileSystem.deserialize(data)
			if self.data then
				local newsize = math.floor(self.data.size)
				if math.floor(self.fs.maxSize) ~= newsize then
					print("old disk size", math.floor(self.fs.maxSize))
					print("new disk size", newsize)
					self.fs.maxSize = newsize
				else
					print("disk size:", newsize)
				end
			end
		elseif self.data then
			print("create new disk data")
			self.fs = FileSystem.new(math.floor(self.data.size))
		else
			print("create new creative disk data")
			self.fs = FileSystem.new(1024 * 1024 * 1024)
		end
	end

	sc.hardDiskDrivesDatas[id] = FileSystem.createSelfData(self)
	self.changed = false
	fsmanager_init(self)
    if sc.creativeCheck(self, not self.data) then return end
end

function hdd:server_onFixedUpdate()
    if sc.creativeCheck(self, not self.data) then return end

	if self.changed and self.data and sc.needSaveData() then
		--print("SAVE DISK DATA")

		local data = self.fs:serialize()
		if self.worldKey then
			sm.storage.save(self.worldKey, data)
		else
			self.storage:save(data)
		end

		self.changed = false
	end
end

function hdd.server_onDestroy(self)
	local id = self.interactable:getId()
	sc.hardDiskDrivesDatas[id] = nil
	if self.worldKey then
		worldDisksLoaded[self.worldKey] = nil
	end
end

-----------------------------------------------------------

function hdd:client_onCreate()
	fsmanager_init(self)
end

function hdd:client_onInteract(_, state)
	if state and not sc.disableFilesystemMenu then
		fsmanager_open(self)
	end
end

function hdd:client_canInteract()
	return not sc.disableFilesystemMenu
end