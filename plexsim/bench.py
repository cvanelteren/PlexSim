import timeit

def time_each(func_names, sizes):
    setup = f'''
import numpy; import xtensor_basics
arr = numpy.random.randn({sizes})
    '''
    tim = lambda func: min(timeit.Timer(f'{func}(arr)',
                                        setup=setup).repeat(3, 100))
    return [tim(func) for func in func_names]

from functools import partial

sizes = [10 ** i for i in range(7)]
funcs = ['numpy.sum',
         'xtensor_basics.compute_xtensor_immediate',
         'xtensor_basics.compute_xtensor']
sum_timer = partial(time_each, funcs)
times = list(map(sum_timer, sizes))
print(times)
from matplotlib import pyplot as plt 

plt.Figure(figsize=(5, 10))
plt.plot(times)
plt.legend(["numpy", "xtensor_immediate", "xtensor"])
plt.show()
