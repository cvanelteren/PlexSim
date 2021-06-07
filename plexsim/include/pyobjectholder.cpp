#include "pyobjectholder.hpp"

// default constructor
PyObjectHolder::PyObjectHolder() : ptr(nullptr){};

// constructor point python object
PyObjectHolder::PyObjectHolder(PyObject *o) : ptr(o) {
  // acquire guard
  std::lock_guard<std::mutex> guard(ref_mutex);
  // increase ref counter
  Py_XINCREF(ptr);
}

PyObjectHolder::PyObjectHolder(const PyObjectHolder &h)
    : PyObjectHolder(h.ptr){};

// default destructor
PyObjectHolder::~PyObjectHolder() {

  // release guard
  std::lock_guard<std::mutex> guard(ref_mutex);
  // decrease ref counter
  Py_XDECREF(ptr);
}

// assign operator
PyObjectHolder &PyObjectHolder::operator=(const PyObjectHolder &other) {
  {
    // acquire lock
    std::lock_guard<std::mutex> gaurd(ref_mutex);
    // remove object from ref count
    Py_XDECREF(ptr);
    // reassign and update ref count
    ptr = other.ptr;
    Py_XINCREF(ptr);
  }
  return *this;
}
