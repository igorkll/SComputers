import os
import shutil
import time
import sys

if len(sys.argv) > 1:
    pathElements = sys.argv[1].split("\\")
    folderName = pathElements[-1]
    print(f"disk image: {folderName}")
else:
    while True:
        folderName = input("disk image> ")
        if os.path.isdir(folderName):
            break
        print("directory not found")

# Удаляем файлы из папки importer/files
if os.path.isdir("../../USER/importer/files"):
    shutil.rmtree("../../USER/importer/files")

# Копируем файлы из папки образа в папку importer/files
shutil.copytree(folderName, "../../USER/importer/files")

# Запускаем makeJson.py
path = os.getcwd()
os.chdir("../../USER/importer")
os.startfile("makeJson.py")
os.chdir(path)
time.sleep(1)

# Копируем файл disk.json из importer в gamedisks и переименовываем в имя_образа.json
shutil.copyfile("../../USER/importer/disk.json", "../../ROM/gamedisks/" + folderName + ".json")

# Удаляем файл disk.json и папку importer/files
os.remove("../../USER/importer/disk.json")
shutil.rmtree("../../USER/importer/files")
os.mkdir("../../USER/importer/files")
