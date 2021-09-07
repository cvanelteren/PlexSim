from plexsim.models import Ising
import networkx as nx, matplotlib.pyplot as plt

"""
Traditional Ising model example on a 2d lattice
"""
if __name__ == "__main__":
    # SETUP MODEL
    lattice = nx.grid_graph((64, 64))
    temperature = 2.24
    model = Ising(graph=lattice, t=temperature)
    # output will be (time points) x (number of agents)
    results = model.simulate(1000)

    # ANIMATION
    fig, ax = plt.subplots()
    ax.imshow(results.mean(axis=0).reshape(64, 64))
    ax.set_xlabel("spin $\sigma_i$")
    ax.set_ylabel("spin $\sigma_i$")
    fig.set_title("Traditional Ising model")
    fig.show()
    plt.show(block=1)
