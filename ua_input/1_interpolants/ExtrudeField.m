function vg = ExtrudeField(x,y,vx,vy,x_orig,y_orig,v_orig,step,nsteps)
% ExtrudeField  Extrude a gridded field along flowlines from its data edge.
%
% PURPOSE
%   Takes the perimeter of the finite values of v_orig as seeds, follows
%   streamlines of the vector field (vx,vy) from each seed (stream2), assigns
%   the seed value to all points along the streamline, and grids the result
%   onto the original grid (gridbin). Adapted from Chad Greene.
%
% INPUTS
%   x,y         : grid vectors of the flow field (vx,vy), e.g. H*u, H*v
%   vx,vy       : flow field used to trace flowlines
%   x_orig,y_orig,v_orig : grid vectors and field to be extruded
%                          (NaN where there is no data)
%   step,nsteps : streamline step size (fraction of a grid cell) and maximum number of steps
%
% OUTPUT
%   vg          : extruded field on the original grid (NaN where no flowline reaches)
%
% REQUIRES
%   Image Processing Toolbox (bwperim); gridbin and cell2nancat (C. Greene's
%   tools, not part of this repository)

% Adapted from Chad Greene
[X,Y] = meshgrid(x_orig,y_orig);

perim = bwperim(isfinite(v_orig));
xseed = X(perim); 
yseed = Y(perim); 
[row,col] = find(perim); 
XY = stream2(x,y,vx,vy,xseed,yseed,[step nsteps]);

clear x y vx vy X Y 

% Remove empty entries
IndEmpty = find(cellfun(@isempty,XY));
XY(IndEmpty)=[];
row(IndEmpty)=[];
col(IndEmpty)=[];

clear IndEmpty

V = XY;
for k = 1:length(V) 
     V{k}(:,1) = v_orig(row(k),col(k));
end
V = cell2nancat(V);
vv = [v_orig(perim);V(:,1)] ;

clear V v_orig;

XY = cell2nancat(XY);
xx = [xseed;XY(:,1)] ;
yy = [yseed;XY(:,2)] ;

clear XY perim

isf = isfinite(vv);
xx = xx(isf);
yy = yy(isf);
vv = vv(isf);

clear isf

% Grid up the streamline data:  
vg = gridbin(xx,yy,vv,x_orig,y_orig);

clear xx yy vv x_orig y_orig
