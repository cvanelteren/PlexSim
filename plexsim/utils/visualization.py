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
    def __init__(self, graph: object, time_data: dict, n=1, cmap=None):
        self.graph = graph

        # lazy conversion
        if isinstance(time_data, np.ndarray):
            time_data = {idx: {"states": i} for idx, i in enumerate(time_data)}
        self.time_data = time_data

        # loading colors
        self.colors = None
        if cmap is None:
            try:
                import cmasher as cmr

                self.colors = discrete_cmap(n, "cmr.pride")
            except:
                self.colors = discrete_cmap(n, "tab20c")
        else:
            self.colors = discrete_cmap(n, cmap)

        if len(self.time_data[0]["states"].shape) == 2:
            self.colors = None

    def setup(
        self,
        ax=None,
        layout=None,
        rules=None,
        bounds=None,
        node_kwargs=dict(),
        edge_kwargs=dict(),
        labels=dict(),
        use_timer=True,
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

        # add bounding box
        if bounds is not None:
            self.add_bb(ax, bounds)

        # allow for special case of colors in 3rd dimension
        # get colors
        if self.colors is None:
            C = self.time_data[0]["states"]
        else:
            C = self.colors(self.time_data[0]["states"].astype(int))

        # animation object
        self._nodes = nx.draw_networkx_nodes(
            self.graph, pos, node_color=C, ax=ax, **node_kwargs
        )

        # add node labels
        if labels:
            nx.draw_networkx_labels(self.graph, pos, ax=ax, **labels)

        # draw edges
        self._connections = nx.draw_networkx_edges(
            self.graph, pos, ax=ax, **edge_kwargs
        )
        # add rule graph
        if rules is not None:
            inx = ax.inset_axes((1, 0.25, 0.5, 0.5))
            self.add_rule_graph(rules, inx, self.colors)

        # add time indicator
        if use_timer:
            self.text = ax.annotate(
                "",
                (0, 1),
                va="bottom",
                ha="left",
                xycoords="axes fraction",
                fontsize=27,
            )
        else:
            self.timer = None
        turnoff_spines(ax)
        ax.grid(False)

    def add_bb(self, ax, bounds):
        """add boundings box"""
        from matplotlib import patches

        boundary = patches.Rectangle(
            (bounds[0], bounds[0]),
            bounds[1] - bounds[0],
            bounds[1] - bounds[0],
            facecolor="none",
            alpha=0.1,
            edgecolor="k",
            lw=5,
            zorder=1,
        )
        ax.add_collection(boundary)
        return

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

    def animate(self, idx, edges=False):
        c = self.time_data.get(idx)["states"].astype(int)

        # update colors
        if not self.colors is None:
            c = [self.colors(i) for i in c]
        self._nodes.set_color(c)
        # update time text
        if self.text is not None:
            self.text.set_text(f"T={idx}")

        # update edges
        if edges:
            coordinates = self.time_data[idx].get("coordinates")
            adj = self.time_data[idx].get("adj")
            # recompute adjacency
            paths = np.array(
                [
                    [m.coordinates[x], m.coordinates[y]]
                    for x in adj
                    for y in adj[x].neighbors
                ]
            )

            # recenter the nodes
            self._nodes.set_offsets(coordinates)
            # set paths
            self._connections.set_paths(paths)
            return [self._nodes, self._connections]
        # return axes objects for blittting
        return [self._nodes]

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


def vis_rules(m, ax, **kwargs):
    """
    Visualize value networks
    """
    import cmasher as cmr

    r = m.dump_rules()
    cmap = cmr.guppy(np.linspace(0, 1, m.nStates, 0))
    colors = [cmap[int(i)] for i in r.nodes()]
    nx.draw(r, ax=ax, node_color=colors, **kwargs)


def vis_graph(m, ax, pos=None, **kwargs):
    """
    Visualize value networks
    """
    import cmasher as cmr

    cmap = cmr.guppy(np.linspace(0, 1, m.nStates, 0))
    colors = dict()
    for node in m.graph.nodes():
        idx = m.adj.mapping[node]
        colors[node] = cmap[m.states[idx].astype(int)]

    if pos is None:
        pos = nx.circular_layout(m.graph)
    nx.draw(m.graph, pos=pos, ax=ax, node_color=list(colors.values()), **kwargs)
