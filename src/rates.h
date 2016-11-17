#ifndef RATE_H
#define RATE_H

#include <iostream>
#include <random>
#include <functional>
#include <vector>
#include <string>
#include <gsl/gsl_math.h>
#include <gsl/gsl_integration.h>
#include <gsl/gsl_monte.h>
#include <gsl/gsl_monte_vegas.h>
#include "constants.h"
#include "Xsection.h"

struct integrate1d_params{
	std::function<double(double, double)> interp;   // store a call to member funtion (interp) and object
	double * params;  // other double type parameters
};

double Vegas_func_wrapper(double * var, long unsigned int n_dims, void *params);

template <class T>
class rates{
private:
	T * Xprocess;
	double M;
	const int degeneracy;
	const size_t NE1, NT;
	const double E1L, E1H, TL, TH;
	const double dE1, dT;
	std::vector< std::vector<double> > Rtab;
    std::random_device rd;
    std::mt19937 gen;
    std::gamma_distribution<double> dist_x;
	std::uniform_real_distribution<double> dist_norm_y;
	std::uniform_real_distribution<double> dist_reject;
	void tabulate_E1_T(size_t T_start, size_t dnT);
public:
	rates(T * Xprocess_, int degeneracy_, std::string name_);
	double calculate(double E1, double Temp);
	double interpR(double E1, double Temp);
	void sample_initial(double E1, double Temp, double &E2, double &s);
};



#endif
