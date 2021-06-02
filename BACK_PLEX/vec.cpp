#include <cstdlib>
#include <vector>

#include <iostream>
#include <string>

#include <boost/date_time/posix_time/ptime.hpp>
#include <boost/date_time/microsec_time_clock.hpp>

class TestTimer
{
    public:
        TestTimer(const std::string & name) : name(name),
            start(boost::date_time::microsec_clock<boost::posix_time::ptime>::local_time())
        {
        }

        ~TestTimer()
        {
            using namespace std;
            using namespace boost;

            posix_time::ptime now(date_time::microsec_clock<posix_time::ptime>::local_time());
            posix_time::time_duration d = now - start;

            cout << name << " completed in " << d.total_milliseconds() / 1000.0 <<
                " seconds" << endl;
        }

    private:
        std::string name;
        boost::posix_time::ptime start;
};

struct Pixel
{
    Pixel()
    {
    }

    Pixel(unsigned char r, unsigned char g, unsigned char b) : r(r), g(g), b(b)
    {
    }

    unsigned char r, g, b;
};

void UseVector(std::vector<std::vector<Pixel> >& results)
{
    TestTimer t("UseVector inner");

    for(int i = 0; i < 1000; ++i)
    {
        int dimension = 999;

        std::vector<Pixel>& pixels = results.at(i);
        pixels.resize(dimension * dimension);

        for(int i = 0; i < dimension * dimension; ++i)
        {
            pixels[i].r = 255;
            pixels[i].g = 0;
            pixels[i].b = 0;
        }
    }
}

void UseVectorPushBack(std::vector<std::vector<Pixel> >& results)
{
    TestTimer t("UseVectorPushBack inner");

    for(int i = 0; i < 1000; ++i)
    {
        int dimension = 999;

        std::vector<Pixel>& pixels = results.at(i);
            pixels.reserve(dimension * dimension);

        for(int i = 0; i < dimension * dimension; ++i)
            pixels.push_back(Pixel(255, 0, 0));
    }
}

void UseArray(Pixel** results)
{
    TestTimer t("UseArray inner");

    for(int i = 0; i < 1000; ++i)
    {
        int dimension = 999;

        Pixel * pixels = (Pixel *)malloc(sizeof(Pixel) * dimension * dimension);

        results[i] = pixels;

        for(int i = 0 ; i < dimension * dimension; ++i)
        {
            pixels[i].r = 255;
            pixels[i].g = 0;
            pixels[i].b = 0;
        }

        // free(pixels);
    }
}

void UseArray()
{
    TestTimer t("UseArray");
    Pixel** array = (Pixel**)malloc(sizeof(Pixel*)* 1000);
    UseArray(array);
    for(int i=0;i<1000;++i)
        free(array[i]);
    free(array);
}

void UseVector()
{
    TestTimer t("UseVector");
    {
        std::vector<std::vector<Pixel> > vector(1000, std::vector<Pixel>());
        UseVector(vector);
    }
}

void UseVectorPushBack()
{
    TestTimer t("UseVectorPush");
    {
        std::vector<std::vector<Pixel> > vector(1000, std::vector<Pixel>());
        UseVectorPushBack(vector);
    }
}


int main()
{
    TestTimer t1("The whole thing");

    UseArray();
    UseVector();
    UseVectorPushBack();

    return 0;
}
