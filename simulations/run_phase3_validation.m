function summary = run_phase3_validation()
%RUN_PHASE3_VALIDATION Execute battery and microgrid-transition validations.
root=fileparts(mfilename('fullpath'));
names=["Battery equivalent circuit";"Droop/islanding/reconnection"];
commands={ ...
    sprintf("addpath('%s'); run_battery_validation();",escape_quotes(fullfile(root,'battery'))); ...
    sprintf("addpath('%s'); run_microgrid_transition_validation();",escape_quotes(fullfile(root,'microgrid')))};
passed=false(2,1); elapsed_s=nan(2,1); message=strings(2,1);
for k=1:2
    started=tic;
    try
        evalin('base',commands{k}); passed(k)=true; message(k)="PASS";
    catch exception
        message(k)=string(exception.message);
    end
    elapsed_s(k)=toc(started);
end
summary=table(names,passed,elapsed_s,message);
dest=fullfile(root,'results'); if ~exist(dest,'dir'); mkdir(dest); end
writetable(summary,fullfile(dest,'phase3_regression_summary.csv'));
save(fullfile(dest,'phase3_regression_summary.mat'),'summary');
disp(summary); assert(all(passed),'Phase 3 simulation regression failed.');
fprintf('PASS: all Phase 3 simulation validation stages completed.\n');
end

function value=escape_quotes(value)
value=strrep(value,"'","''");
end
