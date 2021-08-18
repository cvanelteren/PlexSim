import unittest as ut
import subprocess, numpy as np

from plexsim.utils.graph import ConnectedSimpleGraphs
from plexsim.utils.rules import create_rule_full
from plexsim.models.value_network import ValueNetwork

# from plexsim.models.value_network2 import ValueNetwork as V2

import matplotlib.pyplot as plt, networkx as nx
from plexsim.utils.visualisation import GraphAnimation, visualize_graph


import time, logging

# Set log level


class TestCrawl(ut.TestCase):
    model = ValueNetwork
    # model = V2

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
            break

    def test_partial_join(self):
        """
        Tests in a square graph with states [0, 0, 1, 2]
        with a rule as a triangle whether a join on partial complete
        paths are ignored. For example if an option A contains options x1 and option B
        also contains option x1, they should not be merged.
        """

        graph = nx.complete_graph(4)
        rule = create_rule_full(nx.cycle_graph(3))
        S = np.arange(len(rule))

        m = self.model(graph, rules=rule, agentStates=S)
        m.states = [0, 0, 1, 2]
        targets = np.ones(m.nNodes) * 3

        # the nodes that have the same states can make
        # two triangles
        # the other can make one more unrolled
        targets[2] = 4
        targets[3] = 4
        self.__test_crawl_single(m, targets=targets, verbose=False)

    def test_y_dual_heuristic(self):
        """Test two path graphs on a y-structure

        Each node should complete atleast 1 value network
        A part of the network should complete 1 more chain

        This is a the heuristic version, all nodes are tested to only satisfy
        only 1 value network.

        """

        n = 3
        graph = nx.path_graph(n)
        graph.add_edge(1, 10)
        # graph.add_edge(11, 11)

        # define state space
        S = np.arange(n)
        # define double y state structure
        SS = np.array([*S, n - 1])

        r = create_rule_full(nx.path_graph(3))
        m = self.model(graph, rules=r, agentStates=S, heuristic=1)
        assert m.heuristic == 1
        assert SS.size == m.nNodes, f"{SS.size=} {m.nNodes=}"
        m.states = SS

        targets = np.ones(m.nNodes)
        targets[m.adj.mapping["1"]] = 1
        targets[m.adj.mapping["0"]] = 1

        # visualize_graph(m)
        # plt.show()
        self.__test_crawl_single(m, targets=targets, verbose=False)

    # @ut.skip
    def test_y_dual(self):
        """
        Test two path graphs on a y-structure

        Each node should complete atleast 1 value network
        A part of the network should complete 1 more chain
        """

        n = 3
        graph = nx.path_graph(n)
        graph.add_edge(1, 10)
        # graph.add_edge(11, 11)

        # define state space
        S = np.arange(n)
        # define double y state structure
        SS = np.array([*S, n - 1])

        r = create_rule_full(nx.path_graph(3))
        m = self.model(graph, rules=r, agentStates=S)
        assert SS.size == m.nNodes, f"{SS.size=} {m.nNodes=}"
        m.states = SS

        targets = np.ones(m.nNodes)
        targets[m.adj.mapping["1"]] = 2
        targets[m.adj.mapping["0"]] = 2

        visualize_graph(m)
        plt.show()
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
        self.__test_crawl_single(m, targets=targets, verbose=False)

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
            plt.show(block=True)

        crawls = []
        for node_label, node in m.adj.mapping.items():
            crawl = m.check_df(node, verbose=verbose)
            if verbose:
                print(crawl)
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
                f"assignment was {assignment} with {crawl}\n{node=}\t{len(crawl)=}\t{targets[node]=}",
            )

            crawls.append(assignment)

        if verbose:
            plt.show()


import cmasher as cmr


if __name__ == "__main__":
    ut.main()
