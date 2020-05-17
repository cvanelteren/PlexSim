#![feature(specialization)]
#![feature(proc_macro)]
#![feature(proc_macro_path_invoc)]
extern crate pyo3;
use pyo3::prelude::*;

#[py::class]
struct RObject {
    num : i32,
    token: PyToken,
}

#[py::methods]
impl RObject {

    pub fn new(py: Python, v:i32) -> PyResult<Py<RObject>> {
        let obj = py.init(|t| RObject{num:v, token: t});
        Ok(obj)
    }

    pub fn mul(&self, v :i32) -> PyResult<i32> {
        Ok(self.num * v)
    }
}

#[py::modinit(spring)]
fn init(py: Python, m: &PyModule) -> PyResult<()> {

    m.add_class::<RObject>()?;

    Ok(())
}
