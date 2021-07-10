from Cython.Build import cythonize
from Cython.Distutils import build_ext
from setuptools import setup
from setuptools.extension import Extension
import numpy, multiprocessing as mp, os

import re, os
from subprocess import run


compiler = "g++-10"
os.environ["CC"] = compiler
os.environ["CXX"] = compiler
add = []
optFlag = "-Ofast"
cppv = "20"
flags = ""

flags = (
    f"{optFlag} -march=native -std=c++{cppv} -flto "
    "-frename-registers -funroll-loops -fno-wrapv "
    "-fopenmp-simd -fopenmp -unused-variable -Wno-unused "
    "-D_GLIBCXX_USE_CXX11_ABI=0 "
)

# collect pyx files
exts = []
baseDir = os.getcwd() + os.path.sep
nums = numpy.get_include()


data_files = []

paths = []
for (root, dirs, files) in os.walk(baseDir):
    for file in files:
        fileName = os.path.join(root, file)
        if file.endswith(".pyx") and not "tests" in root:
            # some cython shenanigans
            extPath = fileName.replace(baseDir, "")  # make relative
            extName = extPath.split(".")[0].replace(
                os.path.sep, "."
            )  # remove extension

            sources = [extPath]

            if os.path.exists(extPath.replace("pyx", "pxd")):
                base, f = os.path.split(fileName)
                base = os.path.basename(base)
                data_files.append((base, [extPath.replace("pyx", "pxd")]))

            paths.append(extPath)

            ex = Extension(
                extName,
                sources=sources,
                include_dirs=[nums, ".", "plexsim/include"],
                libraries=["stdc++"],
                extra_compile_args=flags.split(),
                define_macros=[("NPY_NO_DEPRECATED_API", "NPY_1_7_API_VERSION")],
                extra_link_args=[
                    "-fopenmp",
                    f"-std=c++{cppv}",
                    # '-g'
                ]
                + add,
            )
            exts.append(ex)


# exts = [
#     Extension(
#         "plexsim.models",
#         sources=paths,
#         include_dirs=[nums, "."],
#         libraries=["stdc++"],
#         extra_compile_args=flags.split(),
#         extra_link_args=[
#             "-fopenmp",
#             f"-std=c++{cppv}",
#         ]
#         + add,
#     )
# ]

# print(f"data files {data_files}")
# print(f"{len(exts)} will be compiled")

from Cython.Compiler import Options

Options.fast_fail = True
cdirectives = dict(
    cdivision=True,
    binding=True,
    embedsignature=True,
    boundscheck=False,
    initializedcheck=False,
    overflowcheck=False,
    nonecheck=False,
)
import unittest


def find_pxd(base) -> list:
    """
    package pxd files
    """
    data_files = []
    for root, dirs, files in os.walk(base):
        for file in files:
            if file.split(".")[-1] in "cpp hpp h c pxd".split():
                # base     = os.path.basename(base)
                file = os.path.join(root, file)
                # print(root, file)
                data_files.append([root, [file]])

    return data_files


def TestSuite():
    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover(
        "plexsim/tests", pattern="test_*.py", top_level_dir="plexsim"
    )
    return test_suite


package_data = find_pxd("plexsim")
# with open('requirements.txt', 'r') as f:
#    requirements = f.read().splitlines()
from setuptools import find_namespace_packages, find_packages
from sphinx.setup_command import BuildDoc

name = "plexsim"
version = "2.0"
packages = find_packages(include=["plexsim", "plexsim.*"], exclude=["bk/*", "bk"])

print(packages)

sphinx = dict(
    project=("setup.py", name),
    version=("setup.py", version),
    source_dir=("setup.py", "docs/src"),
    build_dir = ("setup.py", "docs/build"),
)
# future me note: sometimes headers are not included; clean the dist and build folders
# and rebuild
#
setup(
    name=name,
    author="Casper van Elteren",
    author_email="caspervanelteren@gmail.com",
    url="cvanelteren.githubio.io",
    download_url="https://github.com/cvanelteren/PlexSim/archive/refs/tags/v2.5.tar.gz",
    version=version,
    zip_safe=False,
    # package_dir        = {"" : "plexsim"},
    package_data={
        "": "*.pyx *.pxd".split(),
        #  "plexsim" : "plexsim/*pyx plexsim/*pxd".split(),
    },
    include_package_data=True,
    # data_files=data_files,
    data_files=package_data,
    packages=packages,
    install_requires="cython numpy networkx".split(),
    cmdclass=dict(build_sphinx=BuildDoc),
    command_options=dict(build_sphinx=sphinx),
    ext_modules=cythonize(
        exts,
        compiler_directives=cdirectives,
        nthreads=mp.cpu_count(),
    ),
)
