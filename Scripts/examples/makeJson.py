import os
import json
import base64

def walk_directory(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            path = os.path.join(root, file)
            with open(path, 'rb') as f:
                lpath = path.replace("\\", "/")
                
                data = f.read()
                disk_data[lpath[lpath.find("/") + 1:].split(".")[0]] = (base64.b64encode(data)).decode("utf-8")


disk_data = {}
walk_directory('scripts')
with open('examples.json', 'w') as f:
        json.dump(disk_data, f)