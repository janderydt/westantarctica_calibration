function [UserVar,ub,vb,ud,vd]=DefineStartVelValues(UserVar,CtrlVar,MUA,BCs,ub,vb,ud,vd,time,s,b,h,S,B,rho,rhow,GF,AGlen,n,C,m)
% DefineStartVelValues  Ua user input file: start values of the velocities.
% (File name must be DefineStartVelValues.m for Ua to find it; the uploaded file was
% called DefineStartValues.m.) Start velocities are set to 1 m/yr and ud=vd=0.
          
	zer=s*0;
	ub=zer+1 ; vb=zer+1 ; 
    ud = zer; vd = zer;
	
end
