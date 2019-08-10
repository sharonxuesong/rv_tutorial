# import the necessary packages
import numpy as np
from scipy import interpolate
import matplotlib.pyplot as plt
import os
import matplotlib.gridspec as gridspec
from scipy import interpolate
from scipy.optimize import fmin
import emcee
import corner
%matplotlib inline 

os.chdir('../synspec')
specdata=np.load('Kurucz_Sun.npz')
wavelength=specdata['arr_0']
flux=specdata['arr_1']

w_chunk=wavelength[(wavelength>=520) & (wavelength<=520.5)]
f=flux[(wavelength>=520) & (wavelength<=520.5)]

c=2.99792458E8 #light speed in m/s
v_rad=27201    #m/s
z=v_rad/c
print(z)
z_correct=z
w_observed=w_chunk*(1+z)
print(w_chunk-w_observed)

fig = plt.figure(figsize=(24,8))
gs = gridspec.GridSpec(1, 3)
ax1 = plt.subplot(gs[0, 0])
ax2 = plt.subplot(gs[0, 1])
ax3 = plt.subplot(gs[0, 2])
ax1.plot(w_chunk,f,'k-')
ax2.plot(w_observed, f,'k-')
ax3.plot(w_chunk,f,'b-')
ax3.plot(w_observed, f,'r-')
ax3.legend(['Template','Observed'])
ax1.set_xlabel('$\lambda_{chunk}$')
ax2.set_xlabel('$\lambda_{observed}$')
ax3.set_xlabel('$\lambda$')
ax1.set_ylabel('flux')
plt.show()


#For z, at first I chose -(3E4)/c ~ (3E4)/c only consider about the BC shift
z_max=(3E4)/c
z_min=(-3E4)/c
print(z_max)
print(z_min)
z_list=np.linspace(z_min,z_max,200)


def spec_interpolation(z,w1,flux,w2):   #w1:template wavelength, w2:predicted wavelength
    w1_correction=w1*(1+z)
    f = interpolate.interp1d(w1_correction,flux,kind='cubic')
    #f = interpolate.interp1d(w1_correction,flux)
    flux_pred = f(w2)
    return flux_pred
    
    
#Example#
z_example= 9E-5
w_template=wavelength[(wavelength>519.8) & (wavelength<520.6)]
f_template=flux[(wavelength>519.8) & (wavelength<520.6)]
#print(w_template)
#print(w_emitted)
#exit()
flux_pred = spec_interpolation(z_example,w_template,f_template,w_observed)
plt.figure()
plt.plot(wavelength,flux)
plt.plot(w_observed,flux_pred)
plt.legend(['Template','Observed'])
plt.scatter(w_observed,flux_pred,color='red',marker='.')
plt.xlim(519.95,520.46)
plt.xlabel('$\lambda$')
plt.ylabel('flux')
plt.show()


ccf_list=[]
for z in z_list:
    CCF = np.sum((spec_interpolation(z,w_template,f_template,w_observed)-f)**2)
    ccf_list=np.append(ccf_list,[CCF],axis=0)
    print(CCF)
print(ccf_list)
print("finished!")


fig = plt.figure(figsize=(16,8))
gs = gridspec.GridSpec(1, 2)
ax1 = plt.subplot(gs[0, 0])
ax2 = plt.subplot(gs[0, 1])
ax1.plot(z_list,ccf_list)
ax2.plot(z_list[(z_list<10E-5) & (z_list>0)],ccf_list[(z_list<10E-5) & (z_list>0)])
plt.show()


#based on the plot above, I choose the z from -1E-5 to 10E-5 to do the Gaussian fitting.
'''
with open('z_list',"w") as object:
    for i in range(len(z_list)):
        object.write(str(z_list[i])+' '+str(ccf_list[i])+'\n')
object.close()
'''

z_chosen=z_list[(z_list<10E-5) & (z_list>-1E-5)]
ccf_chosen=ccf_list[(z_list<10E-5) & (z_list>-1E-5)]

#fmin#

def ccf_fit(z,p):
    u,sigma,c,k = p
    return k-c*np.exp(-(z-u)**2/(sigma**2))

def residuals(p,z,f):
    return np.sum((f-ccf_fit(z,p))**2)

iniparam0=[9E-5,1E-5,10,40]
parambest,chi2min,iter,funcalls,warnflag,allvecs = fmin(residuals,iniparam0,args=(z_chosen,ccf_chosen),full_output=True,retall=True,maxiter=300,maxfun=1000)
print(parambest)

plt.figure()
plt.plot(z_chosen,ccf_chosen,'.')
plt.plot(z_chosen,ccf_fit(z_chosen,parambest),'r-')
plt.show()

#fitting result#
print ("z_fitted=%s"%(parambest[0]))
print ("z_correct=%s"%(z))
#It seems the result is not good#
