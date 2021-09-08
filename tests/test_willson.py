import networkx as nx
from plexsim.utils.graph import *
from matplotlib import pyplot as plt
from matplotlib.collections import LineCollection

# fig, ax = plt.subplots()
# ax.imshow(g)
# fig.show()
# plt.show(block=1)


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


graphs = Willson(20, 20)
fig, ax = plt.subplots()

pos = {idx: np.array(idx) for idx in graphs[0][0].nodes()}
nx.draw_networkx_nodes(graphs[0][0], pos=pos, ax=ax, node_size=12)


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
lc = LineCollection(offsets, cmap="cmr.pride", zorder=1, norm=norm)

lines = ax.add_artist(lc)
for idx in range(len(graphs)):
    g, path = graphs[idx % len(graphs)]
    offset = add_offset(path, pos)
    print(offset.shape)
    for kdx, i in enumerate(offset):
        offsets.append(i)
        length = (kdx + 1) / len(offset)
        sizes.append(length)

    lines.set_paths(offsets)
    lines.set_array(np.array(sizes))

    fig.canvas.draw()
    fig.canvas.flush_events()

plt.show(block=1)
