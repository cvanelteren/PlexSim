import unittest as ut
import subprocess, numpy as np

from plexsim.utils.graph import ConnectedSimpleGraphs
from plexsim.utils.rules import create_rule_full
from plexsim.models.value_network import ValueNetwork

import matplotlib.pyplot as plt, networkx as nx
from plexsim.utils.visualisation import GraphAnimation

import time, logging

# Set log level


class TestCrawl(ut.TestCase):
    model = ValueNetwork

    def setUp(self):
        self.graphs = []
        for k, v in ConnectedSimpleGraphs().generate(4).items():
            [self.graphs.append(vi) for vi in v]
        self.verbose = False

    # @ut.skip
    def test_true_positive(self):
        """
        Situation in which the social network matches the social network
        """
        for graph in self.graphs:
            r = create_rule_full(graph, self_weight=-1)
            S = np.arange(len(r))
            m = self.model(graph, rules=r, agentStates=S)

            # set state -> social network matches the value network
            for node in range(m.nNodes):
                m.states[node] = node

            targets = np.ones(m.nNodes)
            self.__test_crawl_single(m, targets=targets, verbose=self.verbose)

    # @ut.skip
    def test_true_negative(self):
        """
        Test that no value networks are formed in a state space
        without any value networks
        """
        for graph in self.graphs:
            r = create_rule_full(graph, self_weight=-1)
            S = np.arange(len(r))
            m = self.model(graph, rules=r, agentStates=S)

            # set state -> social network matches the value network
            m.states = S[0]
            targets = np.zeros(m.nNodes)
            self.__test_crawl_single(m, targets=targets, verbose=self.verbose)

    # @ut.skip
    def test_y_dual(self):
        """
        Test two path graphs on a y-structure

        Each node should complete atleast 1 value network
        A part of the network should complete 1 more chain
        """

        graph = nx.path_graph(3)
        graph.add_edge(1, 3)

        # define state space
        S = np.arange(3)
        # define double y state structure
        SS = np.array([*S, 2])

        r = create_rule_full(nx.path_graph(3))
        m = self.model(graph, rules=r, agentStates=S)
        assert SS.size == m.nNodes, f"{SS.size=} {m.nNodes=}"
        m.states = SS

        targets = np.ones(m.nNodes)
        targets[m.adj.mapping["1"]] = 2
        targets[m.adj.mapping["0"]] = 2

        visualize_graph(m)
        self.__test_crawl_single(m, targets=targets, verbose=False)

    def test_unrolled(self):
        """
        Test unrolled cycled graph
        Should find 1 value network for all nodes
        """
        graph = nx.path_graph(4)
        S = np.arange(3)
        SS = np.array([*S, 0])
        r = create_rule_full(nx.cycle_graph(3))

        m = self.model(graph, rules=r, agentStates=S)
        m.states = SS
        targets = np.ones(m.nNodes)
        visualize_graph(m)
        plt.show()
        self.__test_crawl_single(m, targets=targets, verbose=True)

    def __test_crawl_single(self, m: ValueNetwork, targets: list, verbose=False):
        """
        Tests the value network for a given @targets
        """

        if verbose:
            print("-" * 32)
            print(f"Testing graph of size {len(m.graph)}")
            print("-" * 32)

        if verbose:
            visualize_graph(m)
            # plt.show(block=True)

        crawls = []
        for node_label, node in m.adj.mapping.items():
            crawl = m.check_df(node, verbose=verbose)
            # crawl = m.check_df(node)

            if verbose:
                print(f"solution: {crawl} {len(crawl)}")
            assignment = len(crawl) == targets[node]
            if verbose:
                print(f"Results ok? {assignment} for node {node}")
                print(f"{m.adj.mapping=}")
            # print(m.states)

            self.assertTrue(
                assignment,
                f"assignment was {assignment} with {crawl}",
            )

            crawls.append(assignment)

        if verbose:
            plt.show()


import cmasher as cmr


def visualize_graph(m: ValueNetwork):
    cmap = cmr.guppy(np.linspace(0, 1, m.nStates, 0))
    fig, ax = plt.subplots()
    colors = [cmap[int(i)] for i in m.states.astype(int)]
    nx.draw(m.graph, ax=ax, node_color=colors, with_labels=1)
    fig.show()


if __name__ == "__main__":
    ut.main()
