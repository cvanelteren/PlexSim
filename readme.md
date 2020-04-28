# Com(Plex) (Sim)ulation toolbox

Fast and general toolbox for simulation of complex adaptive systems written in cython.
_N.b._ this is a work in progress

## Dependencies

- python >= 3.8
- cython >=.28
- numpy >= 1.18.1
... see req.txt

# License
PlexSim is released under the GNU-GPLv3 license

Powered by 
![cython](banner/cython_logo.svg)


# Example
![banner_gif](banner/PlexSim_banner.gif)


# notes
Cannot have static pyobjects, this causes a segfault in pybind11. 
Use atexit for cleaning them up.
