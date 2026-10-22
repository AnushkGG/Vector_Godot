import zipfile
import os

build_dir = r'c:\Users\ANANYA KOMARWAR\Downloads\vector\c3p_build'
output_file = r'c:\Users\ANANYA KOMARWAR\Downloads\vector\VectorRunner.c3p'

# Remove old output if exists
if os.path.exists(output_file):
    os.remove(output_file)

with zipfile.ZipFile(output_file, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(build_dir):
        for file in files:
            file_path = os.path.join(root, file)
            arcname = os.path.relpath(file_path, build_dir)
            # Use forward slashes in zip paths
            arcname = arcname.replace('\\', '/')
            zf.write(file_path, arcname)
            print(f'  Added: {arcname}')

# Verify
size = os.path.getsize(output_file)
print(f'\nCreated: {output_file}')
print(f'Size: {size:,} bytes ({size/1024:.1f} KB)')

# List contents
with zipfile.ZipFile(output_file, 'r') as zf:
    print(f'Files in archive: {len(zf.namelist())}')
