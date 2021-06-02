#include "pyobjectholder.hpp"

// default constructor
PyObjectHolder::PyObjectHolder() : ptr(nullptr){};

// constructor point python object
PyObjectHolder::PyObjectHolder(PyObject *o) : ptr(o){
    std::lock_guard<std::mutex> guard(ref_mutex);
}


PyObjectHolder::PyObjectHolder(const PyObjectHolder &h):
            PyObjectHolder(h.ptr){};

// default destructor
PyObjectHolder::~PyObjectHolder(){
        std::lock_guard<std::mutex> guard(ref_mutex);
        Py_XDECREF(ptr);
}

// assign operator
PyObjectHolder& PyObjectHolder::operator=(const PyObjectHolder &other){
    {
        std::lock_guard<std::mutex> gaurd(ref_mutex);
        Py_XDECREF(ptr);
        ptr=other.ptr;
        Py_XINCREF(ptr);
    }
    return *this;
}

