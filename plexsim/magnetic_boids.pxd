# distutils: language=c++
from plexsim.types cimport *
from plexsim.models cimport *
from plexsim.value_network cimport *
cdef class MagneticBoids(ValueNetwork):
    cdef:
        double[:, ::1] _coordinates
        double[:, ::1] _velocities

        double[::1] _bounds
        double _radius
        double _boid_radius
        double _max_speed
        double _dt

    cdef void _step(self, node_id_t node) nogil
    cdef void _move_boid(self, node_id_t node) nogil
    cdef void _update_adjacency(self, node_id_t node) nogil
    cdef void _check_collision(self, node_id_t node) nogil
    cdef void _check_boundary(self, node_id_t node) nogil
