import matplotlib.pyplot as plt, cmasher as cmr, pandas as pd
import numpy as np, os, sys, networkx as nx, warnings
from plexsim import models
from imi import infcy

warnings.simplefilter("ignore")
plt.style.use("fivethirtyeight spooky".split())

df = pd.read_pickle("./bench_val.pkl")


def get_cycles(row: pd.Series):
    return sum(nx.triangles(row.m.graph).values()) / 3


def get_edges(row: pd.Series):
    return row.m.graph.number_of_edges()


fig, (axi, axj) = plt.subplots(2, 1)
fig.show()

df["triangles"] = df.apply(get_cycles, axis=1)
df["edges"] = df.apply(get_edges, axis=1)


# vis number of cycles vs run time
for model, dfi in df.groupby("model"):
    axi.scatter(dfi.triangles, dfi.timing.values, label=model, s=8)


mu = df.groupby("triangles model".split()).agg(dict(timing=[np.mean, np.std]))

for model, mui in mu.groupby("model"):
    x, y = mui.timing["mean"].values, mui.timing["std"].values
    xr = mui.index.get_level_values("triangles")
    axi.errorbar(xr, x, y, label=model)

# vis number of edges vs run time
for model, dfi in df.groupby("model"):
    axj.scatter(dfi.edges, dfi.timing.values, label=model, s=8)

mu = df.groupby("edges model".split()).agg(dict(timing=[np.mean, np.std]))
for model, mui in mu.groupby("model"):
    x, y = mui.timing["mean"].values, mui.timing["std"].values
    xr = mui.index.get_level_values("edges")
    axj.errorbar(xr, x, y, label=model)

axi.legend()
axj.set_xlabel("Number of edges")
axi.set_xlabel("Number of triangles")

trials = df.trial.max() + 1
print(df.model.unique())
parameters = f"""
Parameters
----------
trials = {trials}
"""
axj.annotate(parameters, (1.05, 1), xycoords="axes fraction")
fig.supylabel("Timing [sec]")
fig.savefig("./bench_results.png", transparent=0)
plt.show(block=1)
