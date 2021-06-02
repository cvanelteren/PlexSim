# distutils: language=c++
from plexsim.models.potts cimport *
cdef class Bornholdt(Potts):
     cdef:
         double _system_mag
         double* _system_mag_ptr
         double _newsystem_mag
         double* _newsystem_mag_ptr

         double _alpha

     cdef void _swap_buffers(self) nogil

     cdef void _step(self, node_id_t node) nogil
     cdef double _get_system_influence(self) nogil
