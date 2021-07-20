#include <iostream>
using namespace std;
// CRTP EXAMPLE
template <typename T>
class CRTP_A{
  public:
    void do_stuff(size_t N){
        for (size_t i = 0; i<N ; i++){
            static_cast<T&>(*this).do_inner();
        }
    }

 };

class CRTP_B : public CRTP_A<CRTP_B>{
  void do_inner(){
    // heavy computation
  }
};


// VIRTUAL EXAMPLE
class VIRTUAL_A{
  public:
  virtual void do_inner() {};

  void do_stuff(size_t N){
        for (size_t i = 0; i<N ; i++){
            this->do_inner();
        }
  }
};

class VIRTUAL_B : public VIRTUAL_A{
  public:
  void do_inner() override{
    //do heavy computation
  }
};


// FLAT EXAMPLE
class FLAT_A{
  public:
  void do_inner(){
  //heavy computation
}

void do_stuff(size_t N){
  for (size_t i = 0 ; i < N ; i++ ){
    this->do_inner();
    }
  }

};



int main(){
  long n = 10000000;
  for (int i = 0; i < n ; i++) {
    cout << "hello";
  }

}
