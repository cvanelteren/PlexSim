import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from matplotlib.collections import LineCollection

# from plexsim import models

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())


from plexsim.models.value_network_soc import VNSoc

# from plexsim.utils.visualisation import visualize_graph
from plexsim.utils.rules import create_rule_full


def get_graph(g: dict) -> nx.Graph or nx.DiGraph:
    output = dict()
    for k, v in g.items():
        output[k] = dict()
        for kk, vv in v["neighbors"].items():
            output[k][kk] = dict(weight=vv)
    return nx.from_dict_of_dicts(output)


def get_paths(g: nx.Graph) -> np.ndarray:
    global pos
    tmp = []
    for x, y in g.edges():
        tmp.append((pos[x], pos[y]))
    tmp = np.array(tmp)
    return tmp


def update(idx: int) -> list:
    global colors, lc, pb
    ax.relim()

    m.updateState(m.sampleNodes(1)[0])

    print(m.completed_vns)

    # ci = m.states.astype(int)
    # ci = colors[ci]
    # scats.set_color(ci)

    g = get_graph(m.adj.adj)
    paths = get_paths(g)
    lc.set_paths(paths)
    ax.set_title(idx)
    pb.update()
    return [lc, scats]


def visualize_graph(m):
    import cmasher as cmr

    cmap = cmr.guppy(np.linspace(0, 1, m.nStates, 0))
    colors = [cmap[int(i)] for i in m.states.astype(int)]
    g = get_graph(m.adj.adj)

    fig, ax = plt.subplots()
    nx.draw(g, ax=ax, with_labels=1, node_color=colors)
    fig.show()


from matplotlib import animation
import pyprind as pr

if __name__ == "__main__":
    graph = nx.path_graph(30)
    rules = create_rule_full(nx.cycle_graph(3))

    s = np.arange(len(rules))
    print(s)

    settings = dict(
        graph=graph,
        rules=rules,
        agentStates=s,
        heuristic=1,
    )
    m = VNSoc(**settings)

    m.states = [*np.ones(10) * 0, *np.ones(10) * 1, *np.ones(10) * 2]

    g = get_graph(m.adj.adj)
    pos = nx.circular_layout(g)
    p = np.array([i for i in pos.values()])

    cmap = cmr.guppy(np.linspace(0, 1, m.nStates, 0))
    colors = np.array([cmap[i] for i in m.states.astype(int)])

    n = 100
    f = np.linspace(0, n, n, dtype=int)
    pb = pr.ProgBar(f.size)
    fig, ax = plt.subplots()

    nx.draw_networkx_labels(g, pos, ax=ax)
    scats = ax.scatter(p[:, 0], p[:, 1], c=colors, s=300)
    # plt.show(block=1)

    paths = get_paths(g)
    lc = LineCollection(paths, color="lightgray")
    ax.add_collection(lc)
    # ax.axis("equal")

    ax.axis("off")

    ani = animation.FuncAnimation(fig, update, frames=f)
    ani.save("./soc.mp4", fps=30)
    fig.show()
