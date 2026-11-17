function [UserVar,s,b,S,B,rho,rhow,g]=DefineGeometryAndDensities(UserVar,CtrlVar,MUA,F,FieldsToBeDefined)
% DefineGeometryAndDensities  Ua user input file of the synthetic glacier (SYNTH_PIG): geometry and densities.
%
% PURPOSE
%   Creates the geometry of the synthetic glacier (a Pine-Island-like glacier on a narrow domain).
%   The bed B is a sinusoidal trough across the glacier (Ly = 50 km: -1100 m in the middle and -500 m at the sides for a
%   domain that is 50 km wide) with a Gaussian ridge (height 300 m, width 11 km, at x = 250 km), plus small-scale
%   topography (white noise smoothed with a Gaussian kernel and multiplied by 500, generated once with
%   rng("default") so that it is reproducible), and smoothed with a Helmholtz filter (length scale 4 km). If CtrlVar.Experiment contains "calving", a Gaussian overdeepening is
%   added upstream of the ridge (for testing). The ocean surface is S = 0, the ice density 917 kg/m^3, the ocean
%   density 1027 kg/m^3.
%   The surface s and the base b depend on the type of run:
%     - inverse run, or Experiment contains "nochange": from the result file of the synthetic experiment "warm"
%       after 15 years (./ResultsFiles/ResultsFile-warm-000015yr.mat);
%     - time-dependent run without restart: Experiment "spinup": linear surface (400 m at the upstream end, 100 m at the
%       downstream end) on the bed (b = B); Experiment "cold": surface and base from the restart file
%       spinup_nomelt-RestartFile.mat;
%     - diagnostic run (neither time-dependent nor inverse): from the result file of the experiment "warm" after
%       35 years;
%     - otherwise s and b are empty.
%
% INPUTS
%   UserVar, CtrlVar (Experiment, InverseRun, TimeDependentRun, Restart), MUA, F, FieldsToBeDefined (F and
%   FieldsToBeDefined are not used)
%
% OUTPUTS
%   s, b, S, B, rho, rhow, g (g = 9.81/1000)
%
% FILES READ (results of earlier synthetic experiments; data that can be obtained upon request from the author)
%   ./ResultsFiles/ResultsFile-warm-0000<yr>yr.mat (yr = 15 or 35) and spinup_nomelt-RestartFile.mat
%
% REQUIRES
%   Ua source code (HelmholtzEquation)
%
% NOTE: Ua user input files such as this one exist in several stages with the same name (see ua_input/run/4_inverse
%   and ua_input/run/5_diagnostic): Ua uses the copy in the experiment folder, do not put these folders on the MATLAB path.

persistent Fcorrelated_noise

x=MUA.coordinates(:,1); y=MUA.coordinates(:,2);
     
alpha = 0.;

%% Bed topography B
% a sinusoidal trough across the glacier (y direction)
Ly = 50e3;
B = -(500 + 600*sin(pi*y/Ly+pi/2));

% add Gaussian ridge
ampl_b=300; sigma_bx=1.1e4; x0=2.5e5;
DeltaB=-1100+ampl_b*exp(-(x-x0).^2/(2*sigma_bx^2));

I=find(DeltaB>B);
B(I)=DeltaB(I);

% add small scale topography

if isempty(Fcorrelated_noise)

    xd=max(x(:)) ; xu=min(x(:)); yl=max(y(:)) ; yr=min(y(:));
    nx = (xd-xu)/1e3; 
    ny = (yl-yr)/1e3;
    x_l = linspace(xu,xd,nx);
    y_l = linspace(yr,yl,ny);
    [X,Y] = ndgrid(x_l,y_l);
    
    sigma = 4;% standard deviation of the Gaussian kernel (controls correlation)
    % Step 1: Generate white noise
    rng("default"); % for reproducibility
    white_noise = randn(nx,ny);
    
    % Step 2: Create Gaussian kernel
    kernel_size = 2*ceil(3*sigma) + 1;  % Covers 99% of Gaussian
    [x_m, y_m] = meshgrid(-floor(kernel_size/2):floor(kernel_size/2), ...
                      -floor(kernel_size/2):floor(kernel_size/2));
    g_kernel = exp(-(x_m.^2 + y_m.^2) / (2*sigma^2));
    g_kernel = g_kernel / sum(g_kernel(:));  % Normalize
    
    % Step 3: Apply Gaussian filter via convolution
    correlated_noise = 500*conv2(white_noise, g_kernel, 'same');
    
    Fcorrelated_noise = griddedInterpolant(X,Y,correlated_noise,"cubic");
    
end

B = B + Fcorrelated_noise(x,y);
L=4e3 ;  % Smoothing length scale 
[~,SmoothedField]=HelmholtzEquation([],CtrlVar,MUA,1,L^2,B,0); 
B = SmoothedField;

% for testing
if contains(CtrlVar.Experiment,"calving")
    % add guassian overdeepening in the bed upstream of ridge so it creates a lake
    x_m = 2.2e5;
    y_m = 0;
    sigma = 10e3;
    overdeepening = -250*exp(-((x_m-x).^2 + (y_m-y).^2) / (2*sigma^2));
    B = B + overdeepening;
end

S = B*0;

%% Surface s and base b, depending on the type of run
if CtrlVar.InverseRun || contains(CtrlVar.Experiment,"nochange")
    synth_exp = "warm";
    yr = "15";
    tmp = load("./ResultsFiles/ResultsFile-"+synth_exp+"-0000"+yr+"yr.mat");
    Fs = scatteredInterpolant(tmp.MUA.coordinates(:,1),tmp.MUA.coordinates(:,2),tmp.F.s);
    Fb = scatteredInterpolant(tmp.MUA.coordinates(:,1),tmp.MUA.coordinates(:,2),tmp.F.b);
    s = Fs(MUA.coordinates(:,1),MUA.coordinates(:,2));
    b = Fb(MUA.coordinates(:,1),MUA.coordinates(:,2));
elseif CtrlVar.TimeDependentRun && ~CtrlVar.Restart
    if contains(CtrlVar.Experiment,"spinup")
        hmax = 400; hmin = 100; xmax = max(x); xmin = min(x);  
        s = (hmax-hmin)/(xmin-xmax)*(x-xmax)+hmin;
        b = B;
    elseif contains(CtrlVar.Experiment,"cold")
        tmp = load("spinup_nomelt-RestartFile.mat");
        s = tmp.F.s;
        b = tmp.F.b;
    end
else
    s=[];
    b=[];
end

if ~CtrlVar.TimeDependentRun && ~CtrlVar.InverseRun && ~contains(CtrlVar.Experiment,"nochange")
    synth_exp = "warm";
    yr = "35";
    tmp = load("./ResultsFiles/ResultsFile-"+synth_exp+"-0000"+yr+"yr.mat");
    Fs = scatteredInterpolant(tmp.MUA.coordinates(:,1),tmp.MUA.coordinates(:,2),tmp.F.s);
    Fb = scatteredInterpolant(tmp.MUA.coordinates(:,1),tmp.MUA.coordinates(:,2),tmp.F.b);
    s = Fs(MUA.coordinates(:,1),MUA.coordinates(:,2));
    b = Fb(MUA.coordinates(:,1),MUA.coordinates(:,2));
end

rho=917+zeros(MUA.Nnodes,1) ; 
rhow=1027; 
g=9.81/1000;
