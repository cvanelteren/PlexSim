import unittest as ut
import networkx as nx
from plexsim.utils.graph import extract_roles


class TestExtraction(ut.TestCase):
    def test_matching_rule_and_graph(self):
        """
        Testing this graph (state assigned)
           0
           |
           1
           |
           2
           |
           3

        Should return (node -> len results):
        0 -> 1
        1 -> 1
        2 -> 1
        """
        g = nx.path_graph(3)
        roles = [0, 1, 2]
        assign = {node: role for node, role in zip(g.nodes(), roles)}
        nx.set_node_attributes(g, assign, "role")

        targets = {node: 1 for node in g.nodes()}
        for node, target in targets.items():
            extracted_roles, paths = extract_roles(node, g, roles)
            print(extracted_roles, paths)
            self.assertEqual(len(extracted_roles), target)

    def test_multiple_roles_matching_graph(self):
        """
        Tests classic y-structure with 4 node graph with a split at node 1.
        Visually:
            0
            |
            1
           / \
          2   3

        Note this adds roles with "odd number of states". Shouldn't be any different in python
        than the similar test below.
        Should return (node -> len results):
        0 -> 1
        1 -> 1
        2 -> 1
        3 -> 1
        """
        g = nx.path_graph(3)
        g.add_edge(1, 3)
        roles = [("role1", 1), 1, 2, 3]
        assign = {node: role for node, role in zip(g.nodes(), roles)}
        nx.set_node_attributes(g, assign, "role")

        targets = {node: 1 for node in g.nodes()}
        for node, target in targets.items():
            extracted_roles, paths = extract_roles(node, g, roles)
            print(extracted_roles, paths)
            self.assertEqual(len(extracted_roles), target)

    def test_y_split_three_state(self):
        """
        Same as above but the states are as such:
            0
            |
            2
           / \
          2   1

        Should return (node -> len results):
        0 -> 1
        1 -> 1
        2 -> 0
        3 -> 1
        """

        g = nx.path_graph(3)
        g.add_edge(1, 3)
        roles = [0, 2, 2, 1]
        assign = {node: role for node, role in zip(g.nodes(), roles)}
        nx.set_node_attributes(g, assign, "role")

        targets = {node: 1 for node in g.nodes()}
        for node, target in targets.items():
            extracted_roles, paths = extract_roles(node, g, roles)
            print(extracted_roles, paths)
            self.assertEqual(len(extracted_roles), target)


if __name__ == "__main__":
    ut.main()
