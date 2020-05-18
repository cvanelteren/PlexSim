extern crate rand;
extern crate rayon;
extern crate ndarray;
// extern crate ndarray_rand;
extern crate serde;
extern crate serde_json;
extern crate mersenne_twister;
extern crate rand_mt;
extern crate xorshift;
extern crate time;


use std::fs::File;
use std::io::Read;

use rand::prelude::*;
// use rand::{Rng, thread_rng};
use std::mem::{swap};
use rand::distributions::Uniform;
use rand::seq::index::sample;

use ndarray::prelude::*;
use ndarray::parallel::prelude::*;
use ndarray::Zip;

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use serde_json::{Value, Result, json};
use xorshift::{Rand, Rng, SeedableRng, SplitMix64, Xoroshiro128, Xorshift128, Xorshift1024, thread_rng};


type NodeID    = usize;
type NodeState = usize;

struct Structure{
    directed    : bool,
    adj         : HashMap<NodeID, Vec<NodeID>>,
    sampleSize  : usize,
    nodeids     : Vec<NodeID>,
    rng         : Xoroshiro128,
}


impl Structure{
    // constructor
    pub fn new(graph : String) -> Self{
        let tmp: Value = serde_json::from_str(&graph).unwrap();
        let mut source   : NodeID;
        let mut target   : NodeID;
        let directed     : bool = tmp["directed"].as_bool().unwrap(); 

        let mut adj     = HashMap::<NodeID, Vec<NodeID>>::new();
        let links   : Vec::<Value> =
            tmp["links"].as_array().unwrap().to_vec().to_owned();

        for hm in links{
            source = hm["source"].as_i64().unwrap() as usize;
            target = hm["target"].as_i64().unwrap() as usize;
            adj.entry(target).or_insert(Vec::new()).push(source);
            if !directed{
                adj.entry(source).or_insert(Vec::new()).push(target);
            }
        }
        let sampleSize : usize;
        if tmp["sampleSize"].is_number(){
            sampleSize = tmp["sampleSize"].as_i64().unwrap() as usize;
        }
        else{
            sampleSize = adj.len() as usize;
        }

        let nodeids : Vec<NodeID> = adj.keys().cloned().collect();
        use time::precise_time_ns;
        let now = precise_time_ns();
        // let mut sm: SplitMix64 = SeedableRng::from_seed(now);
        // let mut rng : Xoroshiro128 = Rand::rand(&mut sm);
        let rng : Xoroshiro128 = thread_rng();
        return Self{
            directed   : directed,
            adj        : adj,
            sampleSize : sampleSize,
            nodeids    : nodeids,
            rng        : rng,
        }; 
    }

    pub fn sampleNodes(&mut self, n_samples: usize) -> Array1<NodeID>{
        // let mut rng : MersenneTwister = SeedableRng::from_seed(0);
        let N  = n_samples * self.sampleSize;
        let mut nodeids = Array1::<NodeID>::zeros(N);
        // loop vars
        let nNodes = self.adj.len() - 1 as usize;
        let mut j : NodeID;
        nodeids.par_map_inplace(|val|
         {
             let mut r = self.rng;
             *val = r.gen_range(0, nNodes);
        });

        // find parallel alternative
        // let mut checker: usize;
        // for (sample, val) in nodeids.indexed_iter_mut()
        // {
        //     checker = sample % nNodes; 
        //     if checker == 0{
        //         for i in nNodes..1{
        //            j = self.rng.gen_range(0, i);
        //            self.nodeids.swap(i, j);
        //         }
        //         // self.rng.shuffle(&mut self.nodeids);
        //         // self.nodeids.shuffle(&mut self.rng);
        //     }
        //     *val  =  self.nodeids[checker];
        // }

        // println!("{:?}", nodeids);
        return nodeids;
    }

    pub fn randCheck(&mut self, N: usize) {
        use rand::distributions::Uniform;
        let mut m;
        for x in 0..N{
            m = self.rng.gen_range(0., 1.);
        }
    }

    pub fn testArray(&self, n : usize){
        let m = Array1::<usize>::ones(n);
        let mut d = m.sum();
        // for x in m.iter(){
            // d += x;
        // }
        assert_eq!(d, n);
    }


    pub fn testVec(&self, n : usize){
        let m = vec![1; n];
        let mut d = 0;
        for x in m.iter(){
            d += x;
        }
        assert_eq!(d, n);
    }

}



struct Dynamics{
    structure : Structure,
    states    : Vec<NodeState>,
    newstates : Vec<NodeState>,
}

// // hold dynamics functions
// impl Dynamics{
//     fn step(&self, node: NodeID){}
//     fn swap_buffers(&self){
//         swap(&mut self.states, &mut self.newstates);
//        }
//     fn update(&self, nodes: Vec<NodeID>) -> Vec<NodeState>{
//         for node in nodes.iter(){
//             self.step(*node)
//         }
//         let tmp = self.newstates.clone() ;
//         self.swap_buffers();
//         return tmp;
//     }
// }




struct Potts{
    dynamics : Dynamics,
}


extern crate floating_duration;
use std::path::Path;


fn main(){
    let path = Path::new("/home/casper/projects/information_impact/PlexSim/plexsim/edge.json");
    let mut file = File::open(path).unwrap();
    let mut buff = String::new();
    file.read_to_string(&mut buff).unwrap();
    let mut m = Structure::new(buff);
    use std::time::{Duration, Instant};
    use floating_duration::TimeFormat;
    let mut n : Array1<NodeID>;
    // let steps = 10usize.pow(1);
    let steps = 10usize.pow(5);
    let loops = 100000;
    
    let start = Instant::now();
    for x in 0..loops{
        m.testArray(steps);
        // m.testArray(steps);
        // m.randCheck(steps);
    }
    println!("Time taken: {} ", TimeFormat(
        start.elapsed()));
}
