function Create_Geometry_from_reference_and_ds(targettime,CreateGeotiff)
% Create_Geometry_from_reference_and_ds  Ice geometry for a given date.
%
% PURPOSE
%   Takes the reference geometry, a mosaic of BedMachine v3, Bedmap2,
%   Bamber 2009 and RAMP2 data, and applies a surface elevation correction ds
%   from ITS_LIVE, CPOM and Paolo et al. (2023) to obtain a geometry that is
%   representative for targettime (as configured in Calc_ITSLIVE_CPOM_Paolo2023_Deltas
%   only the Nilsson et al. grounded-ice data are used, i.e. no correction on ice shelves). The draft and mask are recalculated from the
%   new surface assuming hydrostatic equilibrium where the ice is floating.
%
% INPUTS
%   targettime    : datetime of the geometry (default datetime(2020,06,01))
%   CreateGeotiff : 1 (default) to also write GeoTiff files to ./GeoTiffFiles (must exist)
%   GriddedInterpolants_Bedmachinev3_Bedmap2_Bamber2009_RAMP2_RefGeometry.mat
%       (from Create_BMv3_B2_Bam2009_RAMP2_RefGeomGriddedInterpolants)
%
% OUTPUTS (current folder)
%   ds_Nilsson_Paolo_<targettime>.mat   : x, y, ds, ds_err, ds_source (cache; reused if present)
%   GriddedInterpolants_Geometry_<targettime>.mat : Fs, Fb, FB, Frho, Fmask
%
% REQUIRES (not part of this repository, see README)
%   Calc_ITSLIVE_CPOM_Paolo2023_Deltas, Calc_dh_from_ds (same folder)
%   MATLAB toolboxes: Image Processing (bwdist), Mapping (geotiffwrite, maprefcells)

if nargin==0
    targettime = datetime(2020,06,01); % format (YYYY,MM,DD)
    CreateGeotiff=1;
elseif nargin==1
    CreateGeotiff=1;
end

fprintf("Loading gridded interpolants for reference geometry...")

load('GriddedInterpolants_Bedmachinev3_Bedmap2_Bamber2009_RAMP2_RefGeometry');
FB_ref = FB; Fb_ref = Fb; Fmask_ref = Fmask; Frho_ref = Frho; Fs_ref = Fs; Fsource_ref = Fsource;

clear FB Fb Fmask Frho Fs Fsource;

fprintf("done.\n");

x = Fb_ref.GridVectors{1};
y = Fb_ref.GridVectors{2};
s = Fs_ref.Values;
B = FB_ref.Values;
rho = Frho_ref.Values;
mask = Fmask_ref.Values;

[X,Y] = ndgrid(x,y);

ds_file = "ds_Nilsson_Paolo_"+string(targettime)+".mat";

if ~exist(ds_file,"file")

    fprintf("Calculating surface correction.\n");

    source = Fsource_ref.Values;
    referencetime = datetime(2015,01,01)+0*X;
    referencetime(source==3) = datetime(1995,01,01); % Bedmap2: Griggs and Bamber for the ice shelves
    referencetime(source==4) = datetime(2004,01,01); % Bamber2009
    referencetime(source==5) = datetime(1990,01,01); % RAMP2 best guess
    
    [ds,ds_err,ds_source] = Calc_ITSLIVE_CPOM_Paolo2023_Deltas(X,Y,referencetime,targettime);    

    if CreateGeotiff
    
        fprintf('Writing GeoTiff files \n');
        
        R = maprefcells([x(1) x(end)],[y(1) y(end)],[numel(x),numel(y)]);
        geotiffwrite("./GeoTiffFiles/ds_"+string(targettime)+".tif",ds',R,'CoordRefSysCode','EPSG:3031');
        geotiffwrite("./GeoTiffFiles/ds_err_"+string(targettime)+".tif",ds_err',R,'CoordRefSysCode','EPSG:3031');
       
        fprintf('done.\n');

    end

    save(ds_file,"x","y","ds","ds_source","ds_err");

else
    
    fprintf("Loading existing surface correction for %s...",string(targettime));

    load(ds_file);

    fprintf('done.\n');

end

fprintf("Applying surface correction and calculating new draft and mask...");
% NOTE: masking ds with a TREND mask did not reduce noise, and removing ds with
% ds_err./ds>0.1 removed too many data points.
% remove ds with errors > 2.5m
ds(ds_err>2.5)=nan;

% replace nans with interpolated values if nearest non-nan is not more than 10km away
ind = ~isnan(ds);
Fds = scatteredInterpolant(X(ind),Y(ind),double(ds(ind)),'natural','none');
dx = X(2,1)-X(1,1);
ind = find((bwdist(~isnan(ds))*dx)<10e3);
ds(ind) = Fds(X(ind),Y(ind));
ds(isnan(ds) & mask~=0) = 0;
ds(mask==0)=nan;

% ds = s(referencetime) - s(targettime) (see Calc_ITSLIVE_CPOM_Paolo2023_Deltas), so subtract it.
s_new = s - ds; % subtract ds here because it is negative for thinning
rhow = 1027;

% remove negative surface
s_new(s_new<0)=0;

[b_new,h_new] = Calc_dh_from_ds(X,Y,s_new,B,rho,rhow);

% To avoid grounding along ice front margins, impose that any ice seaward of 
% BedmapMachine iceshelf mask is floating

%% Apply some checks and set mask
%  ocean/ice/land mask
%  0 = ocean
%  1 = ice-free land
%  2 = grounded
%  3 = floating ice 
mask_new = 0*X;
% no ice above sea level: ice-free land
mask_new(h_new==0 & B>0) = 1;
% draft below or equal to bed? grounded 
mask_new(b_new<=B) = 2; b_new(b_new<B)=B(b_new<B);
% draft non-zero and above bed? floating
mask_new(b_new~=0 & b_new>B) = 3;

fprintf('Done.\n');

%% Save interpolants
fprintf("Creating and saving gridded interpolants for modified geometry...");

% make sure all fields are doubles.
FB = griddedInterpolant(double(X),double(Y),double(B),'cubic');
Fb = FB; Fb.Values = double(b_new);
Fs = FB; Fs.Values = double(s_new);
Frho = FB; Frho.Values = double(rho);
Fmask = griddedInterpolant(double(X),double(Y),mask_new,'nearest');

save("GriddedInterpolants_Geometry_"+string(targettime),'Fs','Fb','FB','Frho','Fmask','-v7.3');

fprintf('done.\n')

%% Write Geotiff files
if CreateGeotiff
    
    fprintf("Writing GeoTiff files...");
    
    R = maprefcells([x(1) x(end)],[y(1) y(end)],[numel(x),numel(y)]);
    geotiffwrite("./GeoTiffFiles/ds_"+string(targettime)+".tif",ds',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/ds_err_"+string(targettime)+".tif",ds_err',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/surface_"+string(targettime)+".tif",s_new',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/draft_"+string(targettime)+".tif",b_new',R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/mask_"+string(targettime)+".tif",mask_new',R,'CoordRefSysCode','EPSG:3031');

    fprintf("Done.\n");

end

clear Fds FB Fb Fs Frho Fmask Fsource ds B mask referencetime rho s source ds_err s_new b_new mask_new 

end
