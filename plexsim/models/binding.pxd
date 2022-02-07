cdef extern from "cpp_binding.hpp":
    ctypedef struct x_t:
        int x
    ctypedef struct y_t:
        x_t a

    void f(y_t x)


    # cppclass test_nested:
    #     ctypedef struct nested_struct:
    #         test_struct a
    #     test_nested(nested_struct &x)
