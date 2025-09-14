if _endtick then
    holo.clear()
    holo.flush()
    return
end

if not start then
    start = true
    tick = 0
    voxel_type = 2

    holo = getHoloprojectors()[1]
    holo.reset()
    holo.clear()

    holo.addVoxel(0, 1, 0, "812d03", voxel_type)
    holo.addVoxel(0, 2, 0, "812d03", voxel_type)
    holo.addVoxel(0, 3, 0, "812d03", voxel_type)
    
    holo.addVoxel(0, 5, 0, "418203", voxel_type)
    holo.addVoxel(0, 4, 0, "418203", voxel_type)
    holo.addVoxel(0, 4, 1, "418203", voxel_type)
    holo.addVoxel(0, 4, -1, "418203", voxel_type)
    holo.addVoxel(1, 4, 0, "418203", voxel_type)
    holo.addVoxel(-1, 4, 0, "418203", voxel_type)

    holo.flush()
end

holo.setScale(0.5, 0.5, 0.5)
holo.setRotation(0, math.rad(tick * 0.5), 0)
holo.setOffset(0, 1 + (math.sin(math.rad(tick)) * 0.8), 0)
tick = tick + 2