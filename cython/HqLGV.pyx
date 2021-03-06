# cython: c_string_type=str, c_string_encoding=ascii
from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp cimport bool
from libc.stdlib cimport malloc, free
from libc.stdlib cimport rand, RAND_MAX
from libc.math cimport *
import os

cdef double GeV_to_Invfm = 5.068

#------------------Import C++ fucntions and class for Xsection and rates------------------
cdef extern from "../src/matrix_elements.h":
	cdef double dqhat_Qq2Qq_dPS(double* PS, size_t ndims, void* params)
	cdef double dqhat_Qg2Qg_dPS(double* PS, size_t ndims, void* params)

cdef extern from "../src/qhat_Xsection.h":
	cdef cppclass QhatXsection_2to2:
		QhatXsection_2to2(double (*dXdPS_)(double*, size_t, void *), double M1_, string name_, bool refresh)
		double calculate(double *args)
		double interpX(double *args)

cdef extern from "../src/qhat.h":
	cdef cppclass Qhat_2to2:
		Qhat_2to2(QhatXsection_2to2 *Xprocess_, int degeneracy_, double eta_2_, string name_, bool refresh)
		double calculate(double *args)
		double interpQ(double *args)

#------------- Import c++ function for Langevin evolution
cdef extern from "../src/Langevin.h":
	cdef int Langevin_pre(double E1, double mass, double temp, double drag, double kpara, double kperp, double delta_lrf, vector[double] & pre_result)
	cdef int Langevin_post(double E1, double mass, double temp, double drag, double kpara, double kperp, double delta_lrf, vector[double] & pre_result, vector[double] & post_result)



#------------ Heavy quark Langevin transport evolution class -------------
cdef class HqLGV:
	cdef bool elastic, EinR
	cdef QhatXsection_2to2 * qhatX_Qq2Qq
	cdef QhatXsection_2to2 * qhatX_Qg2Qg
	cdef Qhat_2to2 * qhat_Qq2Qq
	cdef Qhat_2to2 * qhat_Qg2Qg 
	cdef size_t Nf
	cdef double mass, deltat_lrf
	cdef public vector[double] pre_result, post_result
		
	def __cinit__(self, options, table_folder='./tables', refresh_table=False):
		self.mass = options['mass']
		self.Nf = options['Nf']
		self.elastic = options['elastic']
		self.EinR = options['Einstein']
		self.deltat_lrf = options['dt_lrf']
		
		if not os.path.exists(table_folder):
			os.makedirs(table_folder)

		if self.elastic:
			self.qhatX_Qq2Qq = new QhatXsection_2to2(&dqhat_Qq2Qq_dPS, self.mass, "%s/QhatX_Qq2Qq.hdf5"%table_folder, refresh_table)
			self.qhatX_Qg2Qg = new QhatXsection_2to2(&dqhat_Qg2Qg_dPS, self.mass, "%s/QhatX_Qg2Qg.hdf5"%table_folder, refresh_table)
			self.qhat_Qq2Qq = new Qhat_2to2(self.qhatX_Qq2Qq, 12*self.Nf, 0., "%s/Qhat_Qq2Qq.hdf5"%table_folder, refresh_table)
			self.qhat_Qg2Qg = new Qhat_2to2(self.qhatX_Qg2Qg, 16, 0., "%s/Qhat_Qg2Qg.hdf5"%table_folder, refresh_table)
		
		# giving the incoming heavy quark energy E1 in cell frame, return new_p(p0, px, py, pz) in (0, 0, p_length) frame
	cpdef update_by_Langevin(self, double E1, double temp):
		cdef double drag_Qq, drag_Qg, drag
		cdef double kperp_Qq, kperp_Qg, kperp, \
					kpara_Qq, kpara_Qg, kpara
		cdef double p_length = sqrt(E1*E1 - self.mass*self.mass)
		cdef double * arg = <double*> malloc(4*sizeof(double))
		arg[0] = E1; arg[1] = temp; arg[2] = 0; arg[3] = 0
		drag_Qq = self.qhat_Qq2Qq.interpQ(arg)
		drag_Qg = self.qhat_Qg2Qg.interpQ(arg)
		arg[3] = 1
		kperp_Qq = self.qhat_Qq2Qq.interpQ(arg)
		kperp_Qg = self.qhat_Qg2Qg.interpQ(arg)
		arg[3] = 2
		kpara_Qq = self.qhat_Qq2Qq.interpQ(arg)
		kpara_Qg = self.qhat_Qg2Qg.interpQ(arg)

		drag = (drag_Qq + drag_Qg) / p_length * GeV_to_Invfm
		kperp = (kperp_Qq + kperp_Qg) * GeV_to_Invfm
		kpara = (kpara_Qq + kpara_Qg) * GeV_to_Invfm
		if self.EinR:
			drag = kperp / (2.*temp*E1);

		Langevin_pre(E1, self.mass, temp, drag, kperp, kpara, self.deltat_lrf, self.pre_result)
		cdef double new_energy = self.pre_result[0]


		arg[0] = new_energy
		arg[3] = 1
		kperp_Qq = self.qhat_Qq2Qq.interpQ(arg)
		kperp_Qg = self.qhat_Qg2Qg.interpQ(arg)
		arg[3] = 2
		kpara_Qq = self.qhat_Qq2Qq.interpQ(arg)
		kpara_Qg = self.qhat_Qg2Qg.interpQ(arg)

		free(arg)
		kperp = (kperp_Qq + kperp_Qg) * GeV_to_Invfm
		kpara = (kpara_Qq + kpara_Qg) * GeV_to_Invfm

		Langevin_post(E1, self.mass, temp, drag, kperp, kpara, self.deltat_lrf, self.pre_result, self.post_result)
		return 1 

