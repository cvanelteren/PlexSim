#!/bin/sh

prefix=/home/casper/projects/information_impact/PlexSim/plexsim/target/release/build/jemalloc-sys-40aa1ea4686391e1/out
exec_prefix=/home/casper/projects/information_impact/PlexSim/plexsim/target/release/build/jemalloc-sys-40aa1ea4686391e1/out
libdir=${exec_prefix}/lib

LD_PRELOAD=${libdir}/libjemalloc.so.2
export LD_PRELOAD
exec "$@"
