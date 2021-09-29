#include "pyobjectholder.hpp"

// default constructor
PyObjectHolder::PyObjectHolder() : ptr(nullptr){};

// constructor point python object
PyObjectHolder::PyObjectHolder(PyObject *o) : ptr(o) {
  /**
   * @brief      Holds pointer to a python object.
   *
   * @details  Cython  does  not allow  for  interaction  of
   * python objects. Cython extensions are considered python
   * objects under OpenMP operations. This class circumvents
   * this problem; it holds merely a pointer to the original
   * object  and should  be unpacked  according to  its base
   * type (see cython code).
   *
   */
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
    std::lock_guard<std::mutex> guard(ref_mutex);
    // remove object from ref count
    Py_XDECREF(ptr);
    // reassign and update ref count
    ptr = other.ptr;
    Py_XINCREF(ptr);
  }
  return *this;
}
