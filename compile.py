from Cython.Build import cythonize
from Cython.Distutils import build_ext
from setuptools import setup
from setuptools.extension import Extension
import numpy, multiprocessing as mp, os

import re, os
from subprocess import run
add = []
compiler = 'g++'
optFlag = '-O3'
cppv    = '11'

flags = f'{optFlag} -march=native -std=c++{cppv} -flto '\
        '-frename-registers -funroll-loops -fno-wrapv '\
        '-fopenmp-simd -fopenmp -D_GLIBCXX_PARALLEL'
try:
    clangCheck = run(f"{compiler} --version".split(), capture_output= True)
    if not clangCheck.returncode and 'fs4' not in os.uname().nodename:
        print("Using default")
        os.environ['CXXFLAGS'] =  f'{compiler} {flags}'
        os.environ['CC']       =  f'{compiler} {flags}'
        # add.append('-lomp') # c
except Exception as e:
    print(e)
    pass
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
            ex = Extension(extName, \
                           sources            = sources, \
                           include_dirs       = [nums, '.'],\
                           extra_compile_args = flags.split(),\
                           extra_link_args = ['-fopenmp',\
                                              f'-std=c++{cppv}',\
                                              # '-g'\
                                              ] + add,\
            )
            exts.append(ex)
# # compile
# with open('requirements.txt', 'r') as f:
#     install_dependencies = [i.strip() for i in f.readlines()]

cdirectives =  dict(\
                    fast_gil         = True,\
                    boundscheck      = False,\
                    cdivision        = True,\
                    initializedcheck = False,\
                    overflowcheck    = False,\
                    nonecheck        = False,\
                    binding          = True,\
                    # embedsignature = True,\
                    )

#with open('requirements.txt', 'r') as f:
#    requirements = f.read().splitlines()
setup(\
    zip_safe         = False,\
    ext_modules = cythonize(\
                    exts,\
                    # annotate            = True,\ # set to true for performance html
                    language_level      = 3,\
                    compiler_directives = cdirectives,\
                    # source must be pickable
                    nthreads            = mp.cpu_count(),\
    ),\
# gdb_debug =True,
)

