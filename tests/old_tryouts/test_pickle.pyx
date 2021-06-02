cdef class A:
    def __init__(self):
        pass
    def __reduce__(self):
        return (rebuild, (self.__class__, {}))

def rebuild(cls, kwargs):
    return cls(**kwargs)

import pickle
a = A()
b = pickle.dumps(a)
print(pickle.loads(b))
