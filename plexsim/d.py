
from plexsim.models import *
import example
import networkx as nx

import dis
def main():

    g = nx.path_graph(3)
    # m = Potts(g)
    p = example.PD(g)
    dis.dis(p.simulate(10))
