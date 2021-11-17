import unittest as ut
import subprocess, numpy as np

from plexsim.utils.graph import ConnectedSimpleGraphs
from plexsim.utils.rules import create_rule_full
from plexsim.models.value_network import ValueNetwork

# from plexsim.models.value_network2 import ValueNetwork as V2

import matplotlib.pyplot as plt, networkx as nx
from plexsim.utils.visualization import GraphAnimation, vis_graph, vis_rules


import time, logging


class TestCrawl(ut.TestCase):
    model = ValueNetwork
    # model = V2

    def setUp(self):
        print(f"Testing {self.model}")
        self.graphs = []
        for k, v in ConnectedSimpleGraphs().generate(5).items():
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

    def test_allow_no_cycle(self):
        """
        Test two connected triangles. The algorithm should never cross the center knot.
        """

        rule = nx.path_graph(5)
        rule.add_edge(2, 0)
        rule.add_edge(2, 4)
        graph = rule.copy()
        rule = create_rule_full(rule)

        s = np.arange(len(rule))
        m = self.model(graph, rules=rule, agentStates=s)

        m.states = [
            0,
            1,
            2,
            3,
            4,
            5,
        ]
        print(m.states)
        fig, ax = plt.subplots()
        # vis_rules(m, ax=ax)
        vis_graph(m, ax=ax, with_labels=1)
        # plt.show(block=1)
        # fig.show()

        targets = np.ones(m.nNodes)
        self.__test_crawl_single(m, targets=targets, verbose=False, test_specific=[2])

    @ut.skip("The recursive join does not work any more for all unrolled graphs.")
    def test_partial_join(self):
        """
        Tests in a square graph with states [0, 0, 1, 2]
        with a rule as a triangle tests whether a join on partial complete
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
        fig, ax = plt.subplots()
        # vis_rules(m, ax=ax)
        # visualize_graph(m, ax=ax, with_labels=1)
        # fig.show()
        # plt.show(block=1)

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
        targets[m.adj.mapping[1]] = 1
        targets[m.adj.mapping[0]] = 1

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
        targets[m.adj.mapping[1]] = 2
        targets[m.adj.mapping[0]] = 2

        # visualize_graph(m)
        # plt.show()
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
        # fig, ax = plt.subplots()
        # visualize_graph(m, ax=ax)
        # plt.show(block=1)
        self.__test_crawl_single(m, targets=targets, verbose=False)

    def __test_crawl_single(
        self,
        m: ValueNetwork,
        targets: list,
        verbose=False,
        test_specific=[],
    ):
        """
        Tests the value network for a given @targets
        """

        if verbose:
            print("-" * 32)
            print(f"Testing graph of size {len(m.graph)}")
            print("-" * 32)

        # if verbose:
        # visualize_graph(m)
        # plt.show(block=True)

        crawls = []
        for node_label, node in m.adj.mapping.items():
            if node in test_specific or test_specific == []:
                crawl = m.check_df(node, verbose=verbose)
                if verbose:
                    print(node_label, node, crawl)
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
            plt.show(block=1)

    def test_double_triangle(self):

        g = nx.cycle_graph(3)
        r = g.copy()
        g.add_edge(0, 4)
        g.add_edge(0, 5)
        g.add_edge(5, 4)

        m = self.model(
            g,
            rules=create_rule_full(r),
            consider_options=1,
            agentStates=np.arange(len(r)),
        )
        m.states = [0, 1, 2, 1, 2]

        print(m.states)
        print(m.check_df(0))
        print(m.check_df(1))

        g = nx.cycle_graph(3)
        r = g.copy()
        g.add_edge(0, 4)
        g.add_edge(1, 4)
        m = self.model(
            g,
            rules=create_rule_full(r),
            consider_options=1,
            agentStates=np.arange(len(r)),
        )

        m.states = [0, 1, 2, 2]
        print(m.states)
        print(m.check_df(0))
        print(m.check_df(1))

    def test_partial_completion(self):
        g = nx.cycle_graph(3)
        m = gen_matching(self.model, g)

        m.consider_options = True

        # should generate 1 but twice
        m.states[2] = 1
        results = m.check_df(0, verbose=1)
        e = 0
        # compute energy over results
        for r in results:
            e += len(r) / m.bounded_rational

        print(e, results, m.bounded_rational)
        if True:
            print("Results")
            print(results)
            print("States")
            print(m.states)
            # print(m.agentStates)
        self.assertEqual(e, 2 / 3)


import cmasher as cmr

from plexsim.models.value_network_gradient import *


def gen_matching(model, graph):
    r = create_rule_full(graph, self_weight=-1)
    S = np.arange(len(r))
    m = model(graph, rules=r, agentStates=S)
    m.states = S.copy()
    return m


# TODO turn TestCrawl into abstract class; repetition of above
class TestGradient(ut.TestCase):
    model = VNG

    def setUp(self):
        print(f"Testing {self.model}")
        self.graphs = []
        for k, v in ConnectedSimpleGraphs().generate(5).items():
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
            m = gen_model(self.model, graph)

            # set state -> social network matches the value network
            m.states = S[0]
            targets = np.zeros(m.nNodes)
            self.__test_crawl_single(m, targets=targets, verbose=self.verbose)
            break

    def test_allow_no_cycle(self):
        """
        Test two connected triangles. The algorithm should never cross the center knot.
        """

        rule = nx.path_graph(5)
        rule.add_edge(2, 0)
        rule.add_edge(2, 4)
        graph = rule.copy()
        rule = create_rule_full(rule)

        s = np.arange(len(rule))
        m = self.model(graph, rules=rule, agentStates=s)

        m.states = [
            0,
            1,
            2,
            3,
            4,
            5,
        ]
        print(m.states)
        fig, ax = plt.subplots()
        # vis_rules(m, ax=ax)
        vis_graph(m, ax=ax, with_labels=1)
        # plt.show(block=1)
        # fig.show()

        targets = np.ones(m.nNodes)
        self.__test_crawl_single(m, targets=targets, verbose=False, test_specific=[2])

    @ut.skip("The recursive join does not work any more for all unrolled graphs.")
    def test_partial_join(self):
        """
        Tests in a square graph with states [0, 0, 1, 2]
        with a rule as a triangle tests whether a join on partial complete
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
        fig, ax = plt.subplots()
        # vis_rules(m, ax=ax)
        # visualize_graph(m, ax=ax, with_labels=1)
        # fig.show()
        # plt.show(block=1)

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
        targets[m.adj.mapping[1]] = 1
        targets[m.adj.mapping[0]] = 1

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
        targets[m.adj.mapping[1]] = 2
        targets[m.adj.mapping[0]] = 2

        # visualize_graph(m)
        # plt.show()
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
        # fig, ax = plt.subplots()
        # visualize_graph(m, ax=ax)
        # plt.show(block=1)
        self.__test_crawl_single(m, targets=targets, verbose=False)

    def test_check_gradient_node(self):
        """
        Single node update gradient method

        Check_gradient node will use the bounded rationality
        to estimate the number of value network it is a member of
        """
        g = nx.path_graph(3)
        m = gen_matching(self.model, g)
        m.bounded_rational = 1
        for node in range(m.nNodes):
            gradient = m.check_gradient_node(node)
            print(f"Checking {node}")
            print(gradient)
            self.assertEqual(gradient, 1)

    def test_gain(self):
        """
        For piecewise linear, an edge should gain 1/k for a random edge
        """

        g = nx.empty_graph(3)
        m = gen_matching(self.model, g)
        g.add_edge(0, 1)
        m_gain = gen_matching(self.model, g)

        s1 = m.siteEnergy(m.states)
        s2 = m_gain.siteEnergy(m.states)

        delta = np.sum(s1) - np.sum(s2)
        self.assertEqual(delta, 1)

        g.add_edge(1, 2)
        m_gain_again = gen_matching(self.model, g)
        s3 = m_gain_again.siteEnergy(m_gain_again.states)
        delta = s3.sum() - s

    def __test_crawl_single(
        self,
        m: ValueNetwork,
        targets: list,
        verbose=False,
        test_specific=[],
    ):
        """
        Tests the value network for a given @targets
        """

        if verbose:
            print("-" * 32)
            print(f"Testing graph of size {len(m.graph)}")
            print("-" * 32)

        crawls = []

        # NOTE: check only boolean if part of value network or not
        output = m.check_gradient(verbose)
        for node_label, node in m.adj.mapping.items():
            if node in test_specific or test_specific == []:

                assignment = False
                if output[node] and targets[node]:
                    assignment = True
                elif not output[node] and not targets[node]:
                    assignment = True

                self.assertTrue(
                    assignment,
                    f"assignment was {assignment} with {output}\n{node=}\t{output[node]}\t{targets[node]=}",
                )
                crawls.append(assignment)


if __name__ == "__main__":
    ut.main()
