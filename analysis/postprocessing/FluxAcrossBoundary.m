function [xB,yB,qB,qBx,qBy]=FluxAcrossBoundary(X,Y,Fub,Fvb,Fh,Fr)
% FluxAcrossBoundary  Ice mass flux through a set of line segments (edges).
%
% PURPOSE
%   Calculates the mass flux of ice through n edges, at the midpoint of each edge, from the velocity, ice
%   thickness and density interpolants. The normal of an edge points outward for clockwise ordered line
%   segments, so a positive flux is out of the domain. NaN edges and edges of zero length are removed.
%
% INPUTS
%   X, Y         : n-by-2 arrays with the x and y coordinates of the two end points of each of the n edges
%   Fub, Fvb     : interpolants of the velocity components (m/yr)
%   Fh, Fr       : interpolants of the ice thickness (m) and the density (kg/m^3)
%
% OUTPUTS
%   xB, yB       : midpoints of the edges (after removal of invalid edges)
%   qB           : flux through each edge in kg/yr (qB = length * h * rho * u.n)
%   qBx, qBy     : x and y components of the flux (kg/yr)
%
% (used by Calc_UaOBFlux_PerBasin)

Inan = find(isnan(X(:,1))|isnan(X(:,2))|isnan(Y(:,1))|isnan(Y(:,2))); 
fprintf("Removing %s nan values.\n",string(numel(Inan)));

if ~isempty(Inan)
    X(Inan,:)=[];
    Y(Inan,:)=[];
end

ds=hypot(X(:,2)-X(:,1),Y(:,2)-Y(:,1));

Izerods = find(ds<eps);
fprintf("Removing %s segments with zero length.\n",string(numel(Izerods)));

ds(Izerods)=[];
X(Izerods,:)=[];
Y(Izerods,:)=[];
   
% pointing outward for clockwise ordered line segments
nx = -(Y(:,2)-Y(:,1))./ds;
ny = (X(:,2)-X(:,1))./ds;

xB = 0.5*(X(:,1)+X(:,2));
yB = 0.5*(Y(:,1)+Y(:,2));

rhoB=Fr(xB,yB);
ubB=Fub(xB,yB); 
vbB=Fvb(xB,yB); 
hB=Fh(xB,yB); 

qB = ds.*hB.*rhoB.*(ubB.*nx+vbB.*ny);  % units: m kg/m^2 (m/yr) = kg/yr

qBx=qB.*nx; qBy=qB.*ny;

end
