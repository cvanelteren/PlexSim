extern crate rand;
extern crate rayon;
extern crate ndarray;
extern crate ndarray_rand;
extern crate serde;
extern crate serde_json;
extern crate mersenne_twister;
extern crate rand_mt;


use std::fs::File;
use std::io::Read;

use rand::prelude::*;
use rand::{Rng, thread_rng};
use std::mem::{swap};
use rand::distributions::Uniform;

use ndarray::prelude::*;
use ndarray_rand::RandomExt;

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use serde_json::{Value, Result, json};

use rayon::prelude::*;
use mersenne_twister::{MersenneTwister};

type NodeID    = usize;
type NodeState = usize;

struct Structure{
    directed    : bool,
    adj         : HashMap<NodeID, Vec<NodeID>>,
    sampleSize  : usize,
    nodeids     : Vec<NodeID>,
    rng         : rand_mt::Mt64,
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

        let mut rng = rand_mt::Mt64::new(0);
        return Self{
            directed   : directed,
            adj        : adj,
            sampleSize : sampleSize,
            nodeids    : nodeids,
            rng        : rng,
        }; 
    }

    pub fn sampleNodes(&mut self, nSamples: usize) -> Array1<NodeID>{
        // let mut rng : MersenneTwister = SeedableRng::from_seed(0);
        let N  = nSamples * self.sampleSize;
        // let mut nodeids = Array2::<NodeID>::zeros((nSamples, self.sampleSize));
        let mut nodeids = Array1::<NodeID>::zeros(N);
        let mut checker: usize;
        let nNodes = self.adj.len() - 1 as usize;

        for (sample, val) in nodeids.indexed_iter_mut()
        {
            checker = sample % nNodes; 
            if checker == 0{
                self.nodeids.shuffle(&mut self.rng);
            }
            *val  =  self.nodeids[checker];
        }
        return nodeids;
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
    println!("{}", m.adj.len());
    let steps = 1000;
    let loops = 4;
    let start = Instant::now();
    for x in 0..loops{
       m.sampleNodes(steps);
    }
    println!("Time taken: {} ", TimeFormat(
        start.elapsed()));


}
