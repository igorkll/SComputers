function sc_reglib_json()
local jsonlib = {}
local json = json
local jsonEncodeInputCheck = jsonEncodeInputCheck

function jsonlib.encode(tbl)
    jsonEncodeInputCheck(tbl, 0)
    return json.encode(tbl)
end

function jsonlib.decode(jsonstring)
    return json.decode(jsonstring)
end

function jsonlib.nativeEncode(tbl)
    jsonEncodeInputCheck(tbl, 0)
    return sm.json.writeJsonString(tbl)
end

function jsonlib.nativeDecode(jsonstring)
    return sm.json.parseJsonString(jsonstring)
end

return jsonlib
end