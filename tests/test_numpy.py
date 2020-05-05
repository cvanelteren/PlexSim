import os
#os.environ['OPENBLAS_NUM_THREADS'] = '1'
#os.environ['MKL_NUM_THREADS'] = '1'

import numpy as np
import time
ranges = [10, 100, 1000 ]
def test_init():
    print("Testing init")
    nTrials = 3 
    for i in ranges:
        start = time.time()
        for trial in range(nTrials):
            a = np.random.rand(i, i)
        
        print(f"size {i} ", (time.time() - start) / nTrials)

def test_dot():
    print("Testing dot matrix")
    nTrials = 3
    for i in ranges:
        a = np.random.randn(i, i)
        b = np.random.randn(i, i)
        c = np.random.randn(i, i)
        start = time.time()
        for trial in range(nTrials):
            a.dot(b, out = c)
        print(f"size {i} ",  1000 * (time.time() - start) / nTrials)
    


if __name__ == "__main__":
    print("Testing numpy")
    test_dot()

    


