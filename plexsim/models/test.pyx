#distutils:language=c++
cdef class A:
    def __init__(self):
        self.test()
        pass
    cdef void test(self):
        print("in a")
        return
    cdef void test_m(self):
        print("called a class")
cdef class B(A):
    def __init__(self):
        super(B, self).__init__()

    cdef void test(self):
        print("in b")
        return
cdef class C(B):
    def __init__(self):
        super(C, self).__init__()
    cdef void test(self):
        print("in C")
        return

cdef class D(C):
    def __init__(self):
        super(D, self).__init__()
    cdef void test(self):
        print("in D")
        return
a = A()
b = B()
c = C()
print("h")
d = D()
