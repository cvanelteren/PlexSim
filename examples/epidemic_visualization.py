from plexsim.models import SIRS
import networkx as nx, matplotlib.pyplot as plt
from plexsim.utils.visualization import GraphAnimation

"""
GOAL:
- show SIR model
- familiarize user with model setup

Plexsim has some basic visualization methods. It is generally
advised to write visualization methods for your need. Below
is an example for inspiration.
"""

if __name__ == "__main__":
    # SETUP MODEL
    # define node, nearest neighbor degree, rewire probability
    n, k, p = 500, 5, 0.1
    # define network interaction structure
    # can be any networkx create graph both directed
    # and indirected
    graph = nx.watts_strogatz_graph(n, k, p)
    temperature = 2.25
    # SIRS can be used for SIR, SIRS or SIS dynamics
    # taken from Youssef and Scolio (2011)
    # beta : infection rate
    # mu : recovery rate
    # by default the constructor calls init_random which infects 1 person in the system
    beta = 0.5
    mu = 1e-1
    model = SIRS(graph=graph, beta=beta, mu=mu)

    results = model.simulate(100)
    # simple animation class (not perfect).
    # can be used as a more advanced base for animation

    # ANIMATION
    import cmasher as cmr

    cmap = cmr.guppy  # colormap for visualization
    animator = GraphAnimation(model.graph, results, model.nStates, cmap=cmap)

    fig, ax = plt.subplots()
    ax.set_title("SIR model example", fontsize=30)
    # use any layout that can interface with nx
    # pos is a dictionary labeling node to position
    pos = nx.spring_layout(model.graph)
    animator.setup(
        ax,
        layout=pos,
        node_kwargs=dict(node_size=5),
        edge_kwargs=dict(edge_color="lightgray"),
    )

    # create colorbar for labeling different states
    labels = ax.inset_axes((0.8, 0, 0.2, 0.05))
    norm = plt.cm.colors.Normalize(
        vmin=model.agentStates.min(), vmax=model.agentStates.max()
    )
    mappable = plt.cm.ScalarMappable(norm=norm, cmap=cmap)
    cbar = fig.colorbar(mappable=mappable, cax=labels, orientation="horizontal")
    # add SIR labelling
    cbar.ax.set_xticklabels("S I R".split())
    # start animation infinite loop
    t = 0
    while True:
        animator.animate(t)
        fig.canvas.flush_events()
        fig.canvas.draw()
        plt.pause(1e-3)
        t += 1
        t %= len(results)
    ax.axis("equal")
    fig.show()
    plt.show(block=1)
