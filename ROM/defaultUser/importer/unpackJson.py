import base64
import json
import os

def unpack_files_from_disk(disk_file, output_folder):
    with open(disk_file, 'r') as f:
        disk_data = json.load(f)

    for relative_path, content in disk_data.items():
        file_path = os.path.join(output_folder, relative_path)
        os.makedirs(os.path.dirname(file_path), exist_ok=True)

        with open(file_path, 'wb') as f:
            f.write(base64.b64decode(content))

disk_file = 'disk.json'
output_folder = 'unpackFiles'

unpack_files_from_disk(disk_file, output_folder)
