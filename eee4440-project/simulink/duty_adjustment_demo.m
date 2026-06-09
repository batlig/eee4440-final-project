%% EEE4440 - CASE B (duty-cycle adjustment demonstration)
%  Sweeps the input voltage (as a PV panel would vary with irradiance/temp) and,
%  for each input, finds the duty cycle that keeps Vout = 200 V. Demonstrates the
%  duty-cycle adjustment requirement and the control range of the SI-C SEPIC.
%  Same converter as build_sepic_model.m (add_sic_sepic_stage), DC source.

clear; clc; close all; bdclose('all');
thisdir  = fileparts(mfilename('fullpath'));
projroot = fileparts(thisdir);
addpath(thisdir);
P = load(fullfile(projroot,'sepic_params.mat'));

Ts=1e-7; Tend=0.015; mdl='sepic_sic_sweep';
Vlist=[40 37 34 31 28];                 % input-voltage operating points [V]

%% Build the model once ------------------------------------------------------
bdclose(mdl); new_system(mdl); load_system('powerlib');
add_block('powerlib/powergui',[mdl '/powergui']);
set_param([mdl '/powergui'],'Position',[20 20 120 70], ...
          'SimulationMode','Discrete','SampleTime',num2str(Ts));
nodes = add_sic_sepic_stage(mdl, P, 0.5, Ts);    % duty set per-iteration below
Vdc=[mdl '/Vdc']; add_block('powerlib/Electrical Sources/DC Voltage Source',Vdc);
set_param(Vdc,'Amplitude','34','Position',[40 210 70 270]);
phs=get_param(Vdc,'PortHandles');
add_line(mdl, phs.RConn(1), nodes('Vp'),'autorouting','on');
add_line(mdl, phs.LConn(1), nodes('g'), 'autorouting','on');
set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
              'FixedStep',num2str(Ts),'StopTime',num2str(Tend));

%% Sweep: for each Vin, adjust D to regulate Vout to 200 V -------------------
nper=round(P.Tsw/Ts); Did=zeros(size(Vlist)); Dset=Did; Vout=Did;
fprintf('\n  Vin(V) | D_ideal | D_set  | Vout(V)\n  -------+---------+--------+--------\n');
for k=1:numel(Vlist)
    Vin=Vlist(k); set_param(Vdc,'Amplitude',num2str(Vin));
    M=200/Vin; Did(k)=(M-2)/(M+2); D=Did(k)+0.02;     % start near ideal + loss offset
    for it=1:2
        on=round(D*nper); Duse=on/nper;
        set_param([mdl '/PWM'],'Period',num2str(nper*Ts),'PulseWidth',num2str(Duse*100));
        out=sim(mdl); [tv,Vo]=sig(out,'Vout_ts'); Vss=mean(Vo(tv>0.8*Tend));
        if it<2, D=Duse+(200-Vss)/(Vin*16.6); D=min(max(D,0.05),0.80); end
    end
    Dset(k)=Duse; Vout(k)=Vss;
    fprintf('   %4.0f  |  %.3f  | %.3f  | %6.2f\n',Vin,Did(k),Dset(k),Vss);
end

%% Figure: duty cycle vs input voltage ---------------------------------------
figdir=fullfile(projroot,'report','figures'); if ~exist(figdir,'dir'), mkdir(figdir); end
f=figure('Visible','off','Position',[100 100 760 400]);
yyaxis left;  plot(Vlist,Dset,'-o','LineWidth',1.5); ylabel('Duty cycle D'); ylim([0.35 0.65]);
yyaxis right; plot(Vlist,Vout,'-s','LineWidth',1.5); ylabel('V_{out} (V)'); ylim([195 205]);
xlabel('Input voltage V_{in} (V)'); grid on;
title('Duty-cycle adjustment: D regulates V_{out}=200 V over the input range');
exportgraphics(f,fullfile(figdir,'sim_duty_adjust.png'),'Resolution',150); close(f);
fprintf('\nControl range: D = %.3f (Vin=%.0f) to %.3f (Vin=%.0f). Figure saved.\n', ...
        Dset(1),Vlist(1),Dset(end),Vlist(end));

function [t,d]=sig(out,var), ts=out.(var); t=ts.Time; d=squeeze(ts.Data); end
