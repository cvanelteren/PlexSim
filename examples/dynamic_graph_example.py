import matplotlib.pyplot as plt, cmasher as cmr
import numpy as np, os, sys, networkx as nx, warnings
from plexsim.models import MagneticBoids

from plexsim.utils.rules import create_rule_full
from matplotlib import animation
from matplotlib.collections import LineCollection
from matplotlib import patches

# from imi import infcy
warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())


""" GOAL: Show possibilities  of simulationg spatio temporal
models

IMPORTANT:  the goal  of  this  script is  not  to show  the
intricacies  of the  model used,  merely that  the framework
allows   for  non-fixed   graph  structures   with  temporal
dynamics. It is up to the user to provide a model and create
visualization as he/she pleases.

The framework was initially  written for a general framework
for graph-based  dynamics with discrete states.  However, it
has functionality  to be  extended to continuous  states and
continuous space.

Below here  is a  boid model  inspired version  where agents
have a dynamic adjacency structure over time and agents move
in space.

"""


def update(idx):
    # ax.cla()
    ax.relim()
    m.updateState(m.sampleNodes(1)[0])
    # print()
    ci = m.states.astype(int)
    ci = colors[ci]

    pos = {idx: ci for idx, ci in enumerate(m.coordinates)}
    adj = {k: v["neighbors"] for k, v in m.adj.adj.items()}
    g = nx.from_dict_of_lists(adj)
    tmp = np.array([[m.coordinates[x], m.coordinates[y]] for x, y in g.edges()])
    # lc.set_offsets(tmp)
    lc.set_paths(tmp)
    scats.set_color(ci)

    scats.set_offsets(m.coordinates)


if __name__ == "__main__":
    # MODEL SETUP
    r = nx.cycle_graph(3)
    repulsion = -1
    br = r.number_of_edges()
    r = create_rule_full(r, self_weight=repulsion, connection_weight_other=repulsion)
    S = np.arange(len(r))
    n = 100

    graph = nx.empty_graph(n)
    bounds = np.array([0, 30.0])
    settings = dict(
        coordinates=np.random.randn(n, 2) * max(bounds),
        velocities=np.random.randn(n, 2),
        graph=graph,  # for internal representation
        rules=r,  # specific to magnetic boids, see docs
        bounded_rational=br,  # specific to magnetic boids, see docs
        agentStates=S,  # discrete states
        radius=3,  # how far the boids can see
        boid_radius=1.5,  # how big the boids are for collisions
        t=1,  # noise parameter, see docs
        max_speed=0.5,
        bounds=bounds,  # bounding box of space
        exploration=0.1,  # see docs for magnetic boids
        memorySize=0,  # see docs of base.pyx
        dt=0.03,  # simulation delta t
        heuristic=1,  # seee dosc for magnetic boids
    )

    m = MagneticBoids(**settings)
    colors = cmr.pride(np.linspace(0, 1, len(r), 0))

    # ANIMATION
    fig, ax = plt.subplots(
        1,
        1,
        facecolor="none",
        constrained_layout=True,
        figsize=(5, 5),
    )
    fig.show()

    ci = m.states.astype(int)
    ci = colors[ci]
    scats = ax.scatter(
        *m.coordinates.T,
        c=ci,
        zorder=5,
        s=np.clip(settings["boid_radius"] * 20, 15, 30),
    )

    tmp = np.array([[m.coordinates[x], m.coordinates[y]] for x, y in m.graph.edges()])
    lc = LineCollection(
        tmp,
        color="lightgray",
        zorder=1,
        alpha=0.7,
    )
    ax.add_collection(lc)

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
    ax.add_artist(boundary)
    # center image
    theta = 0.0
    ax.set_xlim(min(bounds) * 1 - theta, max(bounds) * (1 + theta))
    ax.set_ylim(min(bounds) * 1 - theta, max(bounds) * (1 + theta))
    fig.supxlabel("x")
    fig.supylabel("y")
    ax.set_title("Dynamic spatio-temporal model")
    ax.axis("off")

    counter = 0
    while True:
        counter += 1
        update(counter)
        fig.canvas.flush_events()
        fig.canvas.draw()
        plt.pause(1e-16)
