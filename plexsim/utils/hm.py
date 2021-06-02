import pandas as pd, networkx as nx, numpy as np, random


def sample_random_node(g):
    return random.choice(list(g.nodes()))


def gen_rvs_hm(m, k):
    configuration = []
    for idx in range(n):
        mi = np.random.randint(0, m)
        row = dict(graphlet=csg().rvs(mi), id=f"C{idx}", deg=np.random.randint(1, k))
        configuration.append(row)
    df = pd.DataFrame(configuration)
    return df


def construct_hm(patterns, m) -> pd.DataFrame:
    config = []
    for idx, p in enumerate(patterns):
        row = dict(graphlet=p, deg=m, id=f"C{idx}")
        config.append(row)
    return pd.DataFrame(config)


def generate_hm(df):
    g = nx.union_all(list(df.graphlet), rename=list(df.id))
    subsets = {}
    for node in g.nodes():
        subsets[node] = int(node[1])
    nx.set_node_attributes(g, subsets, "subset")

    picked = set
    for idx, row in df.iterrows():
        deg = row.deg
        # deg = np.random.randint(1, row.deg + 1)
        for degi in range(deg):
            source = sample_random_node(row.graphlet)
            # picked.add(idx)
            source = f"{row.id}{source}"
            choices = list(df[df.id != row.id].index)
            other = random.choice(choices)
            # if (idx,) not in picked:
            # picked.add(idx)
            # picked.add(other)
            dfi = df.iloc[other]
            target = sample_random_node(dfi.graphlet)
            target = f"{dfi.id}{target}"
            g.add_edge(source, target)
    return g
