--builds the scmframework. requires specifying a folder with SComputers scripts
--build script for windows

local scomputersScriptsFolder = ...

local function formatPathWithoutSlash(path)
    path = path:gsub("\\", "/")
    if path:sub(#path, #path) == "/" then
        path = path:sub(1, #path - 1)
    end
    return path
end

local function formatPathWithSlash(path)
    path = path:gsub("\\", "/")
    if path:sub(#path, #path) ~= "/" then
        path = path .. "/"
    end
    return path
end

scomputersScriptsFolder = formatPathWithoutSlash(scomputersScriptsFolder)

local function rawList(path)
    path = formatPathWithoutSlash(path)

    if path:find("%\"") then
        error("bad path")
    end

    local dir, err = io.popen("chcp 1251|dir /a /b \"" .. path .. "\"")
    if not dir then
        return nil, tostring(err or "unknown error")
    end

    local tbl = {}
    for filename in dir:lines() do
        table.insert(tbl, filename)
    end
    dir:close()
    return tbl
end

local function exists(path)
    path = formatPathWithoutSlash(path)
    
    local ok, err, code = os.rename(path, path)
    if not ok then
        if code == 13 then
            return true
        end
    end
    return ok, err
end

local function isDir(path)
    path = formatPathWithSlash(path)
    
    local ok, err, code = os.rename(path, path)
    if not ok then
        if code == 13 then
            return true
        end
    end
    return ok, err
end

local function getExtension(name)
    name = formatPathWithoutSlash(name)

    local newName = {}
    for i = string.len(name), 1, -1 do
        local char = string.sub(name, i, i)
        if char == "." then
            break
        end
        table.insert(newName, 1, char)
    end
    return table.concat(newName)
end

local allScriptsList = {}

local function findAllScripts(path)
    path = formatPathWithSlash(path)
    for _, name in ipairs(rawList(path)) do
        local fullpath = path .. name
        if isDir(fullpath) then
            findAllScripts(fullpath)
        else
            if getExtension(fullpath) == "lua" then
                table.insert(allScriptsList, {
                    fullpath = fullpath,
                    gamepath = "$CONTENT_DATA/Scripts/" .. fullpath:sub(#scomputersScriptsFolder + 2, #fullpath)
                })
            end
        end
    end
end
findAllScripts(scomputersScriptsFolder)

local function readFile(path)
    local file, err = io.open(path, "rb")
    if not file then return nil, tostring(err or "unknown error") end
    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    local file, err = io.open(path, "wb")
    if not file then return nil, tostring(err or "unknown error") end
    file:write(tostring(content))
    file:close()
    return true
end

-----------------------------------------------------------

local filepathHash_str = [[scmframework_filepathHash={_VERSION="md5.lua 1.1.0",_DESCRIPTION="MD5 computation in Lua (5.1-3, LuaJIT)",_URL="https://github.com/kikito/md5.lua",_LICENSE=<<<MIT LICENSE

Copyright (c) 2013 Enrique García Cota + Adam Baldwin + hanzao + Equi 4 Software

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.>>>}local a,b,c,d,e=string.char,string.byte,string.format,string.rep,string.sub;local f,g,h,i,j,k;local l,m=pcall(require,"bit")local n,o=pcall(require,"ffi")if l then f,g,h,i,j,k=m.bor,m.band,m.bnot,m.bxor,m.rshift,m.lshift else l,m=pcall(require,"bit32")if l then h=m.bnot;local p=function(q)return q<=0x7fffffff and q or-(h(q)+1)end;local r=function(s)return function(t,u)return p(s(p(t),p(u)))end end;f,g,i=r(m.bor),r(m.band),r(m.bxor)j,k=r(m.rshift),r(m.lshift)else local function v(w)local x=0;local y=1;for z=1,#w do x=x+w[z]*y;y=y*2 end;return x end;local function A(B,C)local D,E=B,C;if#D<#E then D,E=E,D end;for z=#E+1,#D do E[z]=0 end end;local F;h=function(q)local w=F(q)local G=math.max(#w,32)for z=1,G do if w[z]==1 then w[z]=0 else w[z]=1 end end;return v(w)end;F=function(q)if q<0 then return F(h(math.abs(q))+1)end;local w={}local H=1;local I;while q>0 do I=q%2;w[H]=I;q=(q-I)/2;H=H+1 end;return w end;f=function(J,q)local K=F(J)local L=F(q)A(K,L)local w={}for z=1,#K do if K[z]==0 and L[z]==0 then w[z]=0 else w[z]=1 end end;return v(w)end;g=function(J,q)local K=F(J)local L=F(q)A(K,L)local w={}for z=1,#K do if K[z]==0 or L[z]==0 then w[z]=0 else w[z]=1 end end;return v(w)end;i=function(J,q)local K=F(J)local L=F(q)A(K,L)local w={}for z=1,#K do if K[z]~=L[z]then w[z]=1 else w[z]=0 end end;return v(w)end;j=function(q,M)local N=0;if q<0 then q=h(math.abs(q))+1;N=0x80000000 end;local O=math.floor;for z=1,M do q=q/2;q=f(O(q),N)end;return O(q)end;k=function(q,M)if q<0 then q=h(math.abs(q))+1 end;for z=1,M do q=q*2 end;return g(q,0xFFFFFFFF)end end end;local P;if n then local Q=o.typeof("int[1]")P=function(z)return o.string(Q(z),4)end else P=function(z)local s=function(R)return a(g(j(z,R),255))end;return s(0)..s(8)..s(16)..s(24)end end;local function S(R)local T=0;for z=1,#R do T=T*256+b(R,z)end;return T end;local U;if n then local V=o.typeof("const char*")local W=o.typeof("const int*")U=function(R)local X=V(R)return o.cast(W,X)[0]end else U=function(R)local T=0;for z=#R,1,-1 do T=T*256+b(R,z)end;return T end end;local function Y(R)return{U(e(R,1,4)),U(e(R,5,8)),U(e(R,9,12)),U(e(R,13,16)),U(e(R,17,20)),U(e(R,21,24)),U(e(R,25,28)),U(e(R,29,32)),U(e(R,33,36)),U(e(R,37,40)),U(e(R,41,44)),U(e(R,45,48)),U(e(R,49,52)),U(e(R,53,56)),U(e(R,57,60)),U(e(R,61,64))}end;local Z={0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391,0x67452301,0xefcdab89,0x98badcfe,0x10325476}local s=function(_,a0,a1)return f(g(_,a0),g(-_-1,a1))end;local a2=function(_,a0,a1)return f(g(_,a1),g(a0,-a1-1))end;local a3=function(_,a0,a1)return i(_,i(a0,a1))end;local z=function(_,a0,a1)return i(a0,f(_,-a1-1))end;local a1=function(a4,t,u,a5,a6,_,R,a7)t=g(t+a4(u,a5,a6)+_+a7,0xFFFFFFFF)return f(k(g(t,j(0xFFFFFFFF,R)),R),j(t,32-R))+u end;local function a8(a9,aa,ab,ac,ad)local t,u,a5,a6=a9,aa,ab,ac;local ae=Z;t=a1(s,t,u,a5,a6,ad[0],7,ae[1])a6=a1(s,a6,t,u,a5,ad[1],12,ae[2])a5=a1(s,a5,a6,t,u,ad[2],17,ae[3])u=a1(s,u,a5,a6,t,ad[3],22,ae[4])t=a1(s,t,u,a5,a6,ad[4],7,ae[5])a6=a1(s,a6,t,u,a5,ad[5],12,ae[6])a5=a1(s,a5,a6,t,u,ad[6],17,ae[7])u=a1(s,u,a5,a6,t,ad[7],22,ae[8])t=a1(s,t,u,a5,a6,ad[8],7,ae[9])a6=a1(s,a6,t,u,a5,ad[9],12,ae[10])a5=a1(s,a5,a6,t,u,ad[10],17,ae[11])u=a1(s,u,a5,a6,t,ad[11],22,ae[12])t=a1(s,t,u,a5,a6,ad[12],7,ae[13])a6=a1(s,a6,t,u,a5,ad[13],12,ae[14])a5=a1(s,a5,a6,t,u,ad[14],17,ae[15])u=a1(s,u,a5,a6,t,ad[15],22,ae[16])t=a1(a2,t,u,a5,a6,ad[1],5,ae[17])a6=a1(a2,a6,t,u,a5,ad[6],9,ae[18])a5=a1(a2,a5,a6,t,u,ad[11],14,ae[19])u=a1(a2,u,a5,a6,t,ad[0],20,ae[20])t=a1(a2,t,u,a5,a6,ad[5],5,ae[21])a6=a1(a2,a6,t,u,a5,ad[10],9,ae[22])a5=a1(a2,a5,a6,t,u,ad[15],14,ae[23])u=a1(a2,u,a5,a6,t,ad[4],20,ae[24])t=a1(a2,t,u,a5,a6,ad[9],5,ae[25])a6=a1(a2,a6,t,u,a5,ad[14],9,ae[26])a5=a1(a2,a5,a6,t,u,ad[3],14,ae[27])u=a1(a2,u,a5,a6,t,ad[8],20,ae[28])t=a1(a2,t,u,a5,a6,ad[13],5,ae[29])a6=a1(a2,a6,t,u,a5,ad[2],9,ae[30])a5=a1(a2,a5,a6,t,u,ad[7],14,ae[31])u=a1(a2,u,a5,a6,t,ad[12],20,ae[32])t=a1(a3,t,u,a5,a6,ad[5],4,ae[33])a6=a1(a3,a6,t,u,a5,ad[8],11,ae[34])a5=a1(a3,a5,a6,t,u,ad[11],16,ae[35])u=a1(a3,u,a5,a6,t,ad[14],23,ae[36])t=a1(a3,t,u,a5,a6,ad[1],4,ae[37])a6=a1(a3,a6,t,u,a5,ad[4],11,ae[38])a5=a1(a3,a5,a6,t,u,ad[7],16,ae[39])u=a1(a3,u,a5,a6,t,ad[10],23,ae[40])t=a1(a3,t,u,a5,a6,ad[13],4,ae[41])a6=a1(a3,a6,t,u,a5,ad[0],11,ae[42])a5=a1(a3,a5,a6,t,u,ad[3],16,ae[43])u=a1(a3,u,a5,a6,t,ad[6],23,ae[44])t=a1(a3,t,u,a5,a6,ad[9],4,ae[45])a6=a1(a3,a6,t,u,a5,ad[12],11,ae[46])a5=a1(a3,a5,a6,t,u,ad[15],16,ae[47])u=a1(a3,u,a5,a6,t,ad[2],23,ae[48])t=a1(z,t,u,a5,a6,ad[0],6,ae[49])a6=a1(z,a6,t,u,a5,ad[7],10,ae[50])a5=a1(z,a5,a6,t,u,ad[14],15,ae[51])u=a1(z,u,a5,a6,t,ad[5],21,ae[52])t=a1(z,t,u,a5,a6,ad[12],6,ae[53])a6=a1(z,a6,t,u,a5,ad[3],10,ae[54])a5=a1(z,a5,a6,t,u,ad[10],15,ae[55])u=a1(z,u,a5,a6,t,ad[1],21,ae[56])t=a1(z,t,u,a5,a6,ad[8],6,ae[57])a6=a1(z,a6,t,u,a5,ad[15],10,ae[58])a5=a1(z,a5,a6,t,u,ad[6],15,ae[59])u=a1(z,u,a5,a6,t,ad[13],21,ae[60])t=a1(z,t,u,a5,a6,ad[4],6,ae[61])a6=a1(z,a6,t,u,a5,ad[11],10,ae[62])a5=a1(z,a5,a6,t,u,ad[2],15,ae[63])u=a1(z,u,a5,a6,t,ad[9],21,ae[64])return g(a9+t,0xFFFFFFFF),g(aa+u,0xFFFFFFFF),g(ab+a5,0xFFFFFFFF),g(ac+a6,0xFFFFFFFF)end;local function af(self,R)self.pos=self.pos+#R;R=self.buf..R;for ag=1,#R-63,64 do local ad=Y(e(R,ag,ag+63))assert(#ad==16)ad[0]=table.remove(ad,1)self.a,self.b,self.c,self.d=a8(self.a,self.b,self.c,self.d,ad)end;self.buf=e(R,math.floor(#R/64)*64+1,#R)return self end;local function ah(self)local ai=self.pos;local aj=56-ai%64;if ai%64>56 then aj=aj+64 end;if aj==0 then aj=64 end;local R=a(128)..d(a(0),aj-1)..P(g(8*ai,0xFFFFFFFF))..P(math.floor(ai/0x20000000))af(self,R)assert(self.pos%64==0)return P(self.a)..P(self.b)..P(self.c)..P(self.d)end;function scmframework_filepathHash.new()return{a=Z[65],b=Z[66],c=Z[67],d=Z[68],pos=0,buf="",update=af,finish=ah}end;function scmframework_filepathHash.tohex(R)return c("%08x%08x%08x%08x",S(e(R,1,4)),S(e(R,5,8)),S(e(R,9,12)),S(e(R,13,16)))end;function scmframework_filepathHash.sum(R)return scmframework_filepathHash.new():update(R):finish()end;function scmframework_filepathHash.sumhexa(R)return scmframework_filepathHash.tohex(scmframework_filepathHash.sum(R))end]]
filepathHash_str = filepathHash_str:gsub("<<<", "[[")
filepathHash_str = filepathHash_str:gsub(">>>", "]]")
assert(load(filepathHash_str, "=filepathHash"))()

-----------------------------------------------------------

local frameworkTitle = [[--scmframework is a SComputers-based framework for creating scripts for mods
--this file was generated automatically. You can find the utility for generating it in the SComputers files in the directory: USER/documentation/scmframework
--to run the build, run the script in luajit on Windows and specify the path to the SComputers Scripts folder as an argument
--this framework is an official part of SComputers and is freely distributed
--you can embed it in your mods and use it in your scripts when saving this text
--the author's web page: https://igorkll.github.io/logichub/
--SComputers documentation: https://igorkll.github.io/SComputers/
--SComputers in steam: https://steamcommunity.com/sharedfiles/filedetails/?id=2949350596

--The MIT License (MIT)
--Copyright © 2025 BananaPen
--
--Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.]]

local frameworkMain = [[if not __SCMFRAMEWORK then
__SCMFRAMEWORK = true

local strtool = string

local _better = better
local better
if _better and _better.isAvailable() then
    better = _better
else
    __SCMFRAMEWORK_NO_GETAPI = true
end

local _setmetatable, _getmetatable = setmetatable, getmetatable
local setmetatable, getmetatable
if pcall(_setmetatable, {}, {}) then
    setmetatable = _setmetatable
end
if pcall(_getmetatable, {}) then
    getmetatable = _getmetatable
end

local function formatPathWithoutSlash(path)
    path = path:gsub("\\", "/")
    if path:sub(#path, #path) == "/" then
        path = path:sub(1, #path - 1)
    end
    return path
end

local function formatPathWithSlash(path)
    path = path:gsub("\\", "/")
    if path:sub(#path, #path) ~= "/" then
        path = path .. "/"
    end
    return path
end

local function _strSplit(tool, str, seps)
    if type(seps) ~= "table" then
        seps = {seps}
    end

    local parts = {{}}
    local index = 1
    local strlen = tool.len(str)
    while index <= strlen do
        for _ = 0, strlen * 2 do
            local isBreak
            for i, sep in ipairs(seps) do
                sep = tostring(sep)
                if sep ~= "" and tool.sub(str, index, index + (tool.len(sep) - 1)) == sep then
                    table.insert(parts, {})
                    index = index + tool.len(sep)
                    isBreak = true
                    break
                end
            end
            if not isBreak then break end
        end

        table.insert(parts[#parts], tool.sub(str, index, index))
        index = index + 1
    end

    for i, part in ipairs(parts) do
        parts[i] = table.concat(part)
    end

    return parts
end

local function vfs_resolve(...)
    local elementsList = {...}
    local newElements = {}
    for _, elements in ipairs(elementsList) do
        for _, element in ipairs(elements) do
            if element == "." then
            elseif element == ".." then
                if newElements[#newElements] ~= "" then
                    table.remove(newElements)
                end
            elseif element == "" then
                newElements = {""}
            else
                table.insert(newElements, element)
            end
        end
    end
    if #newElements == 1 and newElements[1] == "" then
        return "/"
    end
    return table.concat(newElements, "/")
end

local function vfs_elements(path)
    path = formatPathWithoutSlash(path)

    local elements = {}
    for i, element in ipairs(_strSplit(strtool, path, "/")) do
        elements[i] = element
    end
    return elements
end

local function vfs_path(path)
    local elements = vfs_elements(path)
    table.remove(elements)
    return vfs_resolve(elements)
end

local function vfs_name(path)
    local elements = vfs_elements(path)
    return table.remove(elements)
end

local function vfs_concat(...)
    local paths = {...}
    for i, path in ipairs(paths) do
        paths[i] = vfs_elements(path)
    end
    return vfs_resolve(unpack(paths))
end

local _orig_dofile = dofile
local workingDirectory
local frameworkLoadedParts = {}
local changePrefixPath = "$CONTENT_3aeb81c2-71b9-45a1-9479-1f48f1e8ff21/"
local changePrefixPath2 = "$CONTENT_" .. sm.json.open("$CONTENT_DATA/description.json").localId .. "/"
local function dofile(path)
    if workingDirectory and path:sub(1, 1) ~= "$" then
        path = vfs_concat(workingDirectory, path)
    end
    print("scmframework> ", path)
    pcall(_orig_dofile, path)

    if path:sub(1, #changePrefixPath) == changePrefixPath then
        local oldPath = path
        path = "$CONTENT_DATA/" .. path:sub(#changePrefixPath + 1, #path)
        print("change path (1): ", oldPath, " > ", path)
    elseif path:sub(1, #changePrefixPath2) == changePrefixPath2 then
        local oldPath = path
        path = "$CONTENT_DATA/" .. path:sub(#changePrefixPath2 + 1, #path)
        print("change path (2): ", oldPath, " > ", path)
    end

    if not frameworkLoadedParts[path] then
        frameworkLoadedParts[path] = true
        local old_workingDirectory = workingDirectory
        workingDirectory = vfs_path(path)
        local func = _G["scmframework_" .. scmframework_filepathHash.sumhexa(path)]
        if func then
            print("loaded from framework!")
            func()
        end
        workingDirectory = old_workingDirectory
    end
end
scmframework_dofile = dofile]]

local frameworkEnd = [[dofile("$CONTENT_DATA/Scripts/scmframeworkAPI.lua")
end]]

local function build_framework(name, list, ignorelist, addCode)
    local scmframework = {}

    table.insert(scmframework, frameworkTitle)
    table.insert(scmframework, "\n\n")
    table.insert(scmframework, filepathHash_str)
    table.insert(scmframework, "\n")
    table.insert(scmframework, frameworkMain)
    table.insert(scmframework, "\n")
    if addCode then
        table.insert(scmframework, addCode)
        table.insert(scmframework, "\n")
    end
    for _, script in ipairs(list) do
        local available = true
        for _, path in ipairs(ignorelist or {}) do
            if script.gamepath:sub(1, #path) == path then
                available = false
                break
            end
        end

        if available then
            local content = readFile(script.fullpath)
            local hash = scmframework_filepathHash.sumhexa(script.gamepath)
            table.insert(scmframework, "function scmframework_" .. hash .. "() --" .. script.gamepath .. "\n")
            local ok, err = load(content, "syntaxtest", "t", {})
            if ok then
                table.insert(scmframework, content)
            else
                print("failed to load script (" .. script.gamepath .. "): ", err)
            end
            table.insert(scmframework, "\nend\n")
        end
    end
    table.insert(scmframework, "\n")
    table.insert(scmframework, frameworkEnd)
    table.insert(scmframework, "\n")
    table.insert(scmframework, frameworkTitle)
    table.insert(scmframework, "\n")

    writeFile(name, table.concat(scmframework))
end

build_framework("scmframework.lua", allScriptsList, {"$CONTENT_DATA/Scripts/canvasAPI/fonts/converted/", "$CONTENT_DATA/Scripts/examples/", "$CONTENT_DATA/Scripts/DebugTest/"}, "__SCMFRAMEWORK_NOFONTS = true")
--build_framework("scmframework.lua", allScriptsList, {"$CONTENT_DATA/Scripts/examples/", "$CONTENT_DATA/Scripts/DebugTest/"})