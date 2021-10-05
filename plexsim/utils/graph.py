import networkx as nx
import numpy as np

__author__ = "Casper van Elteren"
__email__ = "caspervanelteren@gmail.com"

# nx.draw(gc, pos = nx.circular_layout(gc, scale = 1e-5),)
def nx_layout(graph, layout=None, **kwargs):
    from datashader.bundling import hammer_bundle
    import pandas as pd

    if not layout:
        layout = nx.circular_layout(graph)
    data = [[node] + layout[node].tolist() for node in graph.nodes]

    nodes = pd.DataFrame(data, columns=["id", "x", "y"])
    nodes.set_index("id", inplace=True)

    edges = pd.DataFrame(list(graph.edges), columns=["source", "target"])
    return nodes, edges, hammer_bundle(nodes, edges, **kwargs)


def bfs_iso(graph, discovered, tree=nx.DiGraph()):
    """
    Breadth first search isomorphism algorithm.
    Constructs a directed tree-like graph from a node outwards
    """
    d = {}
    for source, pred in discovered.items():
        for neighbor in graph.neighbors(source):
            # don't consider where you came from
            if neighbor not in pred:
                tree.add_edge(source, neighbor)
                # don't go to already discovered nodes
                if neighbor not in discovered.keys():
                    d[neighbor] = d.get(neighbor, []) + [source]

    if d:
        bfs_iso(graph, d, tree)
    # print(discovered, d)
    return tree


def construct_iso_tree(nodes, graph):
    return [bfs_iso(graph, {i: [None]}, nx.DiGraph()) for i in nodes]


def make_connected(g) -> nx.Graph:
    # obtain largest set
    largest = max(nx.connected_components(g), key=lambda x: len(x))
    while len(largest) != len(g):
        for c in nx.connected_components(g):
            for ci in c:
                if ci not in largest:
                    # maintain the degree but add a random edge
                    for neighbor in list(g.neighbors(ci)):
                        target = np.random.choice(list(largest))
                        g.remove_edge(ci, neighbor)
                        g.add_edge(target, ci)
                        largest.add(ci)
                    # check in case neighbor has no degree
                    if ci not in largest:
                        g.add_edge(ci, np.random.choice(list(largest)))
    return g


def powerlaw_graph(n, gamma=1, connected=False, base=nx.Graph):
    deg = np.arange(1, n) ** -float(gamma)
    deg = np.asarray(deg * n, dtype=int)
    deg[deg == 0] = 1
    if deg.sum() % 2:
        deg[np.random.randint(deg.size)] += 1
    g = nx.configuration_model(deg, base())
    if connected:
        g = make_connected(g)
    return g


def recursive_tree(r, jump=0):
    g = nx.Graph()
    g.add_node(0)
    sources = [0]
    n = len(g)
    while r > 0:
        newsources = []
        for source in sources:
            for ri in range(r):
                n += 1
                g.add_edge(source, n)
                newsources.append(n)
        #         print(newsources)
        r -= 2 + jump
        sources = newsources
    return g


import random


class ConnectedSimpleGraphs:
    """
    Simple class that can generate connected graphs up to size n
    """

    def __init__(self):
        """ "
        Class to hold connected graphs of size n
        """
        self.graphs = {2: [nx.path_graph(2)]}
        self.gm = nx.algorithms.isomorphism.GraphMatcher

    def generate(self, n):
        self.graphs = dict(sorted(self.graphs.items(), key=lambda x: x[0]))
        # get largest key already computed
        start = list(self.graphs.keys())[-1]
        while start < n:
            for base in self.graphs.get(start, []):
                # TODO add check for each key if all graphs are found
                for k in range(1, start + 1):
                    graph = self.__call__(base, k)
            start += 1
        return self.graphs

    def flat_generate(self, n):
        """
        Flattens the dictionary from generate
        """
        return [j for i in self.generate(n).values() for j in i]

    def __call__(self, base, k: int):
        import itertools

        # generate new connected graph
        n = len(base) + 1
        for nodes in itertools.permutations(list(base.nodes()), k):
            proposal = base.copy()
            add = True
            for node in nodes:
                proposal.add_edge(node, n)

            for gprime in self.graphs.get(n, []):
                if self.gm(gprime, proposal).is_isomorphic():
                    add = False
                    break
            if add:
                self.graphs[n] = self.graphs.get(n, []) + [proposal]
        return proposal

    def rvs(self, n, sparseness=None):
        """
        Generate random connected graph of size n
        """
        if not sparseness:
            sparseness = lambda: random.uniform(0, 1)
        # start from the same base
        proposal = self.graphs[2][0].copy()
        for ni in range(2, n):
            k = int(sparseness() * n)
            k = max((k, 1))
            for node in random.choices(list(proposal.nodes()), k=k):
                proposal.add_edge(ni, node)
        return proposal


def gini(x: np.ndarray):
    """
    Compute Gini coefficient of degree distribution
    """
    x.sort()
    tmp = np.arange(1, x.size + 1)
    n = x.size
    return ((2 * tmp - n - 1) * x).sum() / (n * x.sum())


def connected_random(
    g: nx.Graph, p: callable, k: int = 10000, pos: dict = None
) -> nx.Graph:
    """modified from Gray et al. (2019)
    Use MCMC method to sample from p(G | G = connected).

    Takes  any graph  as  input and  uses Metroplis  Hasting
    sampling  to reject  graphs that  are not  connected and
    accepts  edges   with  probability  p.   The  generative
    mechanisms utilizes a coordinate  system to decide which
    graphs are connected. For example one can use for p_{ij}
    the  Waxman graph  generator  for accepting  edge i,  j:

        p_{ij}(q, s,  d) =  q * exp(-s * d)

    where $q$  is the
    acceptance probability, $s$ a scaling factor and $d$ the
    (euclidean) distance for edge (i, j)

    """
    if pos is None:
        pos = nx.random_layout(g)
    pos = nx.rescale_layout_dict(pos, 0.5)

    for ki in range(k):
        i, j = np.random.choice(g.nodes(), size=2)
        if i == j:
            continue
        d = np.sqrt(((pos[i] - pos[j]) ** 2).sum())
        pij = p(d)
        if g.has_edge(i, j):
            g.remove_edge(i, j)
            # check for acceptance
            if nx.is_connected(g):
                alpha = min(1, (1 - pij) / pij)
                if np.random.rand() > alpha:
                    g.add_edge(i, j)
            # restore
            else:
                g.add_edge(i, j)
        else:
            alpha = min(1, pij / (1 - pij))
            # restore
            if np.random.rand() < alpha:
                g.add_edge(i, j)
    return g


def legacy_graph(graph):
    from ast import literal_eval

    mapping = dict()
    rmapping = dict()
    for line in nx.generate_multiline_adjlist(graph, ","):
        add = False  # tmp for not overwriting doubles
        # input validation
        lineData = []
        # if second is not dict then it must be source
        for prop in line.split(","):
            try:
                i = literal_eval(prop)  # throws error if only string
                lineData.append(i)
            except:
                lineData.append(prop)  # for strings
        node, info = lineData
        # check properties, assign defaults
        # if 'state' not in graph.node[node]:
        #     idx = np.random.choice(agentStates)
        #     # print(idx, agentStates)
        #     graph.node[node]['state'] = idx
        # if 'nudge' not in graph.node[node]:
        #     graph.node[node]['nudge'] =  DEFAULTNUDGE

        # if not dict then it is a source
        if isinstance(info, dict) is False:
            # add node to seen
            if node not in mapping:
                # append to stack
                counter = len(mapping)
                mapping[node] = counter
                rmapping[counter] = node
                print(mapping)

            # set source
            source = node
            sourceID = mapping[node]

            # states[sourceID] = <long> graph.node[node]['state']
            # nudges[sourceID] = <double> graph.node[node]['nudge']
        # check neighbors
        else:
            # if 'weight' not in info:
            # graph[source][node]['weight'] = DEFAULTWEIGHT
            if node not in mapping:
                counter = len(mapping)
                mapping[node] = counter
                rmapping[counter] = node

            # # check if it has a reverse edge
            # if graph.has_edge(node, source):
            #     sincID = mapping[node]
            #     # weight = graph[node][source]['weight']
            #     # check if t he node is already in stack
            #     if sourceID in set(adj[sincID]) :
            #         add = True
            #     # not found so we should add
            #     else:
            #         add = True
            # # add source > node
            # sincID = <long> mapping[node]
            # adj[sourceID].neighbors.push_back(<long> mapping[node])
            # adj[sourceID].weights.push_back(<double> graph[source][node]['weight'])
            # add reverse
            # if add:
            # adj[sincID].neighbors.push_back( <long> sourceID)
            # adj[sincID].weights.push_back( <double> graph[node][source]['weight'])
    return mapping, rmapping


def get_neighbors(g, node):
    neighbors = list(g.neighbors(node))
    weights = np.array([g[node][neighbor].get("weight", 1) for neighbor in neighbors])
    weights = weights / weights.sum()
    return neighbors, weights


def jujujajaki(g, t, p1, p2, p3, w0=0.2, delta=0.1):

    results = []
    for ti in range(t):
        node = np.random.choice(g.nodes())
        # cutoff
        if np.random.rand() < p1:
            neighbors = tuple(g.neighbors(node))
            for neighbor in neighbors:
                g.remove_edge(node, neighbor)
        # explore
        if np.random.rand() < p2:
            alpha = True if len(tuple(g.neighbors(node))) != len(g) else False
            while alpha:
                other = np.random.choice(g.nodes())
                if not g.has_edge(node, other):
                    alpha = False
            g.add_edge(node, other, weight=np.random.rand())

        # local search
        if p3 < np.random.rand():
            neighbors, weights = get_neighbors(g, node)

            if neighbors:
                other = np.random.choice(
                    neighbors, 1 if len(neighbors) else 0, p=weights
                )[0]
                neighbors, weights = get_neighbors(g, other)

                if neighbors:
                    other_k = np.random.choice(
                        neighbors, 1 if len(neighbors) else 0, p=weights
                    )[0]
                    if not g.has_edge(node, other_k):
                        g.add_edge(node, other_k, weight=w0)

                    g[node][other_k]["weight"] = (
                        g[node][other_k].get("weight", 0) + delta
                    )
        results.append(g.copy())
    return results


def _extract_roles(queue: list, g: nx.Graph, roles: list, paths: list) -> list:

    if len(paths[-1]) > len(roles[-1]):
        # print("exiting!")
        # print(f"{paths} \t {roles}")
        return roles, paths

    if queue:
        node = queue.pop()
        # print(f"At {node}")
        for neighbor in g.neighbors(node):
            # check if role exists
            role_neighbor = nx.get_node_attributes(g, "role")[neighbor]
            # print(f"Looking at {neighbor}")
            if role_neighbor not in roles[-1] and neighbor not in paths[-1]:
                # move to neighbor add seen role
                # print(f"Adding {neighbor} to queue")
                queue.append(neighbor)
                paths[-1].append(neighbor)
                roles[-1].append(role_neighbor)
                roles, paths = _extract_roles(queue, g, roles, paths)
    return roles, paths


def extract_roles(node: int, g: nx.Graph, roles: list) -> list:
    queue = [node]
    node_role = nx.get_node_attributes(g, "role")[node]
    print(f"Testing {node}")
    return _extract_roles(queue, g, roles=[[node_role]], paths=[[node]])


def erase_path(path: list, target: int) -> list:
    # keep path until target
    new_path = []
    for node in path:
        if node == target:
            return new_path
        else:
            new_path.append(node)
    return new_path


def walk(root: int, g: nx.Graph, visited: set) -> tuple:

    path = [root]
    while len(visited) != len(g):
        tmp = []
        for i in g.neighbors(path[-1]):
            if len(path) == 1:
                tmp.append(i)
            elif i != path[-2]:
                tmp.append(i)
        np.random.shuffle(tmp)
        if tmp:
            neighbor = tmp[0]
        else:
            print("No neighbors left")
            assert 0
            path = [root]
            tmp = list(g.neighbors(path[-1]))
            np.random.shuffle(tmp)
            neighbor = tmp[0]
        # connected to already connected structure
        if neighbor in visited and len(path) > 1:
            print(f"Found path {path}")
            print(path)
            return path, g
        # if connected to something already in path
        # erase path
        elif neighbor in path:
            print(f"Erasing {path} with {neighbor}")
            path = erase_path(path, neighbor)
        # grow path
        else:
            path.append(neighbor)
    return path, g


def Willson(n: int, m: int or None = None) -> nx.Graph():
    if m is None:
        m = n
    g = nx.grid_graph((n, m))
    willson_graph = nx.empty_graph()
    for node in g.nodes():
        willson_graph.add_node(node)
    options = list(g.nodes())
    visited = set()

    root = options.pop()
    states = []
    while len(options):
        visited.add(root)
        # generate random walk
        while len(list(g.neighbors(root))) == 0:
            idx = np.random.randint(0, len(visited))
            root = list(visited)[idx]
        path, g = walk(root, g, visited)
        root = path[-1]
        for (x1, x2) in zip(path[:-1], path[1:]):
            visited.add(x2)
            willson_graph.add_edge(x1, x2)

            for neighbor in list(g.neighbors(x2)):
                if neighbor in visited:
                    g.remove_edge(x2, neighbor)

            try:
                options.remove(x2)
            except:
                pass
        states.append((willson_graph.copy(), path))
    return states


def walkm(root, g, visited):
    path = [root]

    move = {
        0: np.array([0, 1]),
        1: np.array([1, 0]),
        2: np.array([-1, 0]),
        3: np.array([0, -1]),
    }
    while len(visited) != len(g):
        try:
            m = np.random.randint(0, 4)
            direction = move[m]
            neighbor = np.unravel_index(root, g.shape) + direction
            neighbor = np.ravel_multi_index(neighbor, g.shape, mode="wrap")

            # connected to already connected structure
            if neighbor in visited and len(path) > 1:
                print(f"Found path {path}")
                return path, g
            # if connected to something already in path
            # erase path
            if neighbor in path:
                print(f"Erasing {path} since  {neighbor} is in path")
                path = [root]
            # grow path
            else:
                path.append(neighbor)
        except Exception as e:
            print(e, neighbor, direction)
            pass
    return path, g


def Willson_matrix(n: int):
    g = np.zeros((n, n))
    options = list(np.arange(g.size))
    visited = set()
    root = options.pop()
    while len(options):
        print(len(options))
        visited.add(root)
        path, g = walkm(root, g, visited)
        for x1, x2 in zip(path[:-1], path[1:]):
            g.flat[x1] = 1
            g.flat[x2] = 1
            visisted.add(x2)
            try:
                options.remove(x2)
            except Exception as e:
                print(e)
                pass
        root = path[-1]
    return g
