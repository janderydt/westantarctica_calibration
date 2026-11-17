function [UserVar,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo]=DefineInputsForInverseRun(UserVar,CtrlVar,MUA,BCs,F,l,GF,InvStartValues,Priors,Meas,BCsAdjoint,RunInfo)
% DefineInputsForInverseRun  Ua user input file: measurements, start values and priors for an inversion.
%
% PURPOSE
%   Reads the data used in the inversion: dhdt (if UserVar.Inverse.Measurements
%   contains 'dhdt') and surface velocities with their errors on the nodes of the
%   mesh, and defines the start values (C, AGlen, m, n; via
%   DefineSlipperyDistribution and DefineAGlenDistribution) and priors for the
%   inversion. Data come from UserVar.dhdtInterpolants and
%   UserVar.VelocityInterpolants (see GetUserVar_Inverse). The fields
%   restricted to the nodes of the mesh are cached in files named
%   <interpolant>_mesh_Nnodes<N>_Nele<M>.mat.
%
% REQUIRES
%   Ua source code (FindAllNodesWithinGivenRangeFromGroundingLine etc.)

fprintf('Reading inputs for inverse run \n');

load(UserVar.VelocityInterpolants);

x = MUA.coordinates(:,1); y = MUA.coordinates(:,2);

%% Inversion dhdt
% UserVar.Inverse.dhdt_err (run table column dhdt_err) is a cap on the dhdt errors
% (m/yr): larger errors are set to this value. Floating ice and areas where the
% error exceeds the signal are given dhdt=0 and a very large error.

if strfind(CtrlVar.Inverse.Measurements,'dhdt')
    
    % to speed up the dhdt assembly, we check if the fields have
    % previously been constructed for the same mesh. If not, we read the
    % interpolants and construct a new file for this particular mesh.
    filename_dhdtfields = UserVar.dhdtInterpolants;
    filename_dhdtfields = erase(filename_dhdtfields,["GriddedInterpolants_","ScatteredInterpolants_",".mat"]);
    filename_dhdtfields = filename_dhdtfields + "_mesh_Nnodes" + string(MUA.Nnodes) + "_Nele" + string(MUA.Nele) + ".mat";

    fprintf('Loading dhdt fields for grounded ice.\n');

    fprintf('Trying to read fields from %s...',filename_dhdtfields);

    if exist(filename_dhdtfields,"file")

        load(filename_dhdtfields);
        fprintf('Done.\n');

    else

        fprintf('Failed.\n Reading from %s instead...',UserVar.dhdtInterpolants);
        tmp = load(UserVar.dhdtInterpolants);

        if isfield(tmp,"Fdhdt_CPOM")
            dhdtMeas=tmp.Fdhdt_CPOM(x,y);
            dhdtError=tmp.Fdhdt_err_CPOM(x,y);
        elseif isfield(tmp,"Fdhdt")
            dhdtMeas=tmp.Fdhdt(x,y);
            try
                dhdtError=tmp.Fdhdt_err(x,y);
            catch 
                dhdtError=0*x+1; % error interpolant does not exist - set errors to one for now as a placeholder
            end      
        end

        save(filename_dhdtfields,"dhdtMeas","dhdtError");
        fprintf('Done.\n');

    end

    if ismember(string(UserVar.Domain),["AMUND_nsmbl","SYNTH_PIG_nsmbl"])

        % set zero values and high errors for floating areas
        dhdtMeas(GF.node<0.5) = 0;
        dhdtError(GF.node<0.5) = nan;

        I=find(dhdtMeas>-0.1); 
        dhdtMeas(I)=0; % remove any positive and small negative dhdt values
    
        I2=find(dhdtError>=abs(dhdtMeas)); % identify areas where error is larger than or equal to the signal
        dhdtMeas(I2)=0;

        % set corresponding errors to large values
        dhdtError(I)=nan; 
        dhdtError(I2)=nan; 
    
        % Change any remaining areas where dhdtError>cutoff to dhdtError=cutoff
        I3 = find(dhdtError>UserVar.Inverse.dhdt_err & ~isnan(dhdtError));
        dhdtError(I3) = UserVar.Inverse.dhdt_err;
    
        dhdtError(isnan(dhdtError))=1e10;

        fprintf('Set zero dhdt and high errors for floating ice.\n');

    else

        error('Did not recognize case.')

    end

    Meas.dhdt=dhdtMeas;
    Meas.dhdtCov=sparse(1:MUA.Nnodes,1:MUA.Nnodes,dhdtError.^2,MUA.Nnodes,MUA.Nnodes);

    if any(isnan(dhdtError))
         error('NaN in dhdtError'); 
    end
end

%% Inversion velocities
uMeas = Fus(x,y);
vMeas = Fvs(x,y);
try
    xerrMeas = Fxerr(x,y);
    yerrMeas = Fyerr(x,y);
catch
    xerrMeas = Fuerr(x,y);
    yerrMeas = Fuerr(x,y);
end

clearvars Fus Fvs

% we don't want zero errors:
xerrMeas(xerrMeas==0) = 0.1;
yerrMeas(yerrMeas==0) = 0.1;

xerrMeas(xerrMeas<1)=1;
yerrMeas(yerrMeas<1)=1;

% Because I put NaN in where there is no data, this will give NaN at location not surounded by four data points
% I can then afterwards find the NaN and put in some data with very high errors.
% I need values everywhere, so I now set vel to zero where no measurments are available, 
% and the error to a very large value

Mask=isnan(uMeas);
uMeas(Mask)=0;
xerrMeas(Mask)=1e10;

Mask=isnan(vMeas);
vMeas(Mask)=0;
yerrMeas(Mask)=1e10;

Meas.us = uMeas;
Meas.vs = vMeas;

usError = xerrMeas;
vsError = yerrMeas;

if any(isnan(Meas.us))
	error('NaN in Meas.us');
elseif any(isnan(Meas.vs))
    error('NaN in Meas.vs');
elseif any(isnan(Meas.dhdt))
    error('NaN in Meas.dhdt');
elseif any(isnan(usError))
    error('NaN in usError');
 elseif any(isnan(vsError))
    error('NaN in vsError');   
end

Meas.usCov=sparse(1:MUA.Nnodes,1:MUA.Nnodes,usError.^2,MUA.Nnodes,MUA.Nnodes);
Meas.vsCov=sparse(1:MUA.Nnodes,1:MUA.Nnodes,vsError.^2,MUA.Nnodes,MUA.Nnodes);

clearvars xerrMeas yerrMeas uMeas vMeas

fprintf('Reading start values for AGlen and C...\n');
[UserVar,InvStartValues.C,InvStartValues.m,InvStartValues.q,InvStartValues.muk]=DefineSlipperyDistribution(UserVar,CtrlVar,MUA,CtrlVar.time,F.s,F.b,F.s-F.b,F.S,F.B,F.rho,F.rhow,GF);
[UserVar,InvStartValues.AGlen,InvStartValues.n]=DefineAGlenDistribution(UserVar,CtrlVar,MUA,CtrlVar.time,F.s,F.b,F.s-F.b,F.S,F.B,F.rho,F.rhow,GF);
fprintf('done \n');

listingCC=dir('CC.mat') ; listingCA=dir('CAGlen.mat') ;
CC = []; CAGlen = []; 

%% Define Priors
Priors.B=F.B;

if ~isfield(UserVar.Inverse,'priorC')
    ub=100; tau=80 ; % units meters, year , kPa
    Priors.C = x*0 + ub/tau^InvStartValues.m(1);
else
    Priors.C = x*0 + UserVar.Inverse.priorC;
end
Priors.m = InvStartValues.m(1);
Priors.muk = InvStartValues.muk(1);

if ~isfield(UserVar.Inverse,'priorAGlen')
    Priors.AGlen = x*0 + AGlenVersusTemp(-15); % this is for n=3 only
else
    Priors.AGlen = x*0 + UserVar.Inverse.priorAGlen;
end
Priors.n=InvStartValues.n(1);

disp(['Constant prior value for C: ',num2str(Priors.C(1))]);
disp(['Constant prior value for AGlen: ',num2str(Priors.AGlen(1))]);

Priors.rho = F.rho;
Priors.rhow = F.rhow;

end
