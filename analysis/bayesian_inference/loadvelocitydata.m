function out = loadvelocitydata(UserVar)
% loadvelocitydata  Observed velocities (or changes in speed) and their errors on the nodes of the Ua mesh.
%
% PURPOSE
%   Provides the data of the Bayesian inference (calc_BayesianInference_u): for each year pair "yr1-yr2" in
%   UserVar.years the observed change in speed (dataformat "du"), or for each year the speed ("u") or
%   log10 of the speed ("LOGu"), interpolated onto the nodes of the Ua mesh, with errors. Gaps (NaN) in the
%   change in speed are filled with the nearest neighbour value and its error. If only grounded ice is used
%   (only_grounded_ice), the change in speed on floating ice is set to ~0 with a tiny error (the emulator is
%   trained for a change of 0 there).
%
% INPUT
%   UserVar with domain ("AMUND" or "SYNTH_PIG"), dataformat, years (one row per emulator, e.g. "2000-2009"),
%   only_grounded_ice (or include_floating_ice) and optionally MUA, GF (mesh and grounding mask)
%
% OUTPUT
%   out.("yr"+yr1+"_yr"+yr2).du / .stddu (N-by-1; "du"), out.("yr"+yr).u / .stdu (other formats), plus MUA, GF
%
% FILES READ (data; can be obtained upon request from the author, see README)
%   /path/to/interpolants/ (set in the code): extruded velocity interpolants of each year
%     (GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat for 2000,
%      GriddedInterpolants_<yr>-<yr+1>_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat for AMUND,
%      ScatteredInterpolants_Velocities_SYNTH_PIG_<year>.mat for SYNTH_PIG)
%   /path/to/DiagnosticData/<domain>/<domain>_Delta_u_<yr1>-<yr2>[_Weertman].mat (set in the code)
%     (MUA_yr2, GF_yr2); for "u" / "LOGu": <domain>_perturbation_grids.mat

domain = UserVar.domain;
if isfield(UserVar,"MUA")
    MUA = UserVar.MUA;
    GF = UserVar.GF;
else
    MUA = [];
end
dataformat = UserVar.dataformat;
years = UserVar.years;
try 
    only_grounded_ice = UserVar.only_grounded_ice;
catch
    only_grounded_ice = 1-UserVar.include_floating_ice;
end

% load measured velocity data

% assemble velocity fields
years_tmp = strjoin(years,"-");
years_unique = unique(split(years_tmp,"-"));

for ii=1:numel(years_unique)

    if contains(domain,"AMUND")
        if years_unique(ii)=="2000"
            fname = "GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat";
        else
            fname = "GriddedInterpolants_"+string(double(years_unique(ii)))+"-"+string(double(years_unique(ii))+1)+...
                "_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat";
        end
    elseif domain=="SYNTH_PIG"
        fname = "ScatteredInterpolants_Velocities_SYNTH_PIG_"+years_unique(ii)+".mat";
    end

    load("/path/to/interpolants/"+fname);
    v_tmp = hypot(Fus.Values,Fvs.Values);
    Fu = Fus; Fu.Values = v_tmp;
    std_tmp = hypot(Fxerr.Values,Fyerr.Values);
    Fstd = Fus; Fstd.Values = std_tmp;
    v.("yr"+years_unique(ii)).F = Fu;
    std.("yr"+years_unique(ii)).F = Fstd;

end

for dd=1:numel(dataformat)

    if dataformat(dd) == "du"
        
        years_tmp = split(years(dd),"-");
        yr1 = years_tmp(1);
        yr2 = years_tmp(2);

        if isempty(MUA)
            try
                load("/path/to/DiagnosticData/"+domain+"/"+domain+"_Delta_u_"+yr1+"-"+yr2+"_Weertman.mat","MUA_yr2","GF_yr2");
            catch
                load("/path/to/DiagnosticData/"+domain+"/"+domain+"_Delta_u_"+yr1+"-"+yr2+".mat","MUA_yr2","GF_yr2");
            end
            out.("yr"+yr2).MUA = MUA_yr2;
            out.("yr"+yr2).GF = GF_yr2;
            MUA = MUA_yr2;
            GF = GF_yr2;
        else
            out.("yr"+yr1).MUA = MUA;
            out.("yr"+yr1).GF = GF;
        end
    
        % interpolate initial and final speed onto Ua mesh
        u_init = v.("yr"+yr1).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        std_init = std.("yr"+yr1).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        u_target = v.("yr"+yr2).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        std_target = std.("yr"+yr2).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
    
        deltau = u_target-u_init; % measured change in speed (m/yr)
        deltau_err = hypot(std_init,std_target); % error estimate (m/yr)
        
        % remove nans by replacing them with nearest non-nan neighbour
        % value and more conservative error estimate
        Ind = find(~isnan(deltau) & ~isnan(deltau_err));
        Fdeltau_tmp = scatteredInterpolant(MUA.coordinates(Ind,1),MUA.coordinates(Ind,2),deltau(Ind),'nearest');
        Fdeltau_err_tmp = Fdeltau_tmp;
        Fdeltau_err_tmp.Values = deltau_err(Ind);
        Ind = find(isnan(deltau) | isnan(deltau_err));
        deltau(Ind) = Fdeltau_tmp(MUA.coordinates(Ind,1),MUA.coordinates(Ind,2));
        deltau_err(Ind) = Fdeltau_err_tmp(MUA.coordinates(Ind,1),MUA.coordinates(Ind,2)); % inherit nearest neighbour error

        %% if we need to remove the floating ice: emulator is trained for deltau=0 on floating ice, so
        %% setting deltau=0 in measurements will not penalize mismatch for floating ice
        if only_grounded_ice
            deltau(GF.node<0.5) = eps(0);
            deltau_err(GF.node<0.5) = 1e-3;
        end
    
        out.("yr"+yr1+"_yr"+yr2).du = deltau(:);
        out.("yr"+yr1+"_yr"+yr2).stddu = deltau_err(:);

    elseif ismember(dataformat(dd),["u","LOGu"])
    
        tmp=load("/path/to/DiagnosticData/"+domain+"/"+domain+"_perturbation_grids.mat");
        MUA = tmp.("MUA_"+years(dd)); GF = tmp.("GF_"+years(dd));

        % interpolate initial and final speed onto Ua mesh
        u_tmp = v.("yr"+years(dd)).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        std_tmp = std.("yr"+years(dd)).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        
        % apply log if needed
        if dataformat(dd)=="LOGu"
            std_tmp = min(std_tmp./(u_tmp*log(10)),10);
            u_tmp = log10(u_tmp);    
        end

        out.("yr"+years(dd)).u = u_tmp(:);
        out.("yr"+years(dd)).MUA = MUA;
        out.("yr"+years(dd)).GF = GF;
        out.("yr"+years(dd)).stdu = std_tmp(:);
    
    end
end

end
