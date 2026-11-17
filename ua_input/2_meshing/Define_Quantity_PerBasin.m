function [basin,ind] = Define_Quantity_PerBasin(x,y,B,doplots)
% Define_Quantity_PerBasin  Assign points (e.g. mesh nodes) to basins.
%
% PURPOSE
%   Finds for each coordinate pair (x,y) the basin it belongs to. Points inside
%   a basin polygon are assigned to that basin (a point in several polygons
%   goes to the first one); any remaining points are assigned to the basin with
%   the nearest boundary point.
%
% INPUTS
%   x,y     : coordinates of the points (e.g. MUA.coordinates(:,1), (:,2))
%   B       : struct with the basin outlines, e.g. the content of
%             basins_IMBIE_v2.mat (data; can be obtained upon request from the author): B.x{i}, B.y{i} (column vectors with the
%             outline(s) of basin i, several loops separated by NaN, ending
%             with a NaN) and B.name{i} (name of basin i)
%   doplots : 1 to plot the basins and the points (default 0)
%
% OUTPUTS
%   basin   : struct array (one element per basin) with fields .ind (indices
%             of the points in this basin) and .name
%   ind     : vector (same size as x) with the basin number of each point
%
% REQUIRES
%   inpoly2 (Ua / Mesh2d); MATLAB dsearchn

%% detect basin for each coordinate pair
if nargin<4
    doplots=0;
end

%% 1. points inside the basin polygons
xtmp = x;
ytmp = y;
for ii=1:numel(B.x)
    Bx = B.x{ii};
    By = B.y{ii};
    basin(ii).ind = [];
    Inan = [0; find(isnan(Bx)); numel(Bx)];
    for jj=1:numel(Inan)-2
        basin(ii).ind = [basin(ii).ind; find(inpoly2([xtmp(:) ytmp(:)],...
            [Bx(Inan(jj)+1:Inan(jj+1)-1) By(Inan(jj)+1:Inan(jj+1)-1)]))];
    end
    % avoid counting double
    xtmp(basin(ii).ind) = 1e12;
    ytmp(basin(ii).ind) = 1e12;
end

%% 2. any remaining nodes are allocated to basin with nearest boundary
remaining = find(xtmp<1e12-eps);
PQ = [xtmp(remaining) ytmp(remaining)]; dist = [];
for ii=1:numel(B.x)
    P = [B.x{ii} B.y{ii}];
    [~,dist(ii,:)] = dsearchn(P,PQ);
end
[~,I] = min(dist,[],1);
   
%% group indices
ind = zeros(numel(x),1)+nan;
for ii=1:numel(B.x)
    basin(ii).ind = [basin(ii).ind; remaining(find(I==ii))];
    ind(basin(ii).ind(:)) = ii;
    basin(ii).name = B.name{ii};
end

%% optional plot
if doplots

    CM = parula(numel(B.x));
    I = randperm(numel(B.x));
    CM = CM(I,:);

    figure; hold on;
    for ii=1:numel(B.x)
        plot(B.x{ii},B.y{ii},'-k');
        plot(x(basin(ii).ind),y(basin(ii).ind),'o','markersize',1,'color',CM(ii,:));
    end

end

end
