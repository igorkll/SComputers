--full documentation: https://igorkll.github.io/rom.html

--1. save your creation on blueprint
--2. remove your creation from the world (so as not to get confused)
--3. create your own json file with the data
--4. open the folder with your creation (usually the folder with all the blueprints is located along the path: C:\Users\User\AppData\Roaming\Axolot Games\Scrap Mechanic\User\User_XXXXXXXXXXXXXXXXX\Blueprints)
--5. find the folder with your creation and put your json there (read the description.json to make sure that you are putting the json file in the same blueprint as the ROM disk. if this is not the case, the disk will work for you, but it will not work for subscribers of your creation)
--6. remember the UUID of your creation and the name of your json file
--7. load your creation from blueprint and find your ROM disk on it. specify the path to your json in it (it should look something like this: $CONTENT_XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/rom.json) DO NOT REMOVE YOUR CREATION FROM THE LIFT BEFORE YOU SAVE IT!
--8. save your creation to blueprint again UNDER THE SAME NAME WITH OVERWRITING!! this is very important, without it, if you post your creation, subscribers will not get access to the data in json
--9. as a result, it should turn out that your creation has a json file with the data you need, and it also has a ROM disk where the path to this json is indicated, where the UUID of this creation itself is located

local json = require("json")
local rom = getComponent("rom")

if rom.isAvailable() then
    logPrint("data from ROM has been successfully read: ", json.nativeEncode(rom.open()))
else
    logPrint("failed to read ROM data")
end

function callback_loop() end