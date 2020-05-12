
extern crate rand;
extern crate ndarray;
extern crate ndarray_rand;

use rand::{Rng, thread_rng};
use rand::distributions::Uniform;

use ndarray::prelude::*;
// use rand::distributions::Range;
use ndarray_rand::RandomExt;

trait Simulate{
    fn sampleNodes(&self, nSamples: usize) -> Array2<usize>;
    fn step(&self, node: i32);
    fn update(&self, nodes: Array1<i32>);
}

struct Potts{
    states    : Vec<usize>,
    newstates : Vec<usize>,
    nNodes    : usize,
    sampleSize: usize,
}

impl Simulate for Model{
     fn sampleNodes(&self, nSamples: usize) -> Array2<usize> {
         return Array::random((nSamples, self.sampleSize), Uniform::new(0, self.nNodes));
    }

    fn step(&self, node: i32) {
    }

    fn update(&self, nodes : Array1<i32>){
        for node in nodes.iter(){
            self.step(*node);
         }
    }
}

struct Potts{
    states    : Vec<usize>,
    newstates : Vec<usize>,
    nNodes    : usize,
    sampleSize: usize,
}

impl Potts{
   pub fn new(nNodes: usize) -> Potts{
        Potts{
            nNodes: nNodes,
            sampleSize: nNodes,
            states: vec![0; nNodes],
            newstates: vec![0, nNodes],
        }
     }
}
impl Model for Potts{
}

fn main(){
    let m = Potts::new(100);
    println!("{:?}", m.sampleNodes(20));

}
