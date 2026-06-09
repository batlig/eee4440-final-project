%% EEE4440 - CASE A: High-Gain SI-C SEPIC fed by a PV Array
%  Same converter as Case B (built by add_sic_sepic_stage) but the source is a
%  Simscape Electrical PV Array configured to the project panel. Demonstrates
%  operation from a real (nonlinear) PV source near its MPP, delivering ~200 V.
%  MATLAB R2025b (Simulink + Simscape Electrical Specialized Power Systems).

clear; clc; close all; bdclose('all');
thisdir  = fileparts(mfilename('fullpath'));
projroot = fileparts(thisdir);
addpath(thisdir);
P = load(fullfile(projroot,'sepic_params.mat'));

Ts    = 5e-8;    Tend = 0.025;    Dop = 0.513;
G_irr = 1000;    T_cell = 25;             % STC irradiance [W/m^2] and temp [degC]
mdl   = 'sepic_sic_pv';

%% Build model ---------------------------------------------------------------
bdclose(mdl); new_system(mdl); load_system('powerlib'); load_system('sps_lib');
add_block('powerlib/powergui',[mdl '/powergui']);
set_param([mdl '/powergui'],'Position',[20 20 120 70], ...
          'SimulationMode','Discrete','SampleTime',num2str(Ts));

nodes = add_sic_sepic_stage(mdl, P, Dop, Ts);

% Input decoupling capacitor across the PV terminals (standard for PV converters;
% stabilises the PV operating voltage and absorbs the switched-capacitor spikes)
cin=[mdl '/Cin']; add_block('powerlib/Elements/Series RLC Branch',cin);
set_param(cin,'BranchType','RC','Capacitance','100e-6','Resistance','0.02','Position',[160 240 195 285]);
phc=get_param(cin,'PortHandles');
add_line(mdl, phc.LConn(1), nodes('A'),'autorouting','on');
add_line(mdl, phc.RConn(1), nodes('g'),'autorouting','on');

% PV Array configured to the project panel (single 450 W, 60-cell-format module)
pv=[mdl '/PV']; add_block('sps_lib/Sources/PV Array',pv);
set_param(pv,'Position',[10 200 120 320]);
set_param(pv,'ModuleName','User-defined','Nser','1','Npar','1','Ncell','72', ...
             'Voc','40','Isc','13.9','Vm','34','Im','13.2');
phpv=get_param(pv,'PortHandles');
add_line(mdl, phpv.RConn(1), nodes('Vp'),'autorouting','on');   % PV(+) -> input
add_line(mdl, phpv.RConn(2), nodes('g'), 'autorouting','on');   % PV(-) -> ground

% Irradiance & temperature inputs (constants)
addconst(mdl,'Irr', G_irr,  [ -120 215 -70 245]);
addconst(mdl,'Temp',T_cell, [ -120 275 -70 305]);
add_line(mdl,'Irr/1', 'PV/1','autorouting','on');
add_line(mdl,'Temp/1','PV/2','autorouting','on');
% terminate PV measurement bus
add_block('simulink/Sinks/Terminator',[mdl '/PVterm']);
set_param([mdl '/PVterm'],'Position',[140 250 160 270]);
add_line(mdl, phpv.Outport(1), get_param([mdl '/PVterm'],'PortHandles').Inport(1),'autorouting','on');

set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
              'FixedStep',num2str(Ts),'StopTime',num2str(Tend));
save_system(mdl, fullfile(thisdir,[mdl '.slx']));

%% Simulate ------------------------------------------------------------------
fprintf('CASE A (PV source): simulating %s (G=%d W/m^2, T=%d C, Dop=%.4f)...\n',mdl,G_irr,T_cell,Dop);
out = sim(mdl);

%% Post-process --------------------------------------------------------------
[tv,Vo_d]=sig(out,'Vout_ts'); [~,Io_d]=sig(out,'Iout_ts');
[~,Ii_d]=sig(out,'Iin_ts');   [~,Vi_d]=sig(out,'Vin_ts');
ss = tv > 0.8*Tend;
Vo_ss=mean(Vo_d(ss)); Vo_pp=max(Vo_d(ss))-min(Vo_d(ss));
Io_ss=mean(Io_d(ss)); Vpv=mean(Vi_d(ss)); Ipv=mean(Ii_d(ss)); Ppv=Vpv*Ipv;

ln=repmat('-',1,64);
fprintf('\n%s\n  CASE A RESULTS (PV source, steady state)\n%s\n',ln,ln);
fprintf('  PV operating point : Vpv=%.2f V (Vmp=%.0f), Ipv=%.2f A (Imp=%.1f)\n',Vpv,P.Vmp,Ipv,P.Imp);
fprintf('  PV power Ppv=%.1f W of Pmpp=%.0f W  -> %.1f %% of MPP\n',Ppv,P.Vmp*P.Imp,100*Ppv/(P.Vmp*P.Imp));
fprintf('  Vout=%.2f V (target 200) | Vout ripple=%.2f V (%.2f %%) | Iout=%.3f A\n',Vo_ss,Vo_pp,100*Vo_pp/Vo_ss,Io_ss);
fprintf('  Conversion efficiency = %.1f %%\n',100*(Vo_ss*Io_ss)/Ppv);
fprintf('%s\n',ln);

%% Figures -------------------------------------------------------------------
figdir=fullfile(projroot,'report','figures'); if ~exist(figdir,'dir'), mkdir(figdir); end
tms=tv*1e3;
% Vout startup (PV-fed)
f=figure('Visible','off','Position',[100 100 760 380]);
plot(tms,Vo_d,'b','LineWidth',1); hold on; yline(200,'r--','200 V');
xlabel('Time (ms)'); ylabel('V_{out} (V)'); grid on;
title(sprintf('PV-fed converter: output voltage (V_{ss}=%.1f V)',Vo_ss));
exportgraphics(f,fullfile(figdir,'sim_pv_vout.png'),'Resolution',150); close(f);
% PV operating point (voltage & power)
f=figure('Visible','off','Position',[100 100 760 400]);
yyaxis left;  plot(tms,Vi_d,'LineWidth',1); ylabel('V_{PV} (V)'); hold on; yline(P.Vmp,'--');
yyaxis right; plot(tms,Vi_d.*Ii_d,'LineWidth',1); ylabel('P_{PV} (W)');
xlabel('Time (ms)'); grid on;
title(sprintf('PV operating point: V_{PV}=%.1f V (V_{mp}=%.0f), P_{PV}=%.0f W (P_{mpp}=%.0f W)',Vpv,P.Vmp,Ppv,P.Vmp*P.Imp));
exportgraphics(f,fullfile(figdir,'sim_pv_operating.png'),'Resolution',150); close(f);
fprintf('Figures saved to %s\n',figdir);

%% local helpers -------------------------------------------------------------
function [t,d]=sig(out,var), ts=out.(var); t=ts.Time; d=squeeze(ts.Data); end
function addconst(mdl,name,val,pos)
    b=[mdl '/' name]; add_block('simulink/Sources/Constant',b);
    set_param(b,'Value',num2str(val),'Position',pos);
end
