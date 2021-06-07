#ifndef PYHOLDER_HPP
#define PYHOLDER_HPP
#include <Python.h>
#include <mutex>

// lock
std::mutex ref_mutex;

class PyObjectHolder {
public:
  PyObject *ptr;
  // constructor
  PyObjectHolder();
  PyObjectHolder(PyObject *o);

  // rule of 3
  ~PyObjectHolder();
  PyObjectHolder(const PyObjectHolder &h);
  PyObjectHolder &operator=(const PyObjectHolder &other);
};
#endif
