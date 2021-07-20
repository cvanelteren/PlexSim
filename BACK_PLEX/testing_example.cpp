
int main(){
  std::cout<< "testin";
  size_t n = 100000;
  size_t sampleSize = 0;
  std::cout << "test";
  FOENA agentStates = FOENA({0, 1});
  py::object nx = py::module::import( "networkx" );
  py::object g  = nx.attr("path_graph")(100);

  std::cout << "test";

   PottsFast m = PottsFast(g);
   m.simulate(n);

   Potts_ M = Potts_(g);
   M.simulate(n);

   // Potts N = Potts(g,
   //                agentStates,
   //                sampleSize);

   // N.simulate(n);

};

// Local variables:
// rmsbolt-command: "\
// c++ \
//     -O3  \
//     -fopenmp\
//     -fdevirtualize\
//     -fopenmp-simd \
//     -DNDEBUG \
//     -std=c++17\
//     -march=native\
//     -shared \
//     -fPIC\
//     -flto\
//     -lcblas\
//     -Wfatal-errors \
//     -I/usr/include/python3.8/  \
//     -I/home/casper/miniconda3/lib/python3.8/site-packages/numpy/core/include \
//     -I/home/casper/miniconda3/include \
// "
// End:
