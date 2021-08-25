import unittest as ut
from plexsim.models import *
from plexsim.models.base import Model
import subprocess, numpy as np, networkx as nx


from plexsim.models.value_network_soc import *
from plexsim.utils.rules import create_rule_full


class TestSOC(ut.TestCase):
    def test_local_search(self):
        r = create_rule_full(nx.cycle_graph(3))
        g = nx.cycle_graph(3)
        S = np.arange(len(r))
        m = VNSoc(g, r, agentStates=S)
        print("starting")
        node = 0
        neighbor = m.local_search(node)

        neighbors = [m.adj.mapping[i] for i in m.graph.neighbors(m.adj.rmapping[node])]
        # can pick your own
        neighbors.append(node)
        print(neighbor, neighbors)
        self.assertTrue(neighbor in neighbors)

    def test_get_random_neighbor(self):
        r = create_rule_full(nx.cycle_graph(3))
        g = nx.cycle_graph(3)
        S = np.arange(len(r))
        m = VNSoc(g, r, agentStates=S)
        print("starting")

        node = 0
        neighbor = m.get_random_neighbor(node, use_weight=True)

        neighbors = [m.adj.mapping[i] for i in m.graph.neighbors(m.adj.rmapping[node])]
        print(neighbor, neighbors)
        self.assertTrue(neighbor in neighbors)


if __name__ == "__main__":
    ut.main()
