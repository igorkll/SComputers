exampleComponent = class()
exampleComponent.maxParentCount = 1
exampleComponent.maxChildCount = 0
exampleComponent.connectionInput = sm.interactable.connectionType.composite
exampleComponent.connectionOutput = sm.interactable.connectionType.none
exampleComponent.colorNormal = sm.color.new(0x7F7F7Fff)
exampleComponent.colorHighlight = sm.color.new(0xFFFFFFff)
exampleComponent.componentType = "example" --absences can cause problems

function exampleComponent:server_onCreate()
    self.interactable.publicData = {
        sc_component = {
            type = exampleComponent.componentType,
            api = {
                test = function()
                    return "ok"
                end
            }
        }
    }
end