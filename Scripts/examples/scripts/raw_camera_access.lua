local camera = getComponents("camera")[1]

function callback_loop()
    local data = camera.rawRay(0, 0, 512)
    if data then
        print("----------------")
        for k, v in pairs(data) do
            print(k, v)
        end
    end
end