from Cython.Build import cythonize
from Cython.Distutils import build_ext
from setuptools import setup
from setuptools.extension import Extension
import numpy, multiprocessing as mp, os

import re, os
from subprocess import run
add = []
compiler = 'g++'
optFlag  = '-Ofast'
cppv     = '20'

flags = f'{optFlag} -march=native -std=c++{cppv} -flto '\
        '-frename-registers -funroll-loops -fno-wrapv '\
        '-fopenmp-simd -fopenmp -unused-variable -Wno-unused'

# collect pyx files
exts = []
baseDir =  os.getcwd() + os.path.sep
nums = numpy.get_include()


data_files = []
for (root, dirs, files) in os.walk(baseDir):
    for file in files:
        fileName = os.path.join(root, file)
        if file.endswith('.pyx') and not "tests" in root:
            # some cython shenanigans
            extPath  = fileName.replace(baseDir, '') # make relative
            extName  = extPath.split('.')[0].replace(os.path.sep, '.') # remove extension

            sources  = [extPath]

            if os.path.exists(extPath.replace('pyx', "pxd")):
                base, f = os.path.split(fileName)
                base = os.path.basename(base)
                data_files.append((base, [extPath.replace("pyx", "pxd")]))

            ex = Extension(extName,
                           sources            = sources,
                           include_dirs       = [nums, '.'],
                           libraries          = ['stdc++'],
                           extra_compile_args = flags.split(),
                           extra_link_args = ['-fopenmp',
                                              f'-std=c++{cppv}',
                                              # '-g'
                                              ] + add,
            )
            exts.append(ex)

print(f"data files {data_files}")
print(f'{len(exts)} will be compiled')

from Cython.Compiler import Options
Options.fast_fail = True
cdirectives =  dict(
                    cdivision        = True,
                    binding          = True,
                    embedsignature   = True,
                    boundscheck      = False,
                    initializedcheck = False,
                    overflowcheck    = False,
                    nonecheck        = False,
                    )
import unittest
def TestSuite():
    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover('plexsim/tests', pattern='test_*.py',
                                      top_level_dir = 'plexsim')
    return test_suite
#with open('requirements.txt', 'r') as f:
#    requirements = f.read().splitlines()
from setuptools import find_namespace_packages, find_packages
from sphinx.setup_command import BuildDoc
name    = "plexsim"
version = "2.0"
packages = find_packages(include = ["plexsim", "plexsim.*"])

sphinx = dict(project = ("setup.py", name),
              version = ("setup.py", version),
              source_dir = ("setup.py", "docs/source"),
              #build_dir = ("setup.py", "docs/build"),
              )
# future me note: sometimes headers are not included; clean the dist and build folders
# and rebuild
setup(
    name                 = name,
    author               = "Casper van Elteren",
    author_email         = "caspervanelteren@gmail.com",
    url                  = "cvanelteren.githubio.io",
    version              = version,
    zip_safe             = False,
    #package_dir        = {"" : "plexsim"},
    package_data       = {
        "" : "*.pyx *.pxd".split(),
     #  "plexsim" : "plexsim/*pyx plexsim/*pxd".split(),
                     },
    include_package_data = True,
    data_files           = data_files,
    packages             = packages, 
    install_requires     = "cython numpy networkx".split(),
    cmdclass             = dict(build_sphinx = BuildDoc),
    command_options      = dict(build_sphinx = sphinx),
    ext_modules          = cythonize(
                            exts,
                            compiler_directives = cdirectives,
                            nthreads            = mp.cpu_count(),
    ),
)
