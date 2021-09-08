from plexsim.models.base import Model
import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())


class Deriv(Model):
    def __init__(self, **kwargs):
        super(Deriv, self).__init__(**kwargs)

    # step cannot be accessed from python
    # therefore no derived python model can be used
    # to access faster functions
    def _step(self, node):
        self.states[node] = node

    def updateState(self, node):
        print(node)


if __name__ == "__main__":
    settings = dict(graph=nx.empty_graph(10))
    d = Deriv(**settings)
