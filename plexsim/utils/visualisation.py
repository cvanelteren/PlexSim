import networkx as nx, matplotlib.pyplot as plt, numpy as np


def discrete_cmap(N, base_cmap=None):
    """Create an N-bin discrete colormap from the specified input map"""

    # Note that if base_cmap is a string or None, you can simply do
    #    return plt.cm.get_cmap(base_cmap, N)
    # The following works for string, None, or a colormap instance:

    base = plt.cm.get_cmap(base_cmap)
    color_list = base(np.linspace(0, 1, N, 0))
    cmap_name = base.name + str(N)
    return plt.cm.colors.ListedColormap(color_list, color_list, N)


def turnoff_spines(ax):
    for i in "top left bottom right".split():
        ax.spines[i].set_visible(False)


class GraphAnimation:
    def __init__(self, graph, time_data, n=1):
        self.graph = graph
        self.time_data = time_data
        try:
            import cmasher as cmr

            self.colors = discrete_cmap(n, "cmr.pride")
        except:
            self.colors = discrete_cmap(n, "tab20c")

        if len(time_data.shape) == 3:
            self.colors = None

    def setup(
        self,
        ax=None,
        layout=None,
        rules=None,
        node_kwargs=dict(),
        edge_kwargs=dict(),
        labels=dict(),
    ):
        # check if axes is given
        if ax is None:
            fig, ax = plt.subplots()

        # check for layout
        if layout is None:
            layout = nx.circular_layout

        # set layout
        if hasattr(layout, "__call__"):
            pos = layout(self.graph)
        elif isinstance(layout, dict):
            pos = layout

        # allow for special case of colors in 3rd dimension
        # get colors
        if self.colors is None:
            C = self.time_data[0]
        else:
            C = self.colors(self.time_data[0].astype(int))

        # animation object
        self._h = nx.draw_networkx_nodes(
            self.graph, pos, node_color=C, ax=ax, **node_kwargs
        )
        nx.draw_networkx_labels(self.graph, pos, ax=ax, **labels)

        nx.draw_networkx_edges(self.graph, pos, ax=ax, **edge_kwargs)
        # add rule graph
        if rules is not None:
            inx = ax.inset_axes((1, 0.25, 0.5, 0.5))
            self.add_rule_graph(rules, inx, self.colors)

            # inx = ax.inset_axes((1, .5, .5, .5))
            # self.add_rule_igraph(rules, inx, self.colors)
        # add time indicator
        self.text = ax.annotate(
            "", (0, 1), va="bottom", ha="left", xycoords="axes fraction", fontsize=27
        )
        turnoff_spines(ax)
        ax.grid(False)

    @staticmethod
    def add_rule_graph(rules, ax, cmap):
        # add value network
        pos = nx.circular_layout(rules)
        C = cmap(np.linspace(0, 1, len(rules), endpoint=0))
        nx.draw_networkx_nodes(rules, ax=ax, pos=pos, node_color=C)
        for x in [(np.greater, "solid"), (np.less, "dashed")]:
            operator, ls = x
            e = [
                (i, j)
                for i, j, d in rules.edges(data=True)
                if operator(dict(d).get("weight", 1), 0)
            ]
            nx.draw_networkx_edges(rules, ax=ax, edgelist=e, style=ls, pos=pos)

        turnoff_spines(ax)
        ax.margins(0.3)
        ax.axis("equal")
        ax.grid(False)
        return ax

    def add_rule_igraph(self, rules, ax, cmap):
        C = cmap(np.linspace(0, 1, len(rules), endpoint=0))
        A = nx.adjacency_matrix(rules).todense()
        import igraph as ig

        g = ig.Graph.Adjacency(A.tolist())
        ig.plot(g, target=ax, layout="auto", vertex_size=20, vertex_color=C)
        ax.axis("off")
        # ax.margins(.5)

    def animate(self, idx):
        c = self.time_data[idx].astype(int)
        if not self.colors is None:
            c = [self.colors(i) for i in c]
        self._h.set_color(c)
        self.text.set_text(f"T={idx}")
        return self._h.axes.collections

    def gen_panel(self, n_panels=3, **kwargs):
        time_idx = np.linspace(0, self.time_data.size, n_panels, 0).astype(int)
        fig, ax = plt.subplots(1, n_panels, constrained_layout=1)
        for axi, idx in zip(ax, time_idx):
            self.setup(axi, **kwargs)
            axi.set_title(f"T = {idx}")
        fig.show()
        return fig


def simple_animate(graph, time_data, n, file="test.mp4"):
    """
    I use this too often --> simple wrapper
    """
    from matplotlib import animation

    ga = GraphAnimation(graph, time_data, n)
    pos = nx.kamada_kawai_layout(graph)
    fig, ax = plt.subplots()
    ga.setup(ax, layout=pos, rules=tmp.rule)
    f = np.linspace(0, len(time_data), 10, 0).astype(int)
    ani = animation.FuncAnimation(fig, ga.animate, frames=f)
    ani.save(file)
    fig.show()


def create_grid_layout(g):
    pos = {i: np.array(i) for i in g.nodes()}
    return pos
