function Figure2_Plot_SYNTH_PIG_VelThick
% Figure2_Plot_SYNTH_PIG_VelThick  Figure 2: synthetic glacier (SYNTH_PIG) and the change over the calibration period.
%
% *** FOR TRANSPARENCY, NOT RUNNABLE ***
% Needs the results of the synthetic Ua experiments (these data can be obtained upon request from the author), see the load statements.
%
% PURPOSE
%   (a) 3D view of the synthetic glacier after 500 years of the spinup with the cold ocean temperature profile and Weertman sliding ("cold_Weertman"; "00500k000" in the file name is 500.000 years), with the
%   grounding line and the surface velocity vectors; (b, c) ice thickness and speed at t0 = 30 years of the "warm"
%   experiment; (d-i) changes in ice thickness (d-f) and in speed (g-i) between t0 and t1 = 35, 50, 75 years, with the
%   grounding lines of t0 and t1. Saves ./Figure2.png.
%
% REQUIRES
%   Ua source code (Plot_sbB, PlotGroundingLines); cmocean, fig (third party); PlotNodalBasedQuantities_JDR
%   (modified Ua plotting function); all must be on the MATLAB path


CMh = flipud(cmocean('ice',32));
CMu = cmocean('matter',32);
CMdh = cmocean('balance',32);
CMdu = cmocean('balance',32);

H=fig('name','SyntheticGlacier','units','inches','width',80*12/72.27,'height',80*12/72.27,'fontsize',14,'font','Helvetica');
tlo_fig = tiledlayout(4,3,"TileSpacing","tight");         

ax_fig(1) = nexttile(tlo_fig,[2 2]); hold on;
ax_fig(2) = nexttile(tlo_fig,3); hold on;
ax_fig(3) = nexttile(tlo_fig,6); hold on;
for i = 1:6
    ax_fig(3+i) = nexttile(tlo_fig,6+i); hold on;
end

load("/path/to/SYNTH_PIG/ResultsFiles/cold_Weertman/ResultsFile-cold_Weertman-00500k000yr.mat");

lowercase_alphabet = 'a':'z';

%% 3D image
axes(ax_fig(1)); hold on;
CtrlVar.PlotXYscale = 1e3;
[TRI,DT,LightHandle]=Plot_sbB(CtrlVar,MUA,F.s,F.b,F.B,[],[],2,[30 27 90 45],[],[1 1 1],[0.65 0.8 0.9],[0.6902 0.5961 0.4392]);

LightHandle.Style="local";
LightHandle.Position=[-0.4e6/CtrlVar.PlotXYscale 0/CtrlVar.PlotXYscale 7e3];

axes(ax_fig(1)); hold on;
ax_fig(1).FontSize = 14;
xlim(ax_fig(1),[1.5e5 2.9e5]/CtrlVar.PlotXYscale);
ax_fig(1).XLabel.String = "$x\, {\rm [km]}$"; ax_fig(1).XLabel.Interpreter="latex";
ax_fig(1).YLabel.String = "$y\, {\rm [km]}$"; ax_fig(1).YLabel.Interpreter="latex";
ax_fig(1).ZLabel.String = "$z\, {\rm [m]}$"; ax_fig(1).ZLabel.Interpreter="latex";
CtrlVar.PlotGLs=0;
[xGL,yGL]=PlotGroundingLines(CtrlVar,MUA,F.GF) ;
Fs = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),F.s);
zGL_s = Fs(xGL,yGL)+10;
Fb = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),F.b);
zGL_b = Fb(xGL,yGL);

plot3(ax_fig(1),xGL/CtrlVar.PlotXYscale,yGL/CtrlVar.PlotXYscale,zGL_s,'-w','LineWidth',2);
plot3(ax_fig(1),xGL/CtrlVar.PlotXYscale,yGL/CtrlVar.PlotXYscale,zGL_b,'-w','LineWidth',2);

Fub = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),F.ub);
Fvb = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),F.vb);
[X,Y] = ndgrid([1.5e5:10e3:2.85e5],[-2.5e4:5e3:2.5e4]);
ub = Fub(X,Y);
vb = Fvb(X,Y);
zu = Fs(X,Y);
X = [X(:); 270e3];
Y = [Y(:); 20e3];
zu = [zu(:); 270];
ub = [ub(:); 2e3];
vb = [vb(:); 0];

axes(ax_fig(1)); hold on;
quiver3(ax_fig(1),X(:)/CtrlVar.PlotXYscale,Y(:)/CtrlVar.PlotXYscale,zu(:)+1,ub(:)/0.3e3,vb(:)/0.3e3,0*ub(:),'k',"AutoScale","off");
text(ax_fig(1),260,20,360,'$2000\,{\rm m\,a^{-1}}$','fontsize',14,'Interpreter','latex');

text(ax_fig(1),140,-25,1200,"("+lowercase_alphabet(1)+")","FontSize",18);

grid(ax_fig(1),"off"); box(ax_fig(1),"on");
title(ax_fig(1),"");

%% t0 data

CtrlVar.PlotGLs=0;
[xGL0,yGL0]=PlotGroundingLines(CtrlVar,MUA,F.GF);

load("/path/to/SYNTH_PIG/ResultsFiles/warm_Weertman/ResultsFile-warm_Weertman-00030k000yr.mat");

Fub_t0 = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),F.ub);
Fvb_t0 = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),F.vb);
Fu_t0 = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),hypot(F.ub,F.vb));
Fh_t0 = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),F.h);
[X,Y] = ndgrid([0:25e3:2.95e5],[-2.5e4:5e3:2.5e4]);
ub_t0 = Fub_t0(X,Y);
vb_t0 = Fvb_t0(X,Y);

CtrlVar.PlotXYscale=1e3;
CtrlVar.PlotGLs=0;
PlotNodalBasedQuantities_JDR(ax_fig(3),MUA.connectivity,MUA.coordinates,hypot(F.ub,F.vb),CtrlVar);
quiver(ax_fig(3),X(:)/CtrlVar.PlotXYscale,Y(:)/CtrlVar.PlotXYscale,ub_t0(:)/1.5e2,vb_t0(:)/1.5e2,'k',"AutoScale","off","MaxHeadSize",0.03);
colormap(ax_fig(3),CMu);
clim(ax_fig(3),[0 3000]);
[xGL,yGL]=PlotGroundingLines(CtrlVar,MUA,F.GF);
plot(ax_fig(3),xGL/CtrlVar.PlotXYscale,yGL/CtrlVar.PlotXYscale,'k','linewidth',1.5);
xticklabels(ax_fig(3),[]); xlim(ax_fig(3),[0 300]); ylim(ax_fig(3),[-25 25]); 
xlabel(ax_fig(3),""); 
ax_fig(3).YLabel.String = "$y\, {\rm [km]}$"; ax_fig(3).YLabel.Interpreter="latex";
ylabel(ax_fig(3),"y [km]");
axis(ax_fig(3),"tight"); %axis(ax_fig(2),"equal");
text(ax_fig(3),10,20,'$t_0=30\,{\rm years}$','fontsize',18,'Interpreter','latex');
text(ax_fig(3),-40,30,"("+lowercase_alphabet(3)+")","FontSize",18);

CtrlVar.PlotXYscale=1e3;
CtrlVar.PlotGLs=0;
PlotNodalBasedQuantities_JDR(ax_fig(2),MUA.connectivity,MUA.coordinates,F.h,CtrlVar);
colormap(ax_fig(2),CMh);
caxis(ax_fig(2),[0 3500]);
[xGL1,yGL1]=PlotGroundingLines(CtrlVar,MUA,F.GF);
plot(ax_fig(2),xGL1/CtrlVar.PlotXYscale,yGL1/CtrlVar.PlotXYscale,'k','linewidth',1.5);
xticklabels(ax_fig(2),[]); 
xlim(ax_fig(2),[0 300]); ylim(ax_fig(3),[-25 25]); 
ax_fig(2).YLabel.String = "$y\, {\rm [km]}$"; ax_fig(2).YLabel.Interpreter="latex";
axis(ax_fig(2),"tight"); %axis(ax_fig(3),"equal");
text(ax_fig(2),10,20,'$t_0=30\,{\rm years}$','fontsize',18,'Interpreter','latex');
text(ax_fig(2),-40,30,"("+lowercase_alphabet(2)+")","FontSize",18);

%% times t_1
t1 = [35 50 75];

for tt=1:numel(t1)

    load("/path/to/SYNTH_PIG/ResultsFiles/warm_Weertman/ResultsFile-warm_Weertman-000"+string(t1(tt))+"k000yr.mat");

    ub_t1 = F.ub; ub_t1(F.GF.node<0.5)=nan;
    vb_t1 = F.vb; vb_t1(F.GF.node<0.5)=nan;
    Fub_t1 = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),ub_t1);
    Fvb_t1 = scatteredInterpolant(MUA.coordinates(:,1),MUA.coordinates(:,2),vb_t1);
    [X,Y] = ndgrid([0:25e3:2.95e5],[-2.5e4:5e3:2.5e4]);
    ub_t1 = Fub_t1(X,Y);
    vb_t1 = Fvb_t1(X,Y);

    CtrlVar.PlotXYscale=1e3;
    CtrlVar.PlotGLs=0;
    u_t1 = hypot(F.ub,F.vb); u_t1(F.GF.node<0.5)=nan;
    [X2,Y2] = ndgrid([0:5e3:2.95e5],[-2.5e4:2.5e3:2.5e4]);
    plot(ax_fig(6+tt),X2(1:2:end)/1e3,Y2(1:2:end)/1e3,'x','color',[0.5 0.5 0.5],'markersize',3);
    PlotNodalBasedQuantities_JDR(ax_fig(6+tt),MUA.connectivity,MUA.coordinates,u_t1-Fu_t0(MUA.coordinates(:,1),MUA.coordinates(:,2)),CtrlVar);
    dub = ub_t1-ub_t0;
    dvb = vb_t1-vb_t0;
    quiver(ax_fig(6+tt),X(:)/CtrlVar.PlotXYscale,Y(:)/CtrlVar.PlotXYscale,dub(:)/50,dvb(:)/50,'k',"AutoScale","off","MaxHeadSize",0.03);
    quiver(ax_fig(6+tt),20,-23,1000/50,0/50,'k',"AutoScale","off","MaxHeadSize",0.3);
    text(ax_fig(6+tt),20,-19,"1 km/yr");
    colormap(ax_fig(6+tt),CMdu);
    caxis(ax_fig(6+tt),[-1000 1000]);
    plot(ax_fig(6+tt),xGL1/CtrlVar.PlotXYscale,yGL1/CtrlVar.PlotXYscale,'-k','linewidth',1,'color',[1 0.65 0.3]);
    [xGL2,yGL2]=PlotGroundingLines(CtrlVar,MUA,F.GF);
    plot(ax_fig(6+tt),xGL2/CtrlVar.PlotXYscale,yGL2/CtrlVar.PlotXYscale,'k','linewidth',1.5);
    xlim(ax_fig(6+tt),[0 300]); ylim(ax_fig(6+tt),[-25 25]); 
    ax_fig(6+tt).XLabel.String = "$x\, {\rm [km]}$"; ax_fig(6+tt).XLabel.Interpreter="latex";
    if tt==1
        ax_fig(6+tt).YLabel.String = "$y\, {\rm [km]}$"; ax_fig(6+tt).YLabel.Interpreter="latex"; 
    else
        yticklabels(ax_fig(6+tt),[]); 
        ylabel(ax_fig(6+tt),"");
    end
    text(ax_fig(6+tt),10,20,"$t_1="+string(t1(tt))+"\,{\rm years}$",'fontsize',18,'Interpreter','latex');
    text(ax_fig(6+tt),-40,30,"("+lowercase_alphabet(6+tt)+")","FontSize",18);

    
    CtrlVar.PlotXYscale=1e3;
    CtrlVar.PlotGLs=0;
    PlotNodalBasedQuantities_JDR(ax_fig(3+tt),MUA.connectivity,MUA.coordinates,F.h-Fh_t0(MUA.coordinates(:,1),MUA.coordinates(:,2)),CtrlVar);
    colormap(ax_fig(3+tt),CMdh);
    caxis(ax_fig(3+tt),[-1000 1000]);
    g(1)=plot(ax_fig(3+tt),xGL1/CtrlVar.PlotXYscale,yGL1/CtrlVar.PlotXYscale,'-k','linewidth',1,'color',[1 0.65 0.3]);
    g(2)=plot(ax_fig(3+tt),xGL2/CtrlVar.PlotXYscale,yGL2/CtrlVar.PlotXYscale,'k','linewidth',1.5);
    xticklabels(ax_fig(3+tt),[]); xlim(ax_fig(3+tt),[0 300]); ylim(ax_fig(3+tt),[-25 25]); 
    xlabel(ax_fig(3+tt),""); 
    if tt==1
        ax_fig(3+tt).YLabel.String = "$y\, {\rm [km]}$"; ax_fig(3+tt).YLabel.Interpreter="latex";
        legend(ax_fig(3+tt),g(:),["grounding line t_0","grounding line t_1"],"Location","southwest","FontSize",12)
    else
        yticklabels(ax_fig(3+tt),[]); 
        ylabel(ax_fig(3+tt),"");
    end
    text(ax_fig(3+tt),10,20,"$t_1="+string(t1(tt))+"\,{\rm years}$",'fontsize',18,'Interpreter','latex');
    text(ax_fig(3+tt),-40,30,"("+lowercase_alphabet(3+tt)+")","FontSize",18);

end

c1=colorbar(ax_fig(3));
c1.Label.String = "$\mathbf{u}_{\rm meas,0}\; \rm{[m/yr]}$";
c1.Label.Interpreter = "latex";
c1.FontSize=14;

c2=colorbar(ax_fig(2));
c2.Label.String = "$h_{\rm meas,0}\; \rm{[m]}$";
c2.Label.Interpreter = "latex";
c2.FontSize=14;

c3=colorbar(ax_fig(9));
c3.Label.String = "$\mathbf{u}_{\rm meas,1}-\mathbf{u}_{\rm meas,0}\; \rm{[m/yr]}$";
c3.Label.Interpreter = "latex";
c3.FontSize=14;

c4=colorbar(ax_fig(6));
c4.Label.String = "$h_{\rm meas,1}-h_{\rm meas,0}\; \rm{[m]}$";
c4.Label.Interpreter = "latex";
c4.FontSize=14;

pos = get(H,"Position");
set(H,"PaperPositionMode","Auto","PaperUnits","Inches","PaperSize",[pos(3),pos(4)]);
Hname = "./Figure2.png";
print(H,Hname,"-dpng","-r400");
