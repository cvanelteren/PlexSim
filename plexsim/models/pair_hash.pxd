cdef extern from *:
    """
    #ifndef pair_hash_h
    #define pair_hash_h
    struct pair_hash {
        template <class T1, class T2>
        std::size_t operator () (const std::pair<T1,T2> &p) const {
            auto h1 = std::hash<T1>{}(p.first);
            auto h2 = std::hash<T2>{}(p.second);
        return h1 ^ h2;
        }
    };
    #endif
    """
    cdef cppclass pair_hash[T, U]:
       pair[T, U]& operator()

    cdef cppclass hash_unordered_map[T, U, H]:
       hash_unordered_map() except+
