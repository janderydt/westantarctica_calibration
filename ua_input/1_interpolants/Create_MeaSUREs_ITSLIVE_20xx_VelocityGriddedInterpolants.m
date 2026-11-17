function Create_MeaSUREs_ITSLIVE_20xx_VelocityGriddedInterpolants(year,CreateGeotiff)
% Create_MeaSUREs_ITSLIVE_20xx_VelocityGriddedInterpolants  Velocity mosaic for
% a given year from MEaSUREs and ITS_LIVE.
%
% PURPOSE
%   Creates gridded interpolants of surface velocity for the year 20xx to
%   20xx+1 from a combination of MEaSUREs and ITS_LIVE data, with gaps filled
%   by mosaics that span multiple years. Data with a relative error larger
%   than relative_error_cutoff are removed at each step.
%     step 1: MEaSUREs annual 20xx-20xx+1 and ITS_LIVE annual 20xx, combined
%             as an error-weighted average
%     step 2: gaps filled with the MEaSUREs 450m v2 and ITS_LIVE 240m mosaics
%     step 3: remaining gaps filled with MEaSUREs Central Antarctica (1997)
%
% INPUTS
%   year          : start year (default 2019)
%   CreateGeotiff : 1 (default) to also write GeoTiff files to ./GeoTiffFiles (must exist)
%   Public data (to be downloaded from the original sources, see README), in the folder /path/to/data
%   (variable froot_data at the start of the script):
%     $froot_data/Measures/Measures_annual, $froot_data/ITS_LIVE/velocities,
%     $froot_data/Measures/Measures_v2/antarctica_ice_velocity_450m_v2.nc,
%     $froot_data/Measures/Measures_CentralAntarctica/1997/Central_Antarctica_ice_velocity_1997.nc
%
% OUTPUT (current folder)
%   GriddedInterpolants_<year>-<year+1>_MeaSUREs_ITSLIVE_Velocities.mat :
%   Fus, Fvs (velocity components), Fxerr, Fyerr (errors), Fsource (data source index)
%
% REQUIRES (not part of this repository, see README)
%   measures_annual, itslive_annual (reader functions; must be on the MATLAB path)
%   MATLAB Mapping Toolbox (geotiffwrite, maprefcells)

froot_data = "/path/to/data";

%% Settings and paths
relative_error_cutoff = 1; % ERR_V./V

if nargin==0
    year = 2019;
end

if nargin<2
    CreateGeotiff = 1;
end

%% STEP1
% Load MeaSUREs annual data
fprintf("Reading MeaSUREs velocity data for %s-%s",string(year),string(year+1));
try
    [vxm,x,y] = measures_annual('vx',[num2str(year),'_',num2str(year+1)]);
    vym = measures_annual('vy',[num2str(year),'_',num2str(year+1)]);
    xerrm = measures_annual('vxerr',[num2str(year),'_',num2str(year+1)]); xerrm(isnan(xerrm))=0; % change nan to zero for calculation of  total error.
    yerrm = measures_annual('vyerr',[num2str(year),'_',num2str(year+1)]); yerrm(isnan(yerrm))=0; % change nan to zero for calculation of  total error.
    vm = hypot(vxm,vym);
    errm = hypot(xerrm,yerrm);% propagation of error
    wm = 1./errm.^2; % weights
catch
    [~,x,y] = measures_annual('vx','2000_2001');
    vxm = 0*x+eps(0);
    vym = 0*x+eps(0);
    xerrm = 0*x + 1e10;
    yerrm = 0*x + 1e10;
    errm = 0*x + 1e10;
    wm = 0*x;
end

[X,Y] = ndgrid(x,y);
    
fprintf("...done.\n")

badm = errm./hypot(vxm,vym)>relative_error_cutoff;
vxm(badm) = nan; vym(badm) = nan; 

% Load ITSLIVE annual data
fprintf("Reading ITSLIVE velocity data for %s",string(year));
vxi = itslive_annual('vx',num2str(year),X,Y);
vyi = itslive_annual('vy',num2str(year),X,Y);
xerri = itslive_annual('vxerr',num2str(year),X,Y); xerri(isnan(xerri)) = 0;
yerri = itslive_annual('vyerr',num2str(year),X,Y); yerri(isnan(yerri)) = 0;
vi = hypot(vxi,vyi);
erri = hypot(xerri,yerri);% propagation of error for velocity v = sqrt(vx^2+vy^2)
wi = 1./erri.^2; % weights
    
fprintf("...done.\n")

badi = erri./hypot(vxi,vyi)>relative_error_cutoff;
vxi(badi) = nan; vyi(badi) = nan; 
% Indices of missing data: 
indm = ~isfinite(vxm) | ~isfinite(vym) | ~isfinite(wm); 
vxm(indm) = 0; 
vym(indm) = 0; 
wm(indm) = 0; 
indi = ~isfinite(vxi) | ~isfinite(vyi) | ~isfinite(wi); 
vxi(indi) = 0; 
vyi(indi) = 0; 
wi(indi) = 0;

% Weighted mean velocity components: 
vx = (vxi.*wi + vxm.*wm)./(wi + wm + eps); 
vy = (vyi.*wi + vym.*wm)./(wi + wm + eps); 
xerr = hypot(xerri.*wi,xerrm.*wm)./(wi + wm + eps);
yerr = hypot(yerri.*wi,yerrm.*wm)./(wi + wm + eps);

% Replace the completely unknown values with NaNs: 
vx(indi & indm) = nan; 
vy(indi & indm) = nan; 
xerr(indi & indm) = nan;
yerr(indi & indm) = nan;

vx = double(vx); 
vy = double(vy); 
xerr = double(xerr);
yerr = double(yerr);

source_count = 1;
v_source = zeros(size(vx),'uint8');
v_source(~indi & indm) = source_count; % ITS_LIVE
v_source(indi & ~indm) = source_count+1; % Measures v2
v_source(~indi & ~indm) = source_count+2; % Blend of ITS_LIVE and MEasures 
v_source_string(source_count) =  string(source_count)+": ITS_LIVE Antarctica annual "+string(year);
v_source_string(source_count+1) =  string(source_count+1)+": MeaSUREs Antarctica annual "+string(year)+"-"+string(year+1);
v_source_string(source_count+2) =  string(source_count+2)+": Blend of ITS_LIVE and MeaSUREs Antarctica annual "+string(year)+"-"+string(year+1);
source_count = source_count + 3;

nanind = isnan(vx);

%% STEP2
% MeaSUREs mosaic data
ncfile = froot_data+"/Measures/Measures_v2/antarctica_ice_velocity_450m_v2.nc";
fprintf("Reading Velocity data from MeaSURES 450m v2");

xtmp = double(ncread(ncfile,'x'));
ytmp = double(ncread(ncfile,'y'));
ytmp = flip(ytmp,1);
[Xtmp,Ytmp] = ndgrid(xtmp,ytmp);
xerrtmp = ncread(ncfile,'ERRX'); xerrtmp = flip(xerrtmp,2);
yerrtmp = ncread(ncfile,'ERRY'); yerrtmp = flip(yerrtmp,2);
vxtmp = ncread(ncfile,'VX'); vxtmp = flip(vxtmp,2);
vytmp = ncread(ncfile,'VY'); vytmp = flip(vytmp,2);
Fvx = griddedInterpolant(Xtmp,Ytmp,vxtmp,'cubic','none');
Fvy = griddedInterpolant(Xtmp,Ytmp,vytmp,'cubic','none');
Fxerr = griddedInterpolant(Xtmp,Ytmp,xerrtmp,'cubic','none');
Fyerr = griddedInterpolant(Xtmp,Ytmp,yerrtmp,'cubic','none');
            
vxm = Fvx(X,Y);
vym = Fvy(X,Y);
xerrm = Fxerr(X,Y); xerrm(isnan(xerrm))=0; % replace nans by 0 for calculation of total error 
yerrm = Fyerr(X,Y); yerrm(isnan(yerrm))=0; % replace nans by 0 for calculation of total error 

vm = hypot(vxm,vym);
errm = hypot(xerrm,yerrm);% propagation of error for velocity v = sqrt(vx^2+vy^2)
wm = 1./errm.^2;

vxm(errm./vm>relative_error_cutoff) = nan;
vym(errm./vm>relative_error_cutoff) = nan;

fprintf("...done.\n");

% Load ITSLIVE data
fprintf("Processing ITS_LIVE 240m data");

vxi = 0*X + itslive_annual('vx',"0000",X,Y);
vyi = 0*X + itslive_annual('vy',"0000",X,Y);
xerri = 0*X + itslive_annual('vxerr',"0000",X,Y); xerri(isnan(xerri)) = 0;
yerri = 0*X + itslive_annual('vyerr',"0000",X,Y); yerri(isnan(yerri)) = 0;
vi = hypot(vxi,vyi);
erri = hypot(xerri,yerri);% propagation of error for velocity v = sqrt(vx^2+vy^2)
wi = 1./erri.^2; % weights

vxi(erri./vi>relative_error_cutoff) = nan;
vyi(erri./vi>relative_error_cutoff) = nan;

fprintf("...done.\n")

% Indices of missing data: 
indm = ~isfinite(vxm) | ~isfinite(vym) | ~isfinite(wm); 
vxm(indm) = 0; 
vym(indm) = 0; 
wm(indm) = 0; 
indi = ~isfinite(vxi) | ~isfinite(vyi) | ~isfinite(wi); 
vxi(indi) = 0; 
vyi(indi) = 0; 
wi(indi) = 0;

% Weighted mean velocity components: 
vxtmp = (vxi.*wi + vxm.*wm)./(wi + wm + eps); 
vytmp = (vyi.*wi + vym.*wm)./(wi + wm + eps); 
xerrtmp = hypot(xerri.*wi,xerrm.*wm)./(wi + wm + eps);
yerrtmp = hypot(yerri.*wi,yerrm.*wm)./(wi + wm + eps);

% Replace the completely unknown values with NaNs: 
vxtmp(indi & indm) = nan; 
vytmp(indi & indm) = nan; 
xerrtmp(indi & indm) = nan;
yerrtmp(indi & indm) = nan;

vxtmp = double(vxtmp); 
vytmp = double(vytmp); 
xerrtmp = double(xerrtmp);
yerrtmp = double(yerrtmp);

% Now add to final datasets
vx(nanind) = vxtmp(nanind);
vy(nanind) = vytmp(nanind);
xerr(nanind) = xerrtmp(nanind);
yerr(nanind) = yerrtmp(nanind);

v_source(~indi & indm & nanind) = source_count; % ITS_LIVE
fprintf("   > added %s data points from ITS_LIVE 240m mosaic.\n",string(numel(find(~indi & indm & nanind))));
v_source(indi & ~indm & nanind) = source_count+1; % Measures v2
fprintf("   > added %s data points from Measures 450m v2 mosaic.\n",string(numel(find(indi & ~indm & nanind))));
v_source(~indi & ~indm & nanind) = source_count+2; % Blend of ITS_LIVE and MEasures 
fprintf("   > added %s data points from ITS_LIVE + Measures mosaic.\n",string(numel(find(~indi & ~indm & nanind))));
v_source_string(source_count) =  string(source_count)+": ITS_LIVE Antarctica 240m mosaic ";
v_source_string(source_count+1) =  string(source_count+1)+": MeaSUREs Antarctica 450m v2 mosaic";
v_source_string(source_count+2) =  string(source_count+2)+": Blend of ITS_LIVE 240m and MeaSUREs 450m v2 mosaics";
source_count = source_count+3;

nanind = isnan(vx);

%% STEP3
% Fill gaps with MeaSUREs data Central Antarctica
ncfile = froot_data+"/Measures/Measures_CentralAntarctica/1997/Central_Antarctica_ice_velocity_1997.nc";
fprintf("Reading Velocity data from MeaSURES Central Antarctia");

nx = double(ncreadatt(ncfile,'/','nx')); ny = double(ncreadatt(ncfile,'/','ny'));
xmin = str2double(erase(ncreadatt(ncfile,'/','xmin'),[" ","m"])); ymax = str2double(erase(ncreadatt(ncfile,'/','ymax'),[" ","m"]));
dl = str2double(erase(ncreadatt(ncfile,'/','spacing'),[" ","m"]));
xtmp = double([xmin:dl:xmin+(nx-1)*dl]);
ytmp = double([ymax-(ny-1)*dl:dl:ymax]);
[Xtmp,Ytmp] = ndgrid(xtmp,ytmp);
errtmp = double(ncread(ncfile,'err')); errtmp = flip(errtmp,2);
errtmp(errtmp==0) = nan;
vxtmp = double(ncread(ncfile,'vx')); vxtmp = flip(vxtmp,2);
vxtmp(vxtmp==0) = nan;
vytmp = double(ncread(ncfile,'vy')); vytmp = flip(vytmp,2);
vytmp(vytmp==0) = nan;
Fvx = griddedInterpolant(Xtmp,Ytmp,vxtmp,'cubic','none');
Fvy = griddedInterpolant(Xtmp,Ytmp,vytmp,'cubic','none');
Ferr = griddedInterpolant(Xtmp,Ytmp,errtmp,'cubic','none');
            
vxm = Fvx(X,Y);
vym = Fvy(X,Y);
xerrm = Ferr(X,Y); xerrm(isnan(xerrm))=0; % replace nans by 0 for calculation of total error 
yerrm = xerrm; 

vm = hypot(vxm,vym);
errm = hypot(xerrm,yerrm);% propagation of error for velocity v = sqrt(vx^2+vy^2)
wm = 1./errm.^2;

vxm(errm./vm>relative_error_cutoff) = nan;
vym(errm./vm>relative_error_cutoff) = nan;

fprintf("...done.\n");

% Indices of missing data: 
indm = ~isfinite(vxm) | ~isfinite(vym) | ~isfinite(wm); 
vxm(indm) = nan; 
vym(indm) = nan; 
xerrm(indm) = nan;
yerrm(indm) = nan;

vxm = double(vxm);
vym = double(vym); 
xerrm = double(xerrm);
yerrm = double(yerrm);

% Now add to final datasets
vx(nanind) = vxm(nanind);
vy(nanind) = vym(nanind);
xerr(nanind) = xerrm(nanind);
yerr(nanind) = yerrm(nanind);

v_source(~indm & nanind) = source_count; % ITS_LIVE
fprintf("   > added %s data points from MeaSURES Central Antarctica 1997.\n",string(numel(find(~indm & nanind))));
v_source_string(source_count) =  string(source_count)+": MeaSURES Central Antarctica 1997";
source_count = source_count+1;

nanind = isnan(vx);

if CreateGeotiff
    
    fprintf('Writing GeoTiff files \n');
    
    R = maprefcells([x(1) x(end)],[y(end) y(1)],[numel(x),numel(y)]);
    geotiffwrite("./GeoTiffFiles/AntarcticVelocity_"+string(year)+"-"+string(year+1)+"_MeaSUREs_ITSLIVE_vx.tif",flip(vx',1),R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/AntarcticVelocity_"+string(year)+"-"+string(year+1)+"_MeaSUREs_ITSLIVE_vy.tif",flip(vy',1),R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/AntarcticVelocity_"+string(year)+"-"+string(year+1)+"_MeaSUREs_ITSLIVE_xerr.tif",flip(xerr',1),R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/AntarcticVelocity_"+string(year)+"-"+string(year+1)+"_MeaSUREs_ITSLIVE_yerr.tif",flip(yerr',1),R,'CoordRefSysCode','EPSG:3031');
    v = hypot(vx,vy); err = hypot(xerr,yerr);
    geotiffwrite("./GeoTiffFiles/AntarcticVelocity_"+string(year)+"-"+string(year+1)+"_MeaSUREs_ITSLIVE_err.tif",flip(err',1),R,'CoordRefSysCode','EPSG:3031');
    geotiffwrite("./GeoTiffFiles/AntarcticVelocity_"+string(year)+"-"+string(year+1)+"_MeaSUREs_ITSLIVE_source.tif",flip(v_source',1),R,'CoordRefSysCode','EPSG:3031');

    fprintf('Done.\n');

end

fprintf(' Creating gridded interpolants...');

y = flip(y,1);
[X,Y] = ndgrid(x,y);

Fus = griddedInterpolant(X,Y,flip(vx,2),'linear');
Fvs = griddedInterpolant(X,Y,flip(vy,2),'linear');
Fxerr = griddedInterpolant(X,Y,flip(xerr,2),'linear');
Fyerr = griddedInterpolant(X,Y,flip(yerr,2),'linear');
Fsource = griddedInterpolant(X,Y,flip(double(v_source),2),'nearest');

fprintf('done.\n')

fprintf(' Saving VelocityInterpolants with Fus, Fvs, Fxerr, Fyerr. \n')
save("GriddedInterpolants_"+string(year)+"-"+string(year+1)+"_MeaSUREs_ITSLIVE_Velocities",'Fus','Fvs','Fxerr','Fsource','Fyerr','-v7.3');
