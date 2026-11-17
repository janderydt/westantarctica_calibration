function B = RemoveIceRisesAndIslands(B,cutoff)
% RemoveIceRisesAndIslands  Remove small ice rises and islands from the basin outlines of the IMBIE basins.
%
% PURPOSE
%   The first entry of the basin structure B (the entry with the empty name, which holds the ice rises and
%   islands) consists of several closed outlines separated by NaN. Outlines with an area smaller than
%   cutoff are removed; only ice rises and islands larger than the cutoff are kept (the smaller ones are not
%   treated separately). If none is left, the first entry is removed from all fields of B.
%
% INPUT
%   B      : basin structure (content of basins_IMBIE_v2.mat) with the fields x, y (cell arrays with the outlines of
%            each entry, separated by NaN), name, x_center, y_center, area_km2
%   cutoff : minimum area in km^2 (default 250)
%
% OUTPUT
%   B      : the same structure with the small ice rises and islands removed
%
% NOTE: when the first entry is removed, the code assumes that B has 19 entries (the entry for the ice rises and
%   islands and 18 basins).

if nargin < 2
    cutoff = 250; %remove small ice rises and islands.
end

% Only keep ice rises and islands larger than 250km2. We don't treat
% smaller ice rises and/or islands seperately
Bx = B.x{1}; Bxtmp = [];
By = B.y{1}; Bytmp = [];
I = [0; find(isnan(Bx)); numel(Bx)+1];
for ii=1:numel(I)-1
    xtmp = Bx(I(ii)+1:I(ii+1)-1);
    ytmp = By(I(ii)+1:I(ii+1)-1);
    P = polyshape(xtmp(:),ytmp(:));
    A = area(P)/1e6; % square km
    if A>cutoff
        Bxtmp = [Bxtmp(:);xtmp(:);NaN];
        Bytmp = [Bytmp(:);ytmp(:);NaN];
    end
end
if isempty(Bxtmp)
    B.area_km2(1)=[];
    B.name=B.name(2:19);
    B.x_center(1)=[];
    B.x=B.x(2:19);
    B.y_center(1)=[];
    B.y=B.y(2:19);
else
    B.x{1} = Bxtmp;
    B.y{1} = Bytmp;
end
