import os
#os.environ['OPENBLAS_NUM_THREADS'] = '1'
#os.environ['MKL_NUM_THREADS'] = '1'

import numpy as np
import time
ranges = [10, 100, 1000, 10_000]
def test_init():
    print("Testing init")
    for i in ranges:
        start = time.time()
        a = np.random.rand(i, i)
        print(f"size {i} ", time.time() - start)

def test_dot():
    print("Testing dot matrix")
    for i in ranges:
        a = np.random.randn(i, i)
        b = np.random.randn(i, i)
        c = np.random.randn(i, i)
        print(c.shape)
        start = time.time()
        a.dot(b, out = c)
        print(f"size {i} ", time.time() - start)
    


if __name__ == "__main__":
    print("Testing numpy")
    test_init()
    test_dot()

    


