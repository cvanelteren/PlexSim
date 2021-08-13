import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())

from plexsim.models.sandpile import Sandpile

m = Sandpile(sampleSize=1)
m.states = 0

output = np.zeros(m.nNodes)
z = 10
for i in range(z):
    r = m.sampleNodes(1)
    r[0] = 0
    print(r.base)
    m.updateState(r[0])
    output += m.states / z
    print(m.states)

fig, ax = plt.subplots()
h = ax.imshow(output.reshape(10, 10))
fig.colorbar(h)
fig.show()
plt.show(block=True)
