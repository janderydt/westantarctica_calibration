function [b,h] = Calc_dh_from_ds(X,Y,s,B,rho,rhow)
% Calc_dh_from_ds  Ice draft and thickness from surface elevation and bed.
%
% PURPOSE
%   Calculates the lower ice surface (draft) b and the ice thickness h = s - b
%   from the ice surface s, bed B and ice density rho, assuming hydrostatic
%   equilibrium for floating ice. The grounded/floating transition is smoothed
%   with a smooth Heaviside function G (as in Ua, see the Ua Compendium), and
%   b = G*B + (1-G)*b_float is solved with a Newton iteration (at most 30).
%
% INPUTS
%   X,Y     : 2D coordinate matrices (only used for the size; sea level S = 0)
%   s       : ice surface elevation (m, above sea level)
%   B       : bed elevation (m)
%   rho     : vertically averaged ice density (kg/m^3)
%   rhow    : ocean density (kg/m^3)
%
% OUTPUTS
%   b       : ice draft (lower ice surface, m)
%   h       : ice thickness, h = s - b (m)
%
% REQUIRES
%   HeavisideApprox, DiracDelta (Ua source code, https://github.com/GHilmarG/UaSource)

S = 0*X;

% Initial estimate of the draft b: the larger of the bed B and the draft the ice
% would have if it were afloat, b_float = (rho*s - rhow*S)/(rho - rhow).
% hf is the flotation thickness, hf = rhow*(S-B)/rho.
hf=rhow*(S-B)./rho ;

b0 =  max(B,(rho.*s-rhow.*S)./(rho-rhow)) ; 

b=b0;
h=s-b;

% iteration
ItMax=30 ; tol=100*eps ;  J=Inf ; I=0 ;
JVector=zeros(ItMax,1)+NaN ;        

CtrlVar.kH = 1;
CtrlVar.Hh0 = 0;

while I< ItMax && J > tol
    I=I+1;

    G = HeavisideApprox(CtrlVar.kH,h-hf,CtrlVar.Hh0);  % 1
    dGdb=-DiracDelta(CtrlVar.kH,h-hf,CtrlVar.Hh0) ;
    
    F0=    b - G.*B - (1-G).*(rho.*s-rhow.*S)./(rho-rhow) ;
    dFdb = 1 - dGdb.* (B -  (rho.*s-rhow.*S)./(rho-rhow)) ;
    
    db= -F0./dFdb ;
    
    b=b+db ;
    h=s-b ;
    
    F1 =    b - G.*B - (1-G).*(rho.*s-rhow.*S)./(rho-rhow) ;
    
    JLast=J ;
    J=sum(F1.^2,'all','omitnan')/2 ;
    
    JVector(I)=J ;
    
end

fprintf("%s iterations needed for bh calculation.\n",string(I));

end
