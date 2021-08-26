import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from plexsim.models import ValueNetwork
from plexsim.models import MagneticBoids

# from imi import infcy
warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())

from plexsim.utils.rules import create_rule_full

r = nx.cycle_graph(3)
# r = nx.cycle_graph(3)
# r.add_edge(3, 0)
# r = nx.union(r, r, "r1", "r2")
# r = nx.path_graph(3)
# r = nx.krackhardt_kite_graph()
repulsion = -1
br = r.number_of_edges()
r = create_rule_full(r, self_weight=repulsion, connection_weight_other=repulsion)
S = np.arange(len(r))
n = 30


graph = nx.empty_graph(n)
# m =  ValueNetwork(graph = graph)
# m.simulate(2)
# assert 0
bounds = np.array([0, 30.0])
settings = dict(
    coordinates=np.random.randn(n, 2) * max(bounds),
    velocities=np.random.randn(n, 2),
    graph=graph,
    rules=r,
    bounded_rational=br,
    agentStates=S,
    radius=3,
    boid_radius=1.5,
    t=1,
    max_speed=0.5,
    bounds=bounds,
    exploration=0.1,
    # memorySize=2,
    dt=0.1,
    H=np.ones(n) * np.inf,
    heuristic=1,
)

m = MagneticBoids(**settings)
# m.states = 0
print(m.t)

colors = cmr.pride(np.linspace(0, 1, len(r), 0))
from matplotlib import animation
from matplotlib.collections import LineCollection
from matplotlib import patches

theta = 0.1


def update2(idx):
    # ax.cla()
    ax.relim()
    m.updateState(m.sampleNodes(1)[0])
    print(m.velocities)
    # print()
    ci = m.states.astype(int)
    ci = colors[ci]

    # pos = {idx: ci for idx, ci in enumerate(m.coordinates)}
    adj = {k: v["neighbors"] for k, v in m.adj.adj.items()}
    g = nx.from_dict_of_lists(adj)
    tmp = np.array([[m.coordinates[x], m.coordinates[y]] for x, y in g.edges()])
    # lc.set_offsets(tmp)
    lc.set_paths(tmp)
    scats.set_color(ci)

    boundary = patches.Rectangle(
        (m.bounds[0], m.bounds[0]),
        m.bounds[1] - m.bounds[0],
        m.bounds[1] - m.bounds[0],
        facecolor="none",
        alpha=0.1,
        edgecolor="k",
        lw=5,
        zorder=1,
    )
    # [ax.spines[i].set_visible(True) for i in "left top right bottom".split()]
    # ax.add_patch(boundary)
    scats.set_offsets(m.coordinates)
    scatts_range.set_offsets(m.coordinates)

    # ax.annotate(
    #     f"t = {idx}",
    #     (0, 1),
    #     xycoords="axes fraction",
    #     va="bottom",
    #     ha="left",
    #     zorder=5,
    #     fontsize=30,
    # )
    # ax.set_xlabel("x")
    # ax.set_ylabel("y")
    # nx.draw(g, pos=pos, ax=ax, node_color=ci, edge_color="lightgray", node_size=7)
    # ax.tick_params(left=True, bottom=True, labelleft=True, labelbottom=True)
    # ax.set_xlim(min(bounds) * 1 - theta, max(bounds) * (1 + theta))
    # ax.set_ylim(min(bounds) * 1 - theta, max(bounds) * (1 + theta))
    # ax.axis("equal")
    # ax.axis("off")


# print(m.velocities[0], m.coordinates[0])
# ax.axis("equal")
# ax.set_title(f"T={tidx}")

debug = False
# debug = True

fig, ax = plt.subplots(
    1,
    1,
    facecolor="none",
    constrained_layout=True,
    figsize=(5, 5),
    # gridspec_kw=dict(width_ratios=[1, 0.2]),
)
fig.show()

# ri = [(i, j) for i, j, d in r.edges(data=True) if d["weight"] > 0]
# ri = nx.from_edgelist(ri)
# nx.draw(
#    ri,
#    pos=nx.kamada_kawai_layout(ri),
#    ax=target,
#    node_color=colors[np.arange(0, len(r))],
# )
#
# target.axis("equal")
# target.margins(0.5)
# target.annotate(
#    "Target value network",
#    xy=(0.5, 0.75),
#    xycoords="axes fraction",
#    ha="center",
#    va="bottom",
#    fontsize=32,
# )

theta = 0.05
ci = m.states.astype(int)
ci = colors[ci]
scats = ax.scatter(
    *m.coordinates.T, c=ci, zorder=5, s=np.clip(settings["boid_radius"] * 20, 15, 30)
)
scatts_range = ax.scatter(
    *m.coordinates.T,
    c="none",
    zorder=5,
    s=np.clip(
        settings["radius"] * 40,
        15,
        60,
    ),
    edgecolor="k",
)
tmp = np.array([[m.coordinates[x], m.coordinates[y]] for x, y in m.graph.edges()])
lc = LineCollection(
    tmp,
    color="lightgray",
    zorder=1,
    alpha=0.7,
    # theta1=0.2,
    # theta2=0.1
    # connectionstyle="arc3,rad=0.3"
)
ax.add_collection(lc)
ax.set_xlim(min(bounds) * 1 - theta, max(bounds) * (1 + theta))
ax.set_ylim(min(bounds) * 1 - theta, max(bounds) * (1 + theta))
# ax.axis("equal")
# ax.set_xlabel("x")
# ax.set_ylabel("y")
ax.axis("off")

import pyprind as pr

pb = pr.ProgBar(n)


def prog(fn, n):
    pb.update()


debug = 1
if debug:
    counter = 0
    while True:
        counter += 1

        # if counter == 100:
        #     fig.savefig("./sample.png")

        plt.pause(1e-2)
        update2(counter)
else:
    f = np.linspace(0, 100, 200, 0).astype(int)
    ani = animation.FuncAnimation(
        fig,
        update2,
        frames=f,
    )
    ani.save("./flight_test.webm", fps=30, progress_callback=prog)
    fig.show()
