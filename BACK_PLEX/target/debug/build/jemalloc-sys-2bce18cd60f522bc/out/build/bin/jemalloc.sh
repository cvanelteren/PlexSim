#!/bin/sh

prefix=/home/casper/projects/information_impact/PlexSim/plexsim/target/debug/build/jemalloc-sys-2bce18cd60f522bc/out
exec_prefix=/home/casper/projects/information_impact/PlexSim/plexsim/target/debug/build/jemalloc-sys-2bce18cd60f522bc/out
libdir=${exec_prefix}/lib

LD_PRELOAD=${libdir}/libjemalloc.so.2
export LD_PRELOAD
exec "$@"
