#ifndef LANGEVIN_H
#define LANGEVIN_H

#include <vector>
#include "qhat.h"

struct particle
{
        std::vector<double> p;
        std::vector<double> x;
        double t_last, t_last2;
        double Nx, Nc2;
        double weight;
};

std::vector<double> rotate_toZ(std::vector<double> const& xi, double px, double py, double pz);
std::vector<double> rotate_toZ(std::vector<double> const& xi, double px, double py, double pz);

int update_by_Langevin(particle& HQ, double temp, double drag, double kpara, double kperp, double deltat, bool EinR);
int update_by_Langevin_test(particle& HQ, Qhat_2to2* qhatQq2Qq, Qhat_2to2* qhatQg2Qg, double temp, double deltat, bool EinR);

#endif
