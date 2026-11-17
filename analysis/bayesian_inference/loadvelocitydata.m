function out = loadvelocitydata(domain,dataformat,years,only_grounded_ice)
% loadvelocitydata  Observed velocities (or changes in speed) and their errors on the nodes of the Ua mesh.
%
% PURPOSE
%   Provides the data of the Bayesian inference (Calc_BayesianInference): for each year pair "yr1-yr2" in years the observed
%   change in speed (dataformat "du"), or for each year the speed ("u") or log10 of the speed ("LOGu"), interpolated onto
%   the nodes of the Ua mesh, with errors. For "du", gaps (NaN) are set to a change of eps with an error of 1e3 m/yr, and if only
%   grounded ice is used (only_grounded_ice) the change on floating ice is set to eps with an error of 1e-3 m/yr. For
%   AMUND, the speed of 2000 is the 1996-2003 composite, that of 2020 the 2019-2020 field and that of any other year yr
%   the field yr-(yr+1) (all extruded, see Create_ExtrudedFields).
%
% INPUT
%   domain ("AMUND" or "SYNTH_PIG"), dataformat (a vector of "du", "u" or "LOGu", one per emulator), years (a vector of year pairs "2000-2009"
%   for "du" or of years for "u" and "LOGu"), only_grounded_ice (0 or 1)
%
% OUTPUT
%   out.("yr"+yr1+"_yr"+yr2).du / .stddu (N-by-1; "du"), out.("yr"+yr).u / .stdu (other formats), and
%   out.("yr"+yr).MUA / .GF
%
% FILES READ (data; can be obtained upon request from the author, see README)
%   /path/to/interpolants/ (set in the code): extruded velocity interpolants of each year
%     (GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat for 2000,
%      GriddedInterpolants_<yr>-<yr+1>_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat for AMUND,
%      ScatteredInterpolants_Velocities_SYNTH_PIG_<year>.mat for SYNTH_PIG)
%   /path/to/DiagnosticData/<domain>/<domain>_Delta_u_<yr1>-<yr2>[_Weertman].mat (set in the code)
%     (MUA_yr2, GF_yr2); for "u" / "LOGu": <domain>_perturbation_grids.mat

% assemble velocity fields
years_tmp = strjoin(years,"-");
years_unique = unique(split(years_tmp,"-"));

for ii=1:numel(years_unique)

    if domain=="AMUND"
        if years_unique(ii)=="2000"
            fname = "GriddedInterpolants_1996-2003_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat";
        elseif years_unique(ii)=="2020"
            fname = "GriddedInterpolants_"+string(double(years_unique(ii))-1)+"-"+string(double(years_unique(ii)))+...
                "_MeaSUREs_ITSLIVE_Velocities_EXTRUDED.mat";
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

        try
            load("/path/to/DiagnosticData/"+domain+"/"+domain+"_Delta_u_"+yr1+"-"+yr2+"_Weertman.mat","MUA_yr2","GF_yr2");
        catch
            load("/path/to/DiagnosticData/"+domain+"/"+domain+"_Delta_u_"+yr1+"-"+yr2+".mat","MUA_yr2","GF_yr2");
        end
        MUA = MUA_yr2; GF = GF_yr2;

        % interpolate initial and final speed onto Ua mesh
        u_init = v.("yr"+yr1).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        std_init = std.("yr"+yr1).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        u_target = v.("yr"+yr2).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        std_target = std.("yr"+yr2).F(MUA.coordinates(:,1),MUA.coordinates(:,2));

        deltau = u_target-u_init; % measured change in speed (m/yr)
        deltau_err = hypot(std_init,std_target); % error estimate (m/yr)

        % remove nans
        Ind = find(isnan(deltau) | isnan(deltau_err));
        deltau(Ind) = eps(0);
        deltau_err(Ind) = 1e3;

        %% what if we remove the floating ice?
        if only_grounded_ice
            deltau(GF.node<0.5) = eps(0);
            deltau_err(GF.node<0.5) = 1e-3;
        end

        out.("yr"+yr1+"_yr"+yr2).du = deltau(:);
        out.("yr"+yr1+"_yr"+yr2).stddu = deltau_err(:);
        out.("yr"+yr2).MUA = MUA;
        out.("yr"+yr2).GF = GF;

    elseif ismember(dataformat(dd),["u","LOGu"])

        tmp=load("/path/to/DiagnosticData/"+domain+"/"+domain+"_perturbation_grids.mat");
        MUA = tmp.("MUA_"+years(dd)); GF = tmp.("GF_"+years(dd));

        % interpolate initial and final speed onto Ua mesh
        u_tmp = v.("yr"+years(dd)).F(MUA.coordinates(:,1),MUA.coordinates(:,2));
        std_tmp = std.("yr"+years(dd)).F(MUA.coordinates(:,1),MUA.coordinates(:,2));

        % remove nans

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
