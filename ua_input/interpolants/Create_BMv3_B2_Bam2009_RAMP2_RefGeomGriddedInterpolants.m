function Create_BMv3_B2_Bam2009_RAMP2_RefGeomGriddedInterpolants(CreateGeotiff)
% Create_BMv3_B2_Bam2009_RAMP2_RefGeomGriddedInterpolants  Reference ice geometry
% (c. 2015) from BedMachine v3, Bedmap2, Bamber 2009 and RAMP2.
%
% PURPOSE
%   Creates a reference geometry for 2015 based on BedMachine v3 (or Bedmap3).
%   As this product is used as the reference for geometries of other years, the
%   ice front is extended beyond its current extent: in areas that were
%   previously ice covered (e.g. Larsen B), the thin ice of BedMachine is
%   replaced by thickness derived from the Bedmap2, Bamber 2009 and RAMP2
%   surfaces (assuming floatation), but the quality of those products near the
%   edges of ice shelves is generally poor. Alternatively (ExtrudeBedMachine=1)
%   BedMachine is extruded along flowlines.
%
% SWITCHES (top of the script)
%   ExtrudeBedMachine, Bed_UseBedMachine3 / Bed_UseBedmap3 (base geometry),
%   Surface_Use* (data sets used to fill gaps in surface elevation)
%
% INPUTS
%   CreateGeotiff : 1 (default) to also write GeoTiff files to ./GeoTiffFiles (must exist)
%   Data (not provided, see README), in the folders given by the environment
%   variables "froot_data" and "froot_tools":
%     $froot_data/BedMachine_Antarctica/BedMachineAntarctica-v3-PIGdig_PHolland.nc
%       (BedMachine v3 with a modified bed, 'bed_pigdig', provided by P. Holland:
%        identical to BMv3 except for some digging downstream of the PIG grounding line)
%     $froot_data/Bedmap2/bedmap2_tif, $froot_data/Bamber_SurfDEM_2004,
%     $froot_data/RAMP2/osu91a200m.tif
%
% OUTPUT (current folder)
%   GriddedInterpolants_Bedmachinev3_Bedmap2_Bamber2009_RAMP2_RefGeometry.mat :
%   Fs, Fb, FB, Frho, Fmask, Fsource. Fsource values: 1 BedMachine, 2 removed thin
%   floating strip, 3 Bedmap2, 4 Bamber 2009, 5 RAMP2, 6 interpolated.
%
% REQUIRES (not part of this repository, see README)
%   bedmap2_interp, read_Bamber_2004, geoimread; HeavisideApprox (Ua);
%   Create_ExtrudedFields_GriddedInterpolants (only if ExtrudeBedMachine=1)
%   MATLAB toolboxes: Image Processing (bwdist, bwlabel, regionfill),
%   Mapping (geotiffwrite, maprefcells)

ExtrudeBedMachine = 0;

% base geometry for the bed and surface
Bed_UseBedMachine3 = 1;
Bed_UseBedmap3 = 0;

% other data products to fill gaps in the surface elevation
Surface_UseBedMachine3 = 1;
Surface_UseBedmap2 = 1;
Surface_UseBamber2004 = 1;
Surface_UseRAMP2 = 1;

if nargin==0 
    CreateGeotiff = 1;
end

froot_data = getenv("froot_data");
addpath(getenv("froot_tools"));

%%% GEOMETRY
%% Read/process Bed data
if Bed_UseBedMachine3

    %ncfile = froot_data+"/BedMachine_Antarctica/BedMachineAntarctica-v3.nc";
    ncfile = froot_data+"/BedMachine_Antarctica/BedMachineAntarctica-v3-PIGdig_PHolland.nc";
    fprintf(" Reading bed data from file %s...",ncfile);

    % use the modified bed from P. Holland. This is identical to BMv3, except
    % for some digging downstream of the PIG grounding line
    bed = double(flip(ncread(ncfile,'bed_pigdig'),2));
    surface = double(flip(ncread(ncfile,'surface'),2));
    thickness = double(flip(ncread(ncfile,'thickness'),2));
    firn  = double(flip(ncread(ncfile,'firn'),2));
    mask  = double(flip(ncread(ncfile,'mask'),2));
    fprintf("Done.\n")
    
    % All heights are referenced to mean sea level using the geod EIGEN-6D4
    % To obtain height with respect to WGS84 add geoid:
    % Rema = Surface + Firn + Geoid
    % Surface=bed+thickness over the grounded areas
    % However this surface is not the REMA surface
    % So the actual surface (with respect to sea level) is: s = surface+firn
    %                                                       b=bed=surface-thickness=s-firn-thickness
    %                                           therefore   h=s-b=surface+firn-(surface-thickness)=firn+thickness
    %
    %  ocean/ice/land mask
    %  0 = ocean
    %  1 = ice-free land
    %  2 = grounded
    %  3 = floating ice 
    %  4 = Lake Vostok
    %
    % I'm assuming here that the user wants the variable s to be surface+firn, in which case the vertically averaged ice density must be
    % modfied accordingly.
    % 
    s_bm=surface+firn ;
    b_bm=surface-thickness ;
    h_bm=firn+thickness ; % or just h=s-b 
    bed_bm=bed ; 
    rhoi= 917 ; 
    rhow = 1027;
    rhoMin = 100; 
    %
    % The 'firn' field in the Bedmachine data is not the firn thickness, but
    % `firn air content'
    %
    % $$ \mathrm{firn} =  \frac{1}{\rho_i}  \int_{firn layer} (\rho_i - \rho_f) \, dz $$
    %
    % The firn air content has units of distance.
    %
    % \rho = (1-firn/h) \rho_i   where h is the total ice thickness (Ua definition).
    %
    %
    rho=(1-firn./(h_bm+eps)).*rhoi ;  % vertically averaged ice density over the deph h=s-b=firn+thicknes
    % Note: one would expect that the minimum value of rho would be equal to the firn density,
    %       but there are a number of values where rho=0, that is when firn=h. Not sure how this can happen
    %       when the ice thickness is larger than zero... Possibly some inconsistencies between the data sets providing air content (firn) and
    %       ice thickness. Note: firn is 'air content'

    bed_bm(mask==4)=b_bm(mask==4); % get rid of Lake Vostok by setting lower ice surface (b) equal to bedrock elevation (B) over the lake as defined my mask.
    mask(mask==4)=2;

elseif Bed_UseBedmap3

    ncfile = froot_data+"/Bedmap3/bedmap3.nc";

    bed = double(flip(ncread(ncfile,'bed_topography'),2));
    surface = double(flip(ncread(ncfile,'surface_topography'),2));
    thickness = double(flip(ncread(ncfile,'ice_thickness'),2));
    mask  = double(flip(ncread(ncfile,'mask'),2));

    error("need to define density for Bedmap3");

    %  ocean/ice/land mask
    % -9999: open ocean
    % 1: grounded
    % 2/3: transiently grounded and floating
    % 4: rock

    % use Bedmachine conventions: open ocean 0, rock 1, grounded 2,
    % floating 3
    mask(mask==-9999)=0; 
    mask(mask==4)=1;
    mask(mask==1)=2;
    mask(abs(surface-thickness-bed)>eps(1000) & mask==2)=3;

    fprintf("Done.\n")

end

%% DEfine Coordinates
x_bed = double(ncread(ncfile,'x'));
y_bed = double(ncread(ncfile,'y'));
x_bed = unique(x_bed);
y_bed = unique(y_bed);
[X_bed,Y_bed] = ndgrid(x_bed,y_bed);

%% Do some initial consistency checks
I=h_bm>0 ; 
fprintf('Over glaciated areas %f%% of densities are smaller than %f kg/m^3. These densities are set to %f kg/m^3. \n',...
    100*numel(find(rho(I)<rhoMin))/numel(find(I)),rhoMin,rhoMin);
I=h_bm>0 & rho<rhoMin ; rho(I)=rhoMin ; 
% perform some consistency checks
b_bm(mask==0)=0; s_bm(mask==0)=0; % ocean has zero ice draft and surface height
b_bm(mask==1)=bed_bm(mask==1); s_bm(mask==1)=bed_bm(mask==1); % ice-free land has ice draft and surface height equal to the bed height
b_bm(mask==2)=bed_bm(mask==2); % grounded ice has ice draft equal to bed height
mask_bm = mask;

grounded = ismember(mask_bm,[1 2 4]); 

source = zeros(size(h_bm),'uint8'); 
source(h_bm>0 | grounded) = 1; 

if CreateGeotiff
    
    fprintf('Writing origial Bed geometry GeoTiff files...');
    
    if Bed_UseBedmap3
        tag = "Bedmap3";
    elseif Bed_UseBedMachine3
        tag = "Bedmachine3";
    end
    R = maprefcells([x_bed(1) x_bed(end)],[y_bed(1) y_bed(end)],[numel(x_bed),numel(y_bed)]);
    geotiffwrite("./GeoTiffFiles/"+tag+"_bed",bed_bm',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/"+tag+"_mask",mask_bm',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/"+tag+"_icethickness",h_bm',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/"+tag+"_watercolumnthickness",bed_bm'-b_bm',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/"+tag+"_surface",s_bm',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/"+tag+"_draft",b_bm',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/"+tag+"_density",rho',R,'CoordRefSysCode','EPSG:3031');
     
    fprintf('Done.\n');

end

% Distance in kilometers to ocean data: 
D_ocean = bwdist(mask_bm==0); % euclidean distance to the nearest non-zero pixel
% narrow strips of floating ice with thin water column (<15m) exist along
% the ice front. Remove these by looking in a 1.5km strip along the open ocean
% for cells with mask_bm==3. Then set these cells to open ocean
D_grounded = bwdist(mask_bm==2);
I = D_ocean<1.5 & D_grounded<1.5 & mask_bm==3;% & b_bm-bed_bm<15;
b_bm(I) = 0; % ocean
mask_bm(I) = 0;
rho(I) = rhoi;
s_bm(I) = 0;
h_bm(I) = 0;

source(I) = 2; 

%% Now deal with surface data
s_bm3 = 0*X_bed+nan; s_b2 = s_bm3; s_bam = s_b2; s_ramp = s_b2;

if Surface_UseBedMachine3
    %% Load Bedmap2 surface
    fprintf('Adding BedMachine3 data...');
    addpath(froot_data+"/BedMachine_Antarctica/BedMachineAntarctica-v3.nc");

    s_bm3 = bedmap2_interp(X_bed,Y_bed,'surface');
    isn = ~(s_bm3>0);  
    s_bm3(isn) = bedmap2_interp(X_bed(isn),Y_bed(isn),'surface','nearest'); 
    s_b2(bwdist(~isfinite(s_b2))*.5<1) = NaN; % Eliminates 1 km perimeter to avoid narrow strip of bedmap2 data along edges
    fprintf('Done. \n');
else
    s_bm3 = nan*X_bed;
end

if Surface_UseBedmap2
    %% Load Bedmap2 surface
    fprintf('Adding Bedmap2 data...');
    addpath(froot_data+"/Bedmap2/bedmap2_tif");
    s_b2 = bedmap2_interp(X_bed,Y_bed,'surface');
    isn = ~(s_b2>0);  
    s_b2(isn) = bedmap2_interp(X_bed(isn),Y_bed(isn),'surface','nearest'); 
    s_b2(bwdist(~isfinite(s_b2))*.5<1) = NaN; % Eliminates 1 km perimeter to avoid narrow strip of bedmap2 data along edges
    fprintf('Done. \n');
else
    s_b2 = nan*X_bed;
end

if Surface_UseBamber2004
    %% Load Bamber2004 surface
    fprintf('Adding Bamber2004 data...');
    addpath(froot_data+"/Bamber_SurfDEM_2004");
    [~,~,s_bam] = read_Bamber_2004(X_bed,Y_bed,1);
    s_bam(bwdist(~isfinite(s_bam))*.5<5) = NaN; % Eliminates 10 km perimeter b/c drooping ice sheet edges in Bamber and RAMP dems
    fprintf('Done. \n');
else
    s_bam = nan*X_bed;
end

if Surface_UseRAMP2
    %% Load RAMP2 surface
    fprintf('Adding RAMP2 data...');
    [Iramp,xramp,yramp] = geoimread(froot_data+"/RAMP2/osu91a200m.tif"); % The OSU version of the file is referenced to the geoid whereas the RAM2_DEM.tif is referenced to wgs84. Use OSU.  
    Iramp = double(Iramp); 
    Iramp(Iramp==0) = NaN; % Convert zeros to NaN so interpolation won't produce thin ice shelf edges.  
    s_ramp = interp2(xramp,yramp,Iramp,X_bed,Y_bed); 
    s_ramp(bwdist(~isfinite(s_ramp))*.5<5) = NaN;  % Eliminates 10 km perimeter b/c drooping ice sheet edges in Bamber and RAMP dems
    fprintf('Done. \n');
else
    s_ramp = nan*X_bed;
end

if Surface_UseBedmap2 || Surface_UseBamber2004 || Surface_UseRAMP2
    %% convert surface elevation to thickness, assuming floatation
    % first do some adjustments to rho: remove all rho=917 for ocean cells, and
    % interpolate linearly from grounded/floating ice.
    Frho = scatteredInterpolant(X_bed(mask_bm~=0),Y_bed(mask_bm~=0),rho(mask_bm~=0),'natural');
    rho = Frho(X_bed,Y_bed);
    hydro = rhow./(rhow-rho);
    h_b2 = s_b2.*hydro;
    h_bam = s_bam.*hydro;
    h_ramp = s_ramp.*hydro;
    
    %% Prevent new grounding:
    h_max = -rhow./rho.*bed_bm; % maximum thickness that could exist at neutral buoyancy (no new grounding).
    h_b2(h_b2>h_max) = h_max(h_b2>h_max); 
    h_bam(h_bam>h_max) = h_max(h_bam>h_max); 
    h_ramp(h_ramp>h_max) = h_max(h_ramp>h_max); 
    
    % Eliminate negative thickness: 
    h_b2(h_b2<0) = nan; 
    h_bam(h_bam<0) = nan; 
    h_ramp(h_ramp<0) = nan;
    
    %% Combine surface heights 
    % Distance in kilometers to BedMachine ocean data: 
    D = bwdist(mask_bm==0)*0.5; % euclidean distance to the nearest non-zero pixel
    D_thresh_thinice = 10; % replace thin ice within 10 km of ocean (for example, where Mertz Glacier tongue broke off and is now thin on its end in the BedMachine data, overwrite that thin ice with the full thickness from Bedmap2.) 
    
    h_bm_adj = h_bm;
    % Start overwriting BedMachine: 
    source(h_bm_adj<(h_b2/2) & D<D_thresh_thinice & ~grounded) = 3; 
    h_bm_adj(source==3) = h_b2(source==3); 
    
    source(h_bm_adj<(h_bam/2) & D<D_thresh_thinice & ~grounded) = 4; 
    h_bm_adj(source==4) = h_bam(source==4); 
    
    I = find(h_bm_adj<(h_ramp/2) & D<D_thresh_thinice & ~grounded);
    % remove ramp2 data from FRISS region due to odd regrounding
    J = find(Y_bed(I)>840441 & Y_bed(I)<934255 & X_bed(I)>-1182106 & X_bed(I)<-970374); I(J)=[];
    source(I) = 5;
    h_bm_adj(source==5) = h_ramp(source==5); 
    
    h_bm_adj(h_bm_adj==0 & ~grounded) = nan;
    
    L = bwlabel(isnan(h_bm_adj)); 
    h_bm_adj = regionfill(h_bm_adj,L>1);
    source(L>1) = 6; % interpolated
end

if ExtrudeBedMachine

    % We will extrude floating ice along flowlines. To know the ice
    % thickness, we need to extrude surface elevation and ice density.

    % Temporarily create and save interpolants
    Fs = griddedInterpolant(X_bed,Y_bed,s_bm,'cubic');
    Fb = Fs; Fb.Values = b_bm; 
    FB = Fs; FB.Values = bed_bm;
    Frho = Fs; Frho.Values = rho;
    Fmask = Fs; Fmask.Values = mask_bm;

    Velinterpolantfile = "./GriddedInterpolants_2015-2016_MeaSUREs_ITSLIVE_Velocities.mat";
    Geominterpolantfile =  "BMv3_tmp.mat"; save(Geominterpolantfile,"Fs","Fb","FB","Frho","Fmask","-v7.3");
    ScalarInterpolant = [];
    fields_to_extrude = "-geom-";
    Create_ExtrudedFields_GriddedInterpolants(Velinterpolantfile,Geominterpolantfile,ScalarInterpolant,0,fields_to_extrude);

    load(Geominterpolantfile+"_EXTRUDED.mat","Fs","Fb","Frho");
    s_bm = Fs.Values;
    rho_bm = Frho.Values;

    bfloat = s_bm.*(rho_bm./(rho_bm-rhow));
    b_bm = max(bfloat,bed_bm);
    h_bm_adj = s_bm - b_bm;

end

% Calculate s and b from h and B
S = 0*X_bed;
hf=rhow.*(0*S-bed_bm)./rho;
GF = HeavisideApprox(100,h_bm-hf,1); % 1 if grounded, 0 if afloat;
bfloat=S-rho.*h_bm_adj./rhow;
b_bm_adj=GF.*bed_bm + (1-GF) .* bfloat ;

% Enforce b Above B
% because the grounding line is `smeared out' a bit for a finite CtrlVar.kH one can
% have situations where b<B. For CtrlVar.kH>0.1 this is not really much of an issue
% and anyhow this is a direct consequence of using a smooth step function (explained in detail in UaCompendium)
I=b_bm_adj<bed_bm ; b_bm_adj(I)=bed_bm(I);
s_bm_adj=b_bm_adj+h_bm_adj;

% To avoid grounding along ice front margins, impose that any ice seaward of 
% BedmapMachine iceshelf mask is floating
I = find(b_bm_adj<=bed_bm & mask_bm==0);
b_bm_adj(I) = bed_bm(I) + 10;
% recalculate s and h
s_bm_adj(I) = b_bm_adj(I).*(rho(I)-rhow)./rho(I);
h_bm_adj(I) = s_bm_adj(I) - b_bm_adj(I);

mask_bm_adj = 0*X_bed;
%  ocean/ice/land mask
%  0 = ocean
%  1 = ice-free land
%  2 = grounded
%  3 = floating ice 
%  4 = Lake Vostok
mask_bm_adj(mask_bm==1)=1;
mask_bm_adj(mask_bm==4)=4;
mask_bm_adj(b_bm_adj==bed_bm)=2;
mask_bm_adj(b_bm_adj>bed_bm)=3;

if CreateGeotiff
    
    fprintf('Writing GeoTiff files for new geometry...');
    
    R = maprefcells([x_bed(1) x_bed(end)],[y_bed(1) y_bed(end)],[numel(x_bed),numel(y_bed)]);
    geotiffwrite("./GeoTiffFiles/Bedmachinev3_Bedmap2_Bamber2009_RAMP2_mask",mask_bm_adj',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/Bedmachinev3_Bedmap2_Bamber2009_RAMP2_icethickness",h_bm_adj',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/Bedmachinev3_Bedmap2_Bamber2009_RAMP2_watercolumnthickness",bed_bm'-b_bm_adj',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/Bedmachinev3_Bedmap2_Bamber2009_RAMP2_surface",s_bm_adj',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/Bedmachinev3_Bedmap2_Bamber2009_RAMP2_draft",b_bm_adj',R,'CoordRefSysCode','EPSG:3031');      
    geotiffwrite("./GeoTiffFiles/Bedmap2_surface",s_b2',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/Bamber2004_surface",s_bam',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/RAMP2_surface",s_ramp',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/Bedmachinev3_Bedmap2_Bamber2009_RAMP2_source",source',R,'CoordRefSysCode','EPSG:3031');
   
    
    fprintf('Done.\n');

end

%% create gridded interpolants
fprintf(' Creating gridded interpolants for unmodified Bedmachine...')

FB = griddedInterpolant(X_bed,Y_bed,bed_bm,'cubic');
Fs = griddedInterpolant(X_bed,Y_bed,s_bm_adj,'cubic');
Fb = griddedInterpolant(X_bed,Y_bed,b_bm_adj,'cubic');
Frho = griddedInterpolant(X_bed,Y_bed,rho,'cubic'); 
Fmask = griddedInterpolant(X_bed,Y_bed,mask_bm_adj,'nearest');
Fsource = griddedInterpolant(X_bed,Y_bed,single(source),'nearest');

fprintf('done.\n')

fprintf(' Saving BedMachineGriddedInterpolants with Fs, Fb, FB, Frho, Fsource and Fmask. \n');

save('GriddedInterpolants_Bedmachinev3_Bedmap2_Bamber2009_RAMP2_RefGeometry','Fs','Fb','FB','Frho','Fmask','Fsource','-v7.3');

fprintf('done.\n')
