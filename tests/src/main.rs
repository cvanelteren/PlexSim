use std::time::{Duration, Instant};

extern crate rand;
extern crate ndarray;
extern crate ndarray_rand;
extern crate rayon;
use rayon::prelude::*;
use ndarray::Array;
use ndarray_rand::RandomExt;
use rand::distributions::Range;
use rand::Rng;
fn main() {
    
    let mut rng = rand::thread_rng();
    // let mut rng = Isaac64Rng::seed_from_64(3);


    let m = 125*125;
    let n = 10000;

    let z = m * n;

    let R = Range::new(0., 1.);    
    let now = Instant::now();
    let mut a;
    for _ in 0..4{
       a = Array::random((m, n), R);
    };
    let nn = Instant::now();
    println!("{:?}", nn.duration_since(now)); 
}
