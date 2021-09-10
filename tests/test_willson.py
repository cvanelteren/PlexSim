import networkx as nx, numpy as np
from matplotlib import pyplot as plt
from matplotlib.collections import LineCollection

# fig, ax = plt.subplots()
# ax.imshow(g)
# fig.show()
# plt.show(block=1)


def erase_path(path: list, target: int) -> list:
    # keep path until target
    new_path = []
    for node in path:
        if node == target:
            return new_path
        else:
            new_path.append(node)
    return new_path


def walk(root: int, g: nx.Graph, visited: set, animator=None) -> tuple:
    """
    Random walk without back tracking
    """
    path = [root]
    while len(visited) != len(g):
        tmp = []
        for i in g.neighbors(path[-1]):
            if len(path) == 1:
                tmp.append(i)
            elif i != path[-2]:
                tmp.append(i)
            # else:
            # tmp.append(i)
        np.random.shuffle(tmp)
        if tmp:
            neighbor = tmp[0]
        # should never hit this
        else:
            print("No neighbors left")
            assert 0
            path = [root]
            tmp = list(g.neighbors(path[-1]))
            np.random.shuffle(tmp)
            neighbor = tmp[0]
        # connected to already connected structure
        if neighbor in visited and len(path) > 1:
            # print(f"Found path {path}")
            # print(path)
            if animator:
                animator.update(path)
            return path, g
        # if connected to something already in path
        # erase path
        elif neighbor in path:
            # print(f"Erasing {path} with {neighbor}")
            path = erase_path(path, neighbor)
        # grow path
        else:
            path.append(neighbor)

        if animator:
            animator.update(path, color="red")
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
        # generate random walk
        while len(list(g.neighbors(root))) == 0:
            idx = np.random.randint(0, len(visited))
            root = list(visited)[idx]
        print(f"Options left = {len(options)}", end="\r")
        visited.add(root)
        path, g = walk(root, g, visited)
        root = path[-1]
        for (x1, x2) in zip(path[:-1], path[1:]):
            visited.add(x2)
            willson_graph.add_edge(x1, x2)

            for neighbor in list(g.neighbors(x2)):
                if neighbor in visited:
                    g.remove_edge(x2, neighbor)
                    # print(f"Removing {x2} {neighbor}")
            try:
                options.remove(x2)
            except:
                pass
        states.append((willson_graph.copy(), path))
    return states


def get_offsets(g: nx.Graph, pos):
    lc = []
    for edge in g.edges():
        connection = []
        for e in edge:
            connection.append(pos[e])
        lc.append(connection)
    return np.array(lc)


def add_offset(path: list, pos: dict):
    offset = np.zeros((len(path) - 1, 2, 2))
    for idx, (start, end) in enumerate(zip(path[:-1], path[1:])):
        offset[idx, 0] = pos[start]
        offset[idx, 1] = pos[end]
        # offset[idx, 1] = pos[end]
    return offset


class Animator:
    def __init__(self, graph):
        self.graph = graph

        fig, ax = plt.subplots()
        fig.set_facecolor("black")
        ax.set_facecolor("#1c1e26")
        self.fig = fig

        norm = plt.cm.colors.Normalize(vmin=0, vmax=1)
        self.lines = LineCollection([], cmap="cmr.wildfire", zorder=1, norm=norm)
        ax.add_collection(self.lines)

        pos = {idx: np.array(idx) for idx in graphs[0][0].nodes()}
        nx.draw_networkx_nodes(graphs[0][0], pos=pos, ax=ax, node_size=0)

    def draw(self) -> None:
        self.fig.canvas.flush_events()
        self.fig.canvas.draw()

    def update(self, path, color=None):
        offsets = self.lines.get_offsets()
        sizes = self.lines.get_array()
        new_offsets = add_offset(path, self.pos)
        for kidx, offset in new_offsets:
            length = (kdx + 1) / len(new_offsets)
            offsets = np.append(offsets, offset, axis=0)
            sizes = np.append(sizes, length, axis=0)
        self.lines.set_path(offsets)
        self.lines.set_array(sizes)
        self.draw()


graphs = Willson(50, 50)

pos = {idx: np.array(idx) for idx in graphs[0][0].nodes()}

fig, ax = plt.subplots()
nx.draw_networkx_nodes(graphs[0][0], pos=pos, ax=ax, node_size=0, node_color="gray")
fig.set_facecolor("black")
ax.set_facecolor("#1c1e26")


fig.show()
idx = 0
import os, cmasher as cmr

os.makedirs("./figures", exist_ok=True)

bins = np.linspace(0, 1, 20, 0)
cmap = cmr.guppy(bins)
max_path_length = len(max(graphs, key=lambda x: len(x[1]))[1])

norm = plt.cm.colors.Normalize(vmin=0, vmax=1)
offsets = []
sizes = []
lc = LineCollection(offsets, cmap="cmr.savanna", zorder=1, norm=norm)

lines = ax.add_artist(lc)
for idx in range(len(graphs)):
    g, path = graphs[idx % len(graphs)]
    offset = add_offset(path, pos)

    # if len(offset) < 3:
    # print(offset)

    for kdx, i in enumerate(offset):
        offsets.append(i)
        # length = (kdx + 1) / len(offset)
        length = (kdx + 1) / max_path_length
        sizes.append(length)

    lines.set_paths(offsets)
    lines.set_array(np.array(sizes))

    fig.canvas.draw()
    fig.canvas.flush_events()
    # plt.pause(1e-1)

plt.show(block=1)
