#!/usr/bin/python
import os, sys, filecmp
from subprocess import call

for root, dir, files in os.walk('.'):
    for file in files:
        if file.endswith(".so"):
            sys.path.insert(0, root)
        if file.endswith(".org"):
            root = os.path.abspath(root)
            output = file.rstrip(".org")
            file = os.path.join(root, file)
            target = os.path.join(root, f"{output}.rst")
            tmp = os.path.join(root, "../", f"{output}.rst")
            command = f"pandoc {file} -t rst -o {tmp}".split()
            call(command)
            overwrite = False
            filecmp.clear_cache()
            try:
                # if files are the same remove the tmp
                if filecmp.cmp(tmp, target, shallow = False):
                    print(f"{tmp} is not newer than {target}")
                    os.system(f"rm {tmp}")
                else:
                    overwrite = True

            except:
                print("no file match found, creating the file")
                overwrite = True
            
            if overwrite:
                print(f"File is new, copying {tmp} to {target}")
                os.system(f"mv {tmp} {target}")

