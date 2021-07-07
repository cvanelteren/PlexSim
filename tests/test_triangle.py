from plexsim.models import ValueNetwork
import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())
from test_valuenetwork import TestRecursionCrawl

g = nx.cycle_graph(3)
TestRecursionCrawl().test_specific(g)
