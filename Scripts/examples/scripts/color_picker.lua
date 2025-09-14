--the code was written by igroin_the_cat
--designed to work with a 128x128 display

--[[
--colorpicker example

local colorpicker = getComponent("colorpicker")
print(colorpicker.getColor())
]]

function convert_to_hex (rgb)
    local hex = ""
    for i = 1 , #rgb do
        local hex_table = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","F"}
        local num =  rgb[i]/16
        local whole = math.floor( num )
        local remainder = num - whole
        hex = hex .. hex_table[whole+1] .. hex_table[remainder*16 + 1]
    end
    return hex
end

update = update or 1
display = getDisplays()[1]
rgb = rgb or {0,0,0}
hex = hex or ""

old_rgb = old_rgb or {0,0,0}

display.setClicksAllowed(true)
state = display.getClick()

if( rgb[1] ~= old_rgb[1] or rgb[2] ~= old_rgb[2] or rgb[3] ~= old_rgb[3])then
    update = 1
    for i =1 ,#rgb do
        old_rgb[i] = rgb[i]
    end
end

color_picker_table_hex = {"ffffff","ff0000","00ff00","0000ff","ffff00","ff00ff","00ffff","ff8000","7f00ff","80ff00","00ff80","0080ff","ff007f","006600","000066","202020","808080","a0a0a0"}
color_picker_table_rgb = {{255,255,255},{255,0,0},{0,255,0},{0,0,255},{255,255,0},{255,0,255},{0,255,255},{255,128,0},{127,0,255},{128,255,0},{0,255,128},{0,128,255},{255,0,127},{0,102,0},{0,0,102},{32,32,32},{128,128,128},{160,160,160}}
rows = {60,71,82,93,104,115}
columns = {95,106,117}
c = 0
c2 = 0

if(state ~= nil)then
    if(state[3] == "pressed" and state[4] == 1)then
        for i = 1, #rows do
            for r = 1, #columns do
                local color = c2 + r
                if(state[2] > rows[i] and state[2] < rows[i]+8 )then
                    if(state[1] > columns[r] and state[1] < columns[r]+8 )then
                        
                        for i =1 ,#rgb do
                            rgb[i] = color_picker_table_rgb[color][i]
                        end
                    end
                end
            end
            c2 = c2 + 3
        end
    end
    if (state[3] == "released" or state[3] == "drag")and state[4] == 1 then
        if(state[1]>0 and state[1]<25)then
            rgb[1] = state[2]*2
        end
        if(state[1]>30 and state[1]<55)then
            rgb[2] = state[2]*2
        end
        if(state[1]>60 and state[1]<85)then
            rgb[3] = state[2]*2
        end
        for i = 1, 3 do
            if rgb[i] == 254 then
                rgb[i] = 255
            end
        end
    end
end

if(update == 1)then
    display.clear()
    r = {0,0,0}
    g = {0,0,0}
    b = {0,0,0}
    y =0
    
    for i = 0 ,128 do
        y = i
        r[1] = 2*i
        g[2] = 2*i
        b[3] = 2*i
        
        display.drawLine(0,y,25,y,convert_to_hex(r))
        display.drawLine(30,y,55,y,convert_to_hex(g))
        display.drawLine(60,y,85,y,convert_to_hex(b))
        display.drawLine(90,0,90,128,"00FF00")
    end
    
    display.fillRect(95,3,30,30,convert_to_hex(rgb))
    display.drawRect(95,3,30,30,"00ff00")
    display.drawText(97,39,tostring(rgb[1]),"ff0000")
    display.drawText(97,45,tostring(rgb[2]),"00ff00")
    display.drawText(97,51,tostring(rgb[3]),"0000ff")
    display.drawRect(95,37,30,21,"00ff00")
    
    display.drawPixel(26,rgb[1]/2.008,"ffffff")
    display.drawPixel(56,rgb[2]/2.008,"ffffff")
    display.drawPixel(86,rgb[3]/2.008,"ffffff")
    
    for i = 1,#rows do
        for l = 1 , #columns do
            local color = c + l
            display.fillRect(columns[l],rows[i],8,8,color_picker_table_hex[color])
        end
        c = c + 3
    end
    display.flush()
    update = 0
end
hex = convert_to_hex(rgb)

if not apiBinded then
    setComponentApi("colorpicker", {
        getColor = function()
            return sm.color.new("#" .. hex)
        end
    })
    apiBinded = true
end