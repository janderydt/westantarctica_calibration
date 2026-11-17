function [UserVar,ub,vb,ud,vd]=DefineStartVelValues(UserVar,CtrlVar,MUA,BCs,ub,vb,ud,vd,time,s,b,h,S,B,rho,rhow,GF,AGlen,n,C,m)
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Part of the diagnostic stage, which needs the inversion results (restart files) of the
% ensemble members. These data can be obtained upon request from the author.
%
% DefineStartVelValues  Ua user input file (diagnostic stage): start values of the velocities.
% (Ua looks for the file DefineStartVelValues.m; in the uploaded version the file and the
% function were called DefineStartValues.) Start velocities are 1 m/yr, ud=vd=0.
          
	zer=s*0;
	ub=zer+1 ; vb=zer+1 ; 
    ud = zer; vd = zer;
	
end
