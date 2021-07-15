from plexsim.models.types cimport *

cdef class Nudges:
    """"
    Defines nudges interface
    """
    cdef public:
        void _apply_on(self, node_id_t node, double value)
        void _remove_from(self, node_id_t node)
        void _get_nudges(self)


    cdef private:
        Nudges nudges
