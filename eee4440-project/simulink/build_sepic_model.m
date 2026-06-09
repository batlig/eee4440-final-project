%% EEE4440 - CASE B: High-Gain SI-C SEPIC fed by a (variable) DC source
%  Builds the converter via add_sic_sepic_stage(), runs open-loop, and
%  demonstrates the correct 200 V output, startup, steady-state and ripple.
%  Topology: Chandra & Gaur (2023), doi:10.1002/cta.3454.
%  MATLAB R2025b (Simulink + Simscape Electrical Specialized Power Systems).

clear; clc; close all; bdclose('all');
thisdir  = fileparts(mfilename('fullpath'));
projroot = fileparts(thisdir);
addpath(thisdir);                      % make add_sic_sepic_stage visible
P = load(fullfile(projroot,'sepic_params.mat'));

Ts   = 5e-8;     % discrete step (20 MHz -> 400 pts/period @ 50 kHz)
Tend = 0.02;     % stop time [s]
Dop  = 0.513;    % operating duty (open-loop): real losses still give 200 V
mdl  = 'sepic_sic_dc';

%% Build model ---------------------------------------------------------------
bdclose(mdl); new_system(mdl); load_system('powerlib');
add_block('powerlib/powergui',[mdl '/powergui']);
set_param([mdl '/powergui'],'Position',[20 20 120 70], ...
          'SimulationMode','Discrete','SampleTime',num2str(Ts));

nodes = add_sic_sepic_stage(mdl, P, Dop, Ts);

% DC voltage source: +(RConn1)->Vp, -(LConn1)->g
Vdc=[mdl '/Vdc']; add_block('powerlib/Electrical Sources/DC Voltage Source',Vdc);
set_param(Vdc,'Amplitude',num2str(P.Vin),'Position',[40 210 70 270]);
phs=get_param(Vdc,'PortHandles');
add_line(mdl, phs.RConn(1), nodes('Vp'),'autorouting','on');
add_line(mdl, phs.LConn(1), nodes('g'), 'autorouting','on');

set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
              'FixedStep',num2str(Ts),'StopTime',num2str(Tend));
save_system(mdl, fullfile(thisdir,[mdl '.slx']));

%% Simulate ------------------------------------------------------------------
fprintf('CASE B (DC source): simulating %s (Vin=%.0f V, Dop=%.4f)...\n',mdl,P.Vin,Dop);
out = sim(mdl);

%% Post-process --------------------------------------------------------------
[tv,Vo_d]=sig(out,'Vout_ts'); [~,Io_d]=sig(out,'Iout_ts');
[~,Ii_d]=sig(out,'Iin_ts');   [~,Vi_d]=sig(out,'Vin_ts');
[~,Vcs_d]=sig(out,'Vcs_ts');  [~,Vsw_d]=sig(out,'Vsw_ts');
ss = tv > 0.8*Tend;
Vo_ss=mean(Vo_d(ss)); Vo_pp=max(Vo_d(ss))-min(Vo_d(ss));
Io_ss=mean(Io_d(ss)); Ii_ss=mean(Ii_d(ss)); Vi_ss=mean(Vi_d(ss)); Vcs_ss=mean(Vcs_d(ss));

ln=repmat('-',1,64);
fprintf('\n%s\n  CASE B RESULTS (steady state)\n%s\n',ln,ln);
fprintf('  Vin  = %7.2f V | Vout = %7.2f V (target 200) | gain = %.2f\n',Vi_ss,Vo_ss,Vo_ss/Vi_ss);
fprintf('  Vout ripple = %.2f V (%.2f %%) | Iout = %.3f A | Iin = %.2f A\n',Vo_pp,100*Vo_pp/Vo_ss,Io_ss,Ii_ss);
fprintf('  VCS = %.1f V (analytic %.1f) | efficiency = %.1f %%\n',Vcs_ss,P.VCS,100*(Vo_ss*Io_ss)/(Vi_ss*Ii_ss));
fprintf('%s\n',ln);

%% Figures -------------------------------------------------------------------
figdir=fullfile(projroot,'report','figures'); if ~exist(figdir,'dir'), mkdir(figdir); end
tms=tv*1e3; zw=tv>(Tend-4*P.Tsw); tz=(tv(zw)-min(tv(zw)))*1e6;

savefig1(tms,Vo_d,200,'Time (ms)','V_{out} (V)', ...
    sprintf('Output voltage - startup & steady state (V_{ss}=%.1f V)',Vo_ss), ...
    fullfile(figdir,'sim_vout_startup.png'));
savefig2(tz,Vo_d(zw),'Time (\mus)','V_{out} (V)', ...
    sprintf('Steady-state output ripple  \\DeltaV_{pp}=%.2f V (%.2f %%)',Vo_pp,100*Vo_pp/Vo_ss), ...
    fullfile(figdir,'sim_vout_ripple.png'));
savefig2(tz,Ii_d(zw),'Time (\mus)','I_{in} (A)', ...
    sprintf('Continuous input current  I_{in,avg}=%.2f A',Ii_ss), ...
    fullfile(figdir,'sim_iin.png'));
savefig2(tz,Vsw_d(zw),'Time (\mus)','V_{SW} (V)', ...
    sprintf('Switch voltage (off-state \\approx V_{CS}=%.0f V, vs V_{in}+V_o=234 V)',P.VCS), ...
    fullfile(figdir,'sim_vsw.png'));
fprintf('Figures saved to %s\n',figdir);

%% local helpers -------------------------------------------------------------
function [t,d]=sig(out,var), ts=out.(var); t=ts.Time; d=squeeze(ts.Data); end
function savefig1(x,y,yref,xl,yl,ti,fn)
    f=figure('Visible','off','Position',[100 100 760 380]);
    plot(x,y,'b','LineWidth',1); hold on; yline(yref,'r--',sprintf('%g',yref));
    xlabel(xl); ylabel(yl); title(ti); grid on;
    exportgraphics(f,fn,'Resolution',150); close(f);
end
function savefig2(x,y,xl,yl,ti,fn)
    f=figure('Visible','off','Position',[100 100 760 360]);
    plot(x,y,'LineWidth',1.2); xlabel(xl); ylabel(yl); title(ti); grid on;
    exportgraphics(f,fn,'Resolution',150); close(f);
end
