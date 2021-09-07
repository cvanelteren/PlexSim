from plexsim.models import Potts
import networkx as nx, matplotlib.pyplot as plt, numpy as np
from plexsim.utils.visualization import GraphAnimation

"""
GOAL: shows simulation on arbitrary fixed graph structure

Plexsim has some basic visualization methods. It is generally
advised to write visualization methods for your need. Below
is an example for inspiration
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

    # define q = 5 state Potts model
    agentStates = np.arange(5)
    model = Potts(graph=graph, t=temperature, agentStates=agentStates)

    results = model.simulate(500)
    # simple animation class (not perfect).
    # can be used as a more advanced base for animation
    animator = GraphAnimation(model.graph, results, model.nStates)

    # ANIMTION
    fig, ax = plt.subplots()
    animator.setup(
        ax, node_kwargs=dict(node_size=5), edge_kwargs=dict(edge_color="lightgray")
    )

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
