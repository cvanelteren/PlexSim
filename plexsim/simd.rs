extern crate faster;
use faster::*;

fn main(){
    let two_hundred = [2.0f32; 100].simd_iter(f32s(0.0))
        .simd_reduce(f32s(0.0), |acc, v| acc + v)
        .sum();
}


