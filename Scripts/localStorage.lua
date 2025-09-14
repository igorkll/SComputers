localStorage = {}
localStorage.path = "$CONTENT_DATA/USER/localStorage.json"
localStorage.paletteCount = 5
localStorage.fontScaleCount = 4
localStorage.emptyPalette = 5

if sm.json.fileExists(localStorage.path) then
    localStorage.current = sm.json.open(localStorage.path)
end

if not localStorage.current then
    localStorage.current = {palette = 0, fontScale = 1}
end

function localStorage.save()
    sm.json.save(localStorage.current, localStorage.path)
end