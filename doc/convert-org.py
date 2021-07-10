#!/usr/bin/python
import os, sys, filecmp
from subprocess import call

converts = []
for root, dir, files in os.walk("."):
    for file in files:
        if file.endswith(".so"):
            sys.path.insert(0, root)
        if file.endswith(".org") and "figures" not in root:
            root = os.path.abspath(root)
            output = file.rstrip(".org")
            file = os.path.join(root, file)
            # print(file)
            target = os.path.join(root, f"{output}.rst")
            tmp = os.path.join(root, "../", f"{output}.rst")
            ec = f'(progn (find-file "{file}") (end-of-buffer) (org-rst-export-to-rst))'

            # command = f"sh convert_org.sh {file}"
            command = "emacs -u " + '"$(id -un)"'
            command += " --batch --eval '(load user-init-file)'"
            command += f' "{file}" -f org-rst-export-to-rst'
            command = f"emacsclient -e '{ec}'"
            print(">", command)
            os.system(command)
            # command = f"emacsclient\t--eval\t'{ec}'"

            # converts.append(file)
            # o = call(command.split("\t"))
            # print(o)
            # overwrite = False
            # filecmp.clear_cache()
            # try:
            #    # if files are the same remove the tmp
            #    if filecmp.cmp(tmp, target, shallow = False):
            #        print(f"{tmp} is not newer than {target}")
            #        os.system(f"rm {tmp}")
            #    else:
            #        overwrite = True

            # except:
            #    print("no file match found, creating the file")
            #    overwrite = True
            #
            # if overwrite:
            #    print(f"File is new, copying {tmp} to {target}")
            #    os.system(f"mv {tmp} {target}")
