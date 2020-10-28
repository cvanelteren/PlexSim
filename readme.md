# Com(Plex) (Sim)ulation toolbox

Fast and general toolbox for simulation of complex adaptive systems written in cython.
_N.b._ this is a work in progress


# Installation
Current versions are developed on `linux`. 
## New environment
`conda env create --file environment.yml`
## Existing environment
`conda env update --file environment.yml`

## Build and run checks

`python setup.py install`

alt: `sh build.sh -tv`

# License
PlexSim is released under the GNU-GPLv3 license

Powered by 
![cython](banner/cython_logo.svg)


# Example
![banner_gif](banner/PlexSim_banner.gif)


# notes
Cannot have static pyobjects, this causes a segfault in pybind11. 
Use atexit for cleaning them up.
