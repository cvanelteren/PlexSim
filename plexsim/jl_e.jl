using Pkg
Pkg.add("StatsBase")
import StatsBase

n = 1000;
m = 1000;
a = ones{Int64}(m, n)


for i = 1:n
    StatsBase.fisher_yates_sample!(linspace(1,n) linspace(1, n));
end
