function [UserVar,C,m,q,muk]=DefineSlipperyDistribution(UserVar,CtrlVar,MUA,time,s,b,h,S,B,rho,rhow,GF)
% DefineSlipperyDistribution  Ua user input file of the synthetic SYNTH_PIG experiments: basal slipperiness C.
%
% PURPOSE
%   q = muk = 0.5, m = UserVar.m. C is defined as follows:
%     - time-dependent run without restart: log10(C) = log10(ub/tau^m) + 5 (ub = 100 m/yr, tau = 80 kPa) in the valley
%       (|y| < 15 km) and in an elliptical region upstream of x = 150 km, decreasing linearly towards the lateral margins
%       (by 4 orders of magnitude per 10 km); with spatially correlated noise (Gaussian kernel with a standard deviation
%       of 5 km, multiplied by 5, generated once with rng("default")), smoothed with a Helmholtz filter (length scale 4 km);
%     - restart, or a run that is neither time dependent nor an inversion: C is read from
%       CtrlVar.NameOfFileForReadingSlipperinessEstimate (variables xC, yC, C) and interpolated;
%     - inverse run: constant C = ub/tau^m.
%
% REQUIRES
%   Ua source code (HelmholtzEquation)

persistent Fcorrelated_noise

xUa = MUA.coordinates(:,1); yUa = MUA.coordinates(:,2);

q=0.5; muk=0.5;

m=UserVar.m;

if CtrlVar.Restart==0 && CtrlVar.TimeDependentRun

    %% base value in log10
    ub=100; tau=80 ; % units meters, year , kPa
    log10Cbase = log10(ub/tau^m);
    log10C = log10Cbase + zeros(MUA.Nnodes,1);

    %% reduce to log10(C)=log10Cbase at margins
    xc = 1.5e5; yc = 0e3;
    x = MUA.coordinates(:,1);
    y = MUA.coordinates(:,2);
    % reduce over circular strip
    r = sqrt((y-yc).^2+(x-xc).^2/5);
    nodesi = find(x<=1.5e5);
    log10C(nodesi) = max(min(log10Cbase+5 + (-4)/(2.5e4-1.5e4)*(r(nodesi)-1.5e4),log10Cbase+5),log10Cbase);

    %% increase to log10Cbase+5 in valley
    indl = find(y>=0 & x>1.5e5);
    log10C(indl) = min(log10Cbase+5 + (-4)/(2.5e4-1.5e4)*(y(indl)-1.5e4),log10Cbase+5);
    indr = find(y<=0 & x>1.5e5);
    log10C(indr) = min(log10Cbase+5 + (-4)/(-2.5e4+1.5e4)*(y(indr)+1.5e4),log10Cbase+5);

    %% add some spatially correlated noise
    if isempty(Fcorrelated_noise)
        xd=max(xUa(:)) ; xu=min(xUa(:)); yl=max(yUa(:)) ; yr=min(yUa(:));
        nx = (xd-xu)/1e3;
        ny = (yl-yr)/1e3;
        x = linspace(xu,xd,nx);
        y = linspace(yr,yl,ny);
        [X,Y] = ndgrid(x,y);

        sigma = 5;% standard deviation of the Gaussian kernel (controls correlation)
        % Step 1: Generate white noise
        rng("default"); % for reproducebility
        white_noise = randn(nx,ny);

        % Step 2: Create Gaussian kernel
        kernel_size = 2*ceil(3*sigma) + 1;  % Covers 99% of Gaussian
        [x, y] = meshgrid(-floor(kernel_size/2):floor(kernel_size/2), ...
                          -floor(kernel_size/2):floor(kernel_size/2));
        g_kernel = exp(-(x.^2 + y.^2) / (2*sigma^2));
        g_kernel = g_kernel / sum(g_kernel(:));  % Normalize

        % Step 3: Apply Gaussian filter via convolution
        correlated_noise = 5*conv2(white_noise, g_kernel, 'same');

        Fcorrelated_noise = griddedInterpolant(X,Y,correlated_noise,"cubic");

    end

    C_noise = Fcorrelated_noise(xUa,yUa);

    log10C = log10C+C_noise;

    C = min(max(10.^(log10C),CtrlVar.Cmin),CtrlVar.Cmax);

    L=4e3 ;  % Smoothing length scale
    [~,SmoothedField]=HelmholtzEquation([],CtrlVar,MUA,1,L^2,log10(C),0);
    C = 10.^SmoothedField;

end

if CtrlVar.Restart || (~CtrlVar.TimeDependentRun && ~CtrlVar.InverseRun)

    tmp=load(CtrlVar.NameOfFileForReadingSlipperinessEstimate);
    FC = scatteredInterpolant(tmp.xC,tmp.yC,tmp.C);
    C = FC(xUa,yUa);

end

if CtrlVar.InverseRun
    ub=100; tau=80 ; % units meters, year , kPa
    Cbase = ub/tau^m;
    C = Cbase + zeros(MUA.Nnodes,1);
end

end
