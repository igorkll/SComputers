# как же я люблю chatGpt за то, что мне не нужно сратить время на этот мелкий код

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
                disk_data[lpath[lpath.find("/") + 1:]] = (base64.b64encode(data)).decode("utf-8")


disk_data = {}
walk_directory('files')
with open('disk.json', 'w') as f:
        json.dump(disk_data, f)