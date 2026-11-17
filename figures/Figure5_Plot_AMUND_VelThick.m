function Figure5_Plot_AMUND_VelThick
% Figure5_Plot_AMUND_VelThick  Figure 5: AMUND data and the changes used in the calibration.
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Needs the results of diagnostic and inverse experiments of the ensemble (these data can be obtained upon request from the author).
%
% PURPOSE
%   (a-c) ice speed, ice thickness and dh/dt in 2000; (d-f) change in ice thickness between 2000 and 2009, 2014, 2020
%   (diagnostic experiments with the new geometry, minus 2000); (g-i) observed changes in speed between 2000 and 2009, 2014,
%   2020 (loadvelocitydata); (j-l) modelled (Ua, from the diagnostic experiments) and observed (InSAR / ESA) grounding lines
%   of Pine Island, Thwaites and Dotson / Crosson in 1996-2022. Saves ./Figure5.png.
%   The Ua results are the diagnostic experiments with the experiment numbers runID_* and the inversion with number
%   runID_dhdt2000 (cycle 2: dhdt measurements).
%
% DATA (the model results can be obtained upon request from the author)
%   Diagnostic results /path/to/diagnostic_cases/AMUND_nsmbl/..., inversion results
%   /path/to/inverse_cases/AMUND_nsmbl/..., observed velocities (loadvelocitydata), grounding lines in
%   /path/to/data/GroundingLine and /AmundsenSea (MEaSUREs InSAR v2, Milillo et al. Thwaites 2016-2017, Pope/Smith/Kohler Dotson
%   and Crosson, Ross et al. COSMO-SkyMed 2020-2022, ESA CCI GL v2)
%
% REQUIRES
%   Ua source code, loadvelocitydata (analysis/bayesian_inference); cmocean, fig, ll2psxy (third party),
%   PlotNodalBasedQuantities_JDR; MATLAB Mapping Toolbox (shaperead)

froot_data = "/path/to/data";

%% GATHER DATA FOR 2000
% ice thickness and surface 2000
% experiment numbers of the diagnostic and inverse experiments used
runID_2000 = 23816;
files = dir("/path/to/diagnostic_cases/AMUND_nsmbl/AMUND_nsmbl_Diagnostic_"+string(runID_2000)+"/ResultsFiles/*.mat");
out = load(files.folder+"/"+files.name);
h2000 = out.F.h;
Fh2000 = scatteredInterpolant(out.MUA.coordinates(:,1),out.MUA.coordinates(:,2),h2000);
s2000 = out.F.s;

% velocity 2000
out = loadvelocitydata("AMUND","u","2000",1);
u2000 = out.("yr2000").u;
std2000 = out.("yr2000").stdu;
u2000(isnan(std2000))=nan;
MUA2000 = out.yr2000.MUA;
GF2000 = out.yr2000.GF;

% dh/dt 2000
runID_dhdt2000 = 20032;
files = dir("/path/to/inverse_cases/AMUND_nsmbl/AMUND_nsmbl_Inverse_"+string(runID_dhdt2000)+"/*InverseCycle2.mat");
out = load(files.folder+"/"+files.name,"Meas","F");
dhdt2000 = out.Meas.dhdt;
dhdt2000(out.F.GF.node==0 | dhdt2000==0)=nan;

%% GATHER GEOMETRY DATA FOR SECOND STEP
% \delta h 2009
runID_2009 = 32967;
files = dir("/path/to/diagnostic_cases/AMUND_nsmbl/AMUND_nsmbl_Diagnostic_"+string(runID_2009)+"/ResultsFiles/*.mat");
out = load(files.folder+"/"+files.name);
h2009 = out.F.h;
h2000_tmp = Fh2000(out.MUA.coordinates(:,1),out.MUA.coordinates(:,2));
Ind = find(~inpoly([out.MUA.Boundary.x(:) out.MUA.Boundary.y(:)],[MUA2000.Boundary.x(:) MUA2000.Boundary.y(:)]));
h2000_tmp(Ind) = 0;
dh2000_2009 = h2009 - h2000_tmp;
MUA2009_withIS = out.MUA;
GF2009_withIS = out.F.GF;

% \delta h 2014
runID_2014 = 41220;
files = dir("/path/to/diagnostic_cases/AMUND_nsmbl/AMUND_nsmbl_Diagnostic_"+string(runID_2014)+"/ResultsFiles/*.mat");
out = load(files.folder+"/"+files.name);
h2014 = out.F.h;
h2000_tmp = Fh2000(out.MUA.coordinates(:,1),out.MUA.coordinates(:,2));
Ind = find(~inpoly([out.MUA.Boundary.x(:) out.MUA.Boundary.y(:)],[MUA2000.Boundary.x(:) MUA2000.Boundary.y(:)]));
h2000(Ind) = 0;
dh2000_2014 = h2014 - h2000_tmp;
MUA2014_withIS = out.MUA;
GF2014_withIS = out.F.GF;

% \delta h 2020
runID_2020 = 25107;
files = dir("/path/to/diagnostic_cases/AMUND_nsmbl/AMUND_nsmbl_Diagnostic_"+string(runID_2020)+"/ResultsFiles/*.mat");
out = load(files.folder+"/"+files.name);
h2020 = out.F.h;
h2000_tmp = Fh2000(out.MUA.coordinates(:,1),out.MUA.coordinates(:,2));
Ind = find(~inpoly([out.MUA.Boundary.x(:) out.MUA.Boundary.y(:)],[MUA2000.Boundary.x(:) MUA2000.Boundary.y(:)]));
h2000_tmp(Ind) = 0;
dh2000_2020 = h2020 - h2000_tmp;
MUA2020_withIS = out.MUA;
GF2020_withIS = out.F.GF;

%% GATHER VELOCITY DATA FOR THIRD STEP
% \delta u 2009
out = loadvelocitydata("AMUND","du","2000-2009",1);
du2000_2009 = out.("yr2000_yr2009").du;
stddu2000_2009 = out.("yr2000_yr2009").stddu;
MUA2009 = out.yr2009.MUA;
GF2009 = out.yr2009.GF;
du2000_2009(GF2009.node==0 | stddu2000_2009==1e3)=nan;

% \delta u 2014
out = loadvelocitydata("AMUND","du","2000-2014",1);
du2000_2014 = out.("yr2000_yr2014").du;
stddu2000_2014 = out.("yr2000_yr2014").stddu;
MUA2014 = out.yr2014.MUA;
GF2014 = out.yr2014.GF;
du2000_2014(GF2014.node==0 | stddu2000_2014==1e3)=nan;

% \delta u 2020
out = loadvelocitydata("AMUND","du","2000-2020",1);
du2000_2020 = out.("yr2000_yr2020").du;
stddu2000_2020 = out.("yr2000_yr2020").stddu;
MUA2020 = out.yr2020.MUA;
GF2020 = out.yr2020.GF;
du2000_2020(GF2020.node==0 | stddu2000_2020==1e3)=nan;

%% GATHER GROUNDING LINE DATA
% observed GL
S_insar = shaperead(froot_data+"/GroundingLine/MEaSUREs_INSAR_v2/InSAR_GL_Antarctica_v02.shp");
S_insar_mililloTW = shaperead(froot_data+"/AmundsenSea/Milillo_GL_Thwaites/Thwaites_2016-2017.shp");
S_insar_mililloDC = shaperead(froot_data+"/AmundsenSea/Milillo_GL_CrossonDotson/Grounding_Lines_CSK_Pope_Smith_Kohler.shp");
S_insar_ross = shaperead(froot_data+"/GroundingLine/Rossetal_COSMO-Skymet_2025/grounding_lines/CSK_grounding_lines_2020-2022_v0.1.shp");
S_ESA = shaperead(froot_data+"/GroundingLine/ESA_DLR_1994-2020_v2/20210305000000_AIS_CCI_GLL.2.0_20210305.shp");

kk=1;
for jj=1:length(S_insar)
    year = str2double(S_insar(jj).DATE1(1:4));
    ind = 26-(2022-year); ind(ind<1)=1; ind(ind>26)=26;
    S_insar(kk).ind = ind;
    [S_insar(kk).x,S_insar(kk).y] = ll2psxy(S_insar(jj).Y,S_insar(jj).X,-71,0);
    kk=kk+1;
end
for ii=1:length(S_insar_mililloTW)
    year = str2double(S_insar_mililloTW(ii).MASTER1(1:4));
    
    ind = 26-(2022-year); ind(ind<1)=1; ind(ind>26)=26;
    S_insar(kk).ind = ind;
    S_insar(kk).x = S_insar_mililloTW(ii).X;
    S_insar(kk).y = S_insar_mililloTW(ii).Y;
    kk=kk+1;
end
for ii=1:length(S_insar_mililloDC)
    year = round(S_insar_mililloDC(ii).Date1/1e4);
    ind = 26-(2022-year); ind(ind<1)=1; ind(ind>26)=26;
    S_insar(kk).ind = ind;
    S_insar(kk).x = S_insar_mililloDC(ii).X; 
    S_insar(kk).y = S_insar_mililloDC(ii).Y;
    kk=kk+1;
end
for ii=1:length(S_insar_ross)
    year = round(S_insar_ross(ii).Primary1/1e4);
    ind = 26-(2022-year); ind(ind<1)=1; ind(ind>26)=26;
    S_insar(kk).ind = ind;
    S_insar(kk).x = S_insar_ross(ii).X;  
    S_insar(kk).y = S_insar_ross(ii).Y;
    kk=kk+1;
end
for ii=1:length(S_ESA)
    year = str2double(S_ESA(ii).T1(1:4));
    ind = 26-(2022-year); ind(ind<1)=1; ind(ind>26)=26;
    S_insar(kk).ind = ind;
    S_insar(kk).x = S_ESA(ii).X;
    S_insar(kk).y = S_ESA(ii).Y;
    kk=kk+1;
end

% model GL
runID = ["23816","32967","41220","25107"]; 
years = [2000,2009,2014,2020];
for ii = 1:numel(runID)
    files(ii) = dir("/path/to/diagnostic_cases/AMUND_nsmbl/AMUND_nsmbl_Diagnostic_"+runID(ii)+"/ResultsFiles/*.mat");
    load(files(ii).folder+"/"+files(ii).name,"F","MUA","CtrlVar");
    CtrlVar.PlotGLs=0;
    [S_ua(ii).x,S_ua(ii).y]=PlotGroundingLines(CtrlVar,MUA,F.GF);
    ind = 26-(2022-years(ii)); ind(ind<1)=1; ind(ind>26)=26;
    S_ua(ii).ind = ind;
end

%% PLOTTING
% speed
CMu = cmocean('matter',32);
CMdu = cmocean('dense',32);
% ice thickness
CMh = flipud(cmocean('ice',32));
CMdh = flipud(cmocean('balance',64));
% dhdt
CMdhdt = flipud(cmocean('balance',32));
CMgl = cmocean('thermal',28); % 1996 - 2022
CMgl = CMgl(1:26,:);

%-------
H=fig('units','inches','width',60*12/72.27,'height',80*12/72.27,'fontsize',14,'font','Helvetica');

tlo_fig = tiledlayout(4,3,"TileSpacing","compact");         

for i = 1:12
    ax_fig(i) = nexttile(tlo_fig,i); hold on;
end 

% u2000
CtrlVar.PlotXYscale=1e3;
CtrlVar.PlotGLs=0;
PlotNodalBasedQuantities_JDR(ax_fig(1),MUA2000.connectivity,MUA2000.coordinates,log10(u2000),CtrlVar);
colormap(ax_fig(1),CMu);
caxis(ax_fig(1),[1 3.5]);
[xGL2000,yGL2000]=PlotGroundingLines(CtrlVar,MUA2000,GF2000);
plot(ax_fig(1),xGL2000/CtrlVar.PlotXYscale,yGL2000/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(1),MUA2000.Boundary.x/CtrlVar.PlotXYscale,MUA2000.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(1),[]); yticklabels(ax_fig(1),[]);
xlabel(ax_fig(1),""); ylabel(ax_fig(1),"");
axis(ax_fig(1),"equal","tight","off");
cb1 = colorbar(ax_fig(1));
cb1.Location = "north";
pos = get(cb1,"Position");
cb1.Position = [pos(1)+1/3*pos(3) pos(2)+2.5*pos(4) 3/4*pos(3) 0.5*pos(4)];
cb1.Label.String = "${\rm log}_{10}(u_{2000})\; \rm{[m/yr]}$";
cb1.Label.Interpreter = "latex";
cb1.Label.FontSize = 14;
cb1.FontSize=14;

plot(ax_fig(1),[-1640 -1640 -1555 -1555 -1640],[-320 -245 -245 -320 -320],'-w','linewidth',1);
plot(ax_fig(1),[-1580 -1580 -1510 -1510 -1580],[-470 -390 -390 -470 -470],'-w','linewidth',1);
plot(ax_fig(1),[-1540 -1540 -1475 -1475 -1540],[-680 -580 -580 -680 -680],'-w','linewidth',1);

xlimits = xlim(ax_fig(1)); ylimits = ylim(ax_fig(1));
text(ax_fig(1),xlimits(1)-100,ylimits(2)+100,"(a)","FontSize",16);

% h2000
PlotNodalBasedQuantities_JDR(ax_fig(2),MUA2000.connectivity,MUA2000.coordinates,h2000,CtrlVar);
colormap(ax_fig(2),CMh);
caxis(ax_fig(2),[0 3500]);
plot(ax_fig(2),xGL2000/CtrlVar.PlotXYscale,yGL2000/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(2),MUA2000.Boundary.x/CtrlVar.PlotXYscale,MUA2000.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(2),[]); yticklabels(ax_fig(2),[]);
xlabel(ax_fig(2),""); ylabel(ax_fig(2),"");
axis(ax_fig(2),"equal","tight","off");
cb2 = colorbar(ax_fig(2));
cb2.Location = "north";
pos = get(cb2,"Position");
cb2.Position = [pos(1)+1/3*pos(3) pos(2)+2.5*pos(4) 3/4*pos(3) 0.5*pos(4)];
    cb2.Label.String = "$h_{2000}\; \rm{[m]}$";
cb2.Label.Interpreter = "latex";
cb2.Label.FontSize = 14;
cb2.FontSize=14;

text(ax_fig(2),xlimits(1)-100,ylimits(2)+100,"(b)","FontSize",16);

% dhdt2000
PlotNodalBasedQuantities_JDR(ax_fig(3),MUA2000.connectivity,MUA2000.coordinates,dhdt2000,CtrlVar);
colormap(ax_fig(3),CMdhdt);
caxis(ax_fig(3),[-3 3]);
plot(ax_fig(3),xGL2000/CtrlVar.PlotXYscale,yGL2000/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(3),MUA2000.Boundary.x/CtrlVar.PlotXYscale,MUA2000.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(3),[]); yticklabels(ax_fig(3),[]);
xlabel(ax_fig(3),""); ylabel(ax_fig(3),"");
axis(ax_fig(3),"equal","tight","off");
cb3 = colorbar(ax_fig(3));
cb3.Location = "north";
pos = get(cb3,"Position");
cb3.Position = [pos(1)+1/3*pos(3) pos(2)+2.5*pos(4) 3/4*pos(3) 0.5*pos(4)];
cb3.Label.String = "$\dot h_{2000}\; \rm{[m/yr]}$";
cb3.Label.Interpreter = "latex";
cb3.Label.FontSize = 14;
cb3.FontSize=14;
text(ax_fig(3),xlimits(1)-100,ylimits(2)+100,"(c)","FontSize",16);

% dh2000-2009
PlotNodalBasedQuantities_JDR(ax_fig(4),MUA2009_withIS.connectivity,MUA2009_withIS.coordinates,dh2000_2009,CtrlVar);
colormap(ax_fig(4),CMdh);
caxis(ax_fig(4),[-100 100]);
plot(ax_fig(4),xGL2000/CtrlVar.PlotXYscale,yGL2000/CtrlVar.PlotXYscale,'--k','linewidth',1);
[xGL2009,yGL2009]=PlotGroundingLines(CtrlVar,MUA2009_withIS,GF2009_withIS);
plot(ax_fig(4),xGL2009/CtrlVar.PlotXYscale,yGL2009/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(4),MUA2000.Boundary.x/CtrlVar.PlotXYscale,MUA2000.Boundary.y/CtrlVar.PlotXYscale,'--k','linewidth',1);
plot(ax_fig(4),MUA2009_withIS.Boundary.x/CtrlVar.PlotXYscale,MUA2009_withIS.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(4),[]); yticklabels(ax_fig(4),[]);
xlabel(ax_fig(4),""); ylabel(ax_fig(4),"");
axis(ax_fig(4),"equal","tight","off");
title(ax_fig(4),"$h_{2009}-h_{2000}$","Interpreter","latex","fontsize",16);
text(ax_fig(4),xlimits(1)-100,ylimits(2)+100,"(d)","FontSize",16);

% dh2000-2014
PlotNodalBasedQuantities_JDR(ax_fig(5),MUA2014_withIS.connectivity,MUA2014_withIS.coordinates,dh2000_2014,CtrlVar);
colormap(ax_fig(5),CMdh);
caxis(ax_fig(5),[-100 100]);
plot(ax_fig(5),xGL2000/CtrlVar.PlotXYscale,yGL2000/CtrlVar.PlotXYscale,'--k','linewidth',1);
[xGL2014,yGL2014]=PlotGroundingLines(CtrlVar,MUA2014_withIS,GF2014_withIS);
plot(ax_fig(5),xGL2014/CtrlVar.PlotXYscale,yGL2014/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(5),MUA2000.Boundary.x/CtrlVar.PlotXYscale,MUA2000.Boundary.y/CtrlVar.PlotXYscale,'--k','linewidth',1);
plot(ax_fig(5),MUA2014_withIS.Boundary.x/CtrlVar.PlotXYscale,MUA2014_withIS.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(5),[]); yticklabels(ax_fig(5),[]);
xlabel(ax_fig(5),""); ylabel(ax_fig(5),"");
axis(ax_fig(5),"equal","tight","off");
title(ax_fig(5),"$h_{2014}-h_{2000}$","Interpreter","latex","fontsize",16);
text(ax_fig(5),xlimits(1)-100,ylimits(2)+100,"(e)","FontSize",16);

% dh2000-2020
PlotNodalBasedQuantities_JDR(ax_fig(6),MUA2020_withIS.connectivity,MUA2020_withIS.coordinates,dh2000_2020,CtrlVar);
colormap(ax_fig(6),CMdh);
caxis(ax_fig(6),[-100 100]);
plot(ax_fig(6),xGL2000/CtrlVar.PlotXYscale,yGL2000/CtrlVar.PlotXYscale,'--k','linewidth',1);
[xGL2020,yGL2020]=PlotGroundingLines(CtrlVar,MUA2020_withIS,GF2020_withIS);
plot(ax_fig(6),xGL2020/CtrlVar.PlotXYscale,yGL2020/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(6),MUA2000.Boundary.x/CtrlVar.PlotXYscale,MUA2000.Boundary.y/CtrlVar.PlotXYscale,'--k','linewidth',1);
plot(ax_fig(6),MUA2020_withIS.Boundary.x/CtrlVar.PlotXYscale,MUA2020_withIS.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(6),[]); yticklabels(ax_fig(6),[]);
xlabel(ax_fig(6),""); ylabel(ax_fig(6),"");
axis(ax_fig(6),"equal","tight","off");
title(ax_fig(6),"$h_{2020}-h_{2000}$","Interpreter","latex","fontsize",16);
linkaxes([ax_fig(4) ax_fig(5) ax_fig(6)]);
cb6=colorbar(ax_fig(6));
cb6.Location = "eastoutside";
pos = get(cb6,"Position");
cb6.Position = [pos(1)+0.5*pos(3) pos(2)+1/8*pos(4) 0.5*pos(3) 3/4*pos(4)];
cb6.Label.String = "$\Delta h\; \rm{[m]}$";
cb6.Label.Interpreter = "latex";
cb6.Label.FontSize = 14;
cb6.FontSize=14;
text(ax_fig(6),xlimits(1)-100,ylimits(2)+100,"(f)","FontSize",16);

% du2000-2009
PlotNodalBasedQuantities_JDR(ax_fig(7),MUA2009.connectivity,MUA2009.coordinates,du2000_2009,CtrlVar);
colormap(ax_fig(7),CMdu);
caxis(ax_fig(7),[0 1000]);
plot(ax_fig(7),xGL2009/CtrlVar.PlotXYscale,yGL2009/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(7),MUA2009_withIS.Boundary.x/CtrlVar.PlotXYscale,MUA2009_withIS.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(7),[]); yticklabels(ax_fig(7),[]);
xlabel(ax_fig(7),""); ylabel(ax_fig(7),"");
axis(ax_fig(7),"equal","tight","off");
title(ax_fig(7),"$u_{2009}-u_{2000}$","Interpreter","latex","fontsize",16);
text(ax_fig(7),xlimits(1)-100,ylimits(2)+100,"(g)","FontSize",16);

% du2000-2014
PlotNodalBasedQuantities_JDR(ax_fig(8),MUA2014.connectivity,MUA2014.coordinates,du2000_2014,CtrlVar);
colormap(ax_fig(8),CMdu);
caxis(ax_fig(8),[0 1000]);
plot(ax_fig(8),xGL2014/CtrlVar.PlotXYscale,yGL2014/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(8),MUA2014_withIS.Boundary.x/CtrlVar.PlotXYscale,MUA2014_withIS.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(8),[]); yticklabels(ax_fig(8),[]);
xlabel(ax_fig(8),""); ylabel(ax_fig(8),"");
axis(ax_fig(8),"equal","tight","off");
title(ax_fig(8),"$u_{2014}-u_{2000}$","Interpreter","latex","fontsize",16);
text(ax_fig(8),xlimits(1)-100,ylimits(2)+100,"(h)","FontSize",16);

% du2000-2020
PlotNodalBasedQuantities_JDR(ax_fig(9),MUA2020.connectivity,MUA2020.coordinates,du2000_2020,CtrlVar);
colormap(ax_fig(9),CMdu);
caxis(ax_fig(9),[0 1000]);
plot(ax_fig(9),xGL2020/CtrlVar.PlotXYscale,yGL2020/CtrlVar.PlotXYscale,'k','linewidth',1);
plot(ax_fig(9),MUA2020_withIS.Boundary.x/CtrlVar.PlotXYscale,MUA2020_withIS.Boundary.y/CtrlVar.PlotXYscale,'k','linewidth',1);
xticklabels(ax_fig(9),[]); yticklabels(ax_fig(9),[]);
xlabel(ax_fig(9),""); ylabel(ax_fig(9),"");
axis(ax_fig(9),"equal","tight","off");
title(ax_fig(9),"$u_{2020}-u_{2000}$","Interpreter","latex","fontsize",14);
linkaxes([ax_fig(7) ax_fig(8) ax_fig(9)]);
cb9=colorbar(ax_fig(9));
cb9.Location = "eastoutside";
pos = get(cb9,"Position");
cb9.Position = [pos(1)+0.5*pos(3) pos(2)+1/8*pos(4) 0.5*pos(3) 3/4*pos(4)];
cb9.Label.String = "$\Delta u\; \rm{[m/yr]}$";
cb9.Label.Interpreter = "latex";
cb9.Label.FontSize = 14;
cb9.FontSize=14;
text(ax_fig(9),xlimits(1)-100,ylimits(2)+100,"(i)","FontSize",16);

% GL PIG
for ii = 1:numel(S_insar)
    plot(ax_fig(10),S_insar(ii).x/1e3,S_insar(ii).y/1e3,':','linewidth',1,'color',CMgl(S_insar(ii).ind,:));
end
for ii = 1:numel(S_ua)
    plot(ax_fig(10),S_ua(ii).x/1e3,S_ua(ii).y/1e3,'-','linewidth',2,'color',CMgl(S_ua(ii).ind,:));
end
plot(ax_fig(10),MUA.Boundary.x/1e3,MUA.Boundary.y/1e3,'-','color',CMgl(S_ua(end).ind,:),'linewidth',0.5);
colormap(ax_fig(10),CMgl);
axis(ax_fig(10),"equal"); grid(ax_fig(10),"on");  box(ax_fig(10),"on");
xlabel(ax_fig(10),""); ylabel(ax_fig(10),"y [km]")
xlim(ax_fig(10),[-1640 -1555]);
ylim(ax_fig(10),[-320 -245]);
title(ax_fig(10),'Pine Island');
text(ax_fig(10),-1635,-230,"(j)","FontSize",16);

% GL Thwaites
for ii = 1:numel(S_insar)
    g(1)=plot(ax_fig(11),S_insar(ii).x/1e3,S_insar(ii).y/1e3,':','linewidth',1,'color',CMgl(S_insar(ii).ind,:));
end
for ii = 1:numel(S_ua)
    g(2)=plot(ax_fig(11),S_ua(ii).x/1e3,S_ua(ii).y/1e3,'-','linewidth',2,'color',CMgl(S_ua(ii).ind,:));
end
plot(ax_fig(11),MUA.Boundary.x/1e3,MUA.Boundary.y/1e3,'-','color',CMgl(S_ua(end).ind,:),'linewidth',0.5);
colormap(ax_fig(11),CMgl);
axis(ax_fig(11),"equal"); grid(ax_fig(11),"on");  box(ax_fig(11),"on");
xlabel(ax_fig(11),"x [km]"); ylabel(ax_fig(11),"");
xlim(ax_fig(11),[-1580 -1510]);
ylim(ax_fig(11),[-470 -390]);
title(ax_fig(11),'Thwaites');
lgd=legend(ax_fig(11),g(:),["${\rm InSAR}$","${\rm \'Ua}$"],"Interpreter","latex","location","northeast","FontSize",14);
lgd.Position = lgd.Position + [0.05 0 -0.05 0];
text(ax_fig(11),-1590,-385,"(k)","FontSize",16);

% GL Dotson Crosson
for ii = 1:numel(S_insar)
    plot(ax_fig(12),S_insar(ii).x/1e3,S_insar(ii).y/1e3,':','linewidth',1,'color',CMgl(S_insar(ii).ind,:));
end
for ii = 1:numel(S_ua)
    plot(ax_fig(12),S_ua(ii).x/1e3,S_ua(ii).y/1e3,'-','linewidth',2,'color',CMgl(S_ua(ii).ind,:));
end
plot(ax_fig(12),MUA.Boundary.x/1e3,MUA.Boundary.y/1e3,'-','color',CMgl(S_ua(end).ind,:),'linewidth',0.5);
colormap(ax_fig(12),CMgl);
axis(ax_fig(12),"equal"); grid(ax_fig(12),"on");  box(ax_fig(12),"on");
xlabel(ax_fig(12),""); ylabel(ax_fig(12),"");
xlim(ax_fig(12),[-1540 -1475]);
ylim(ax_fig(12),[-680 -580]);
title(ax_fig(12),'Dotson / Crosson');
text(ax_fig(12),-1565,-575,"(l)","FontSize",16);

caxis(ax_fig(12),[1996 2022]);
cb12=colorbar(ax_fig(12));
cb12.Ticks=[1996:4:2022];
cb12.TickLabels = ["1996","2000","2004","2008","2012","2016","2020"];
cb12.Location = "eastoutside";
pos = get(cb12,"Position");
cb12.Position = [pos(1)+0.5*pos(3) pos(2)+1/8*pos(4) 0.5*pos(3) 3/4*pos(4)];
cb12.Label.String = "$\rm{years}$";
cb12.Label.Interpreter = "latex";
cb12.Label.FontSize = 14;
cb12.FontSize=14;

pos = get(H,"Position");
set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
Hname = "./Figure5";
print(H,Hname,"-dpng","-r400");

end
