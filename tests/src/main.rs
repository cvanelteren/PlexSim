use std::time::{Duration, Instant};

extern crate rand;
extern crate ndarray; extern crate ndarray_rand;


use ndarray::Array;
use ndarray_rand::RandomExt;
use rand::distributions::Range;
use rand::Rng;


fn main() {
    let mut rng = rand::thread_rng();


    let m = 100;
    let n = 10000;

    let z = m * n;

    
    let now = Instant::now();
    let mut  a;
    for _ in 0..2{
       a = Array::random((m, n), Range::new(0., 1.));
    }
    let nn = Instant::now();
    println!("{:?}", nn.duration_since(now)); 
}
