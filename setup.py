from Cython.Build import cythonize
from Cython.Distutils import build_ext
from setuptools import setup
from setuptools.extension import Extension
import numpy, multiprocessing as mp, os

import re, os
from subprocess import run
__version__ = "1.9.0"
add = []
compiler = 'g++'
optFlag = '-Ofast'
cppv    = '17'

flags = f'{optFlag} -march=native -std=c++{cppv} -flto '\
        '-frename-registers -funroll-loops -fno-wrapv '\
        '-fopenmp-simd -fopenmp -unused-variable -Wno-unused'

# collect pyx files
exts = []
baseDir =  os.getcwd() + os.path.sep
nums = numpy.get_include()

for (root, dirs, files) in os.walk(baseDir):
    for file in files:
        fileName = os.path.join(root, file)
        if file.endswith('.pyx'):
            # some cython shenanigans
            extPath  = fileName.replace(baseDir, '') # make relative
            extName  = extPath.split('.')[0].replace(os.path.sep, '.') # remove extension

            sources  = [extPath]

            if os.path.exists(extPath.replace('pyx', "pxd")):
                sources.append(extPath.replace("pyx", "pxd"))
            print(sources)
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
print(f'{len(exts)} will be compiled')
# # compile
# with open('requirements.txt', 'r') as f:
#     install_dependencies = [i.strip() for i in f.readlines()]

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
namespaces = find_namespace_packages(include = ["plexsim"],
                                     exclude = ["plexsim.tests*"])

packages = find_packages()

# packages = find_packages(where = "plexsim")
print(packages)
setup(
      package_dir = {"" : "plexsim"},
      package_data       = { "" : '*.pxd *.pyx'.split(),
                             "plexsim" : "*pxd *.pyx".split()
                             },
      ext_modules = cythonize(
                    exts,
                    language_level      = 3,
                    compiler_directives = cdirectives,
                    nthreads            = mp.cpu_count(),
    ),
# gdb_debug =True,
)

