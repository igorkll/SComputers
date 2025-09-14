ibridge = class()
ibridge.maxParentCount = 1
ibridge.maxChildCount = 0
ibridge.connectionInput = sm.interactable.connectionType.composite
ibridge.connectionOutput = sm.interactable.connectionType.none
ibridge.colorNormal = sm.color.new(0x7F7F7Fff)
ibridge.colorHighlight = sm.color.new(0xFFFFFFff)
ibridge.componentType = "ibridge" --absences can cause problems

function ibridge:check()
    if not dlm then error("The BetterAPI is not installed. the component cannot work", 3) end
    if not sc.restrictions.ibridge then error("the use of the Internet bridge was prohibited by the administrator", 3) end
end

function ibridge:server_onCreate()
    self.interactable.publicData = {
        sc_component = {
            type = ibridge.componentType,
            api = {
                isAllow = function ()
                    return not not (dlm and sc.restrictions.ibridge)
                end,
                get = function (url, headers)
                    self:check()
                    local out = {dlm.http.get(sc.advDeepcopy(url), sc.advDeepcopy(headers))}
                    for key, value in pairs(out) do
                        out[key] = sc.advDeepcopy(value)
                    end
                    return out
                end,
                post = function (url, data, headers)
                    self:check()
                    local out = {dlm.http.post(sc.advDeepcopy(url), sc.advDeepcopy(data), sc.advDeepcopy(headers))}
                    for key, value in pairs(out) do
                        out[key] = sc.advDeepcopy(value)
                    end
                    return out
                end
            }
        }
    }
end