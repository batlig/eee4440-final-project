%% EEE4440 - Closed-loop validation of the analog voltage-mode controller
%  Same SI-C SEPIC power stage, but the gate is driven by the designed Type-II
%  controller: output sensing (H) -> error vs Vref -> Type-II compensator ->
%  saturation -> PWM comparator (sawtooth) -> MOSFET gate. An input-voltage step
%  (34 -> 30 V) is applied to show the loop holds Vout = 200 V (duty adjusts).
%  This validates the analog design that is implemented in LTspice.
%  MATLAB R2025b (Simulink + Simscape Electrical + Control System Toolbox).

clear; clc; close all; bdclose('all');
thisdir  = fileparts(mfilename('fullpath'));
projroot = fileparts(thisdir);
addpath(thisdir);
P = load(fullfile(projroot,'sepic_params.mat'));
C = load(fullfile(projroot,'ctrl_params.mat'));

Ts=5e-8; Tend=0.03; Vstep_t=0.018; Vin0=P.Vin; Vin1=30; mdl='sepic_sic_cl';

%% Build model ---------------------------------------------------------------
bdclose(mdl); new_system(mdl); load_system('powerlib');
add_block('powerlib/powergui',[mdl '/powergui']);
set_param([mdl '/powergui'],'Position',[20 20 120 70], ...
          'SimulationMode','Discrete','SampleTime',num2str(Ts));

nodes = add_sic_sepic_stage(mdl, P, 0.5, Ts, true);   % extPWM = true

% Input: controlled voltage source (step 34 -> 30 V), +(RConn1)->Vp, -(LConn1)->g
cvs=[mdl '/Vin']; add_block('powerlib/Electrical Sources/Controlled Voltage Source',cvs);
set_param(cvs,'Position',[60 210 95 270]);
phc=get_param(cvs,'PortHandles');
add_line(mdl, phc.RConn(1), nodes('Vp'),'autorouting','on');
add_line(mdl, phc.LConn(1), nodes('g'), 'autorouting','on');
add_block('simulink/Sources/Step',[mdl '/Vstep']);
set_param([mdl '/Vstep'],'Time',num2str(Vstep_t),'Before',num2str(Vin0),'After',num2str(Vin1),'Position',[0 225 30 255]);
add_line(mdl,'Vstep/1','Vin/1','autorouting','on');

% Dedicated output sensing for the loop
vs=[mdl '/Vsense']; add_block('powerlib/Measurements/Voltage Measurement',vs);
set_param(vs,'Position',[840 470 870 500]);
phvs=get_param(vs,'PortHandles');
add_line(mdl, phvs.LConn(1), nodes('R'),'autorouting','on');
add_line(mdl, phvs.LConn(2), nodes('g'),'autorouting','on');

% Controller chain
add_block('simulink/Math Operations/Gain',[mdl '/H']);
set_param([mdl '/H'],'Gain',num2str(C.H),'Position',[760 475 790 505]);
% soft-start reference: ramp 0 -> Vref over 8 ms (prevents integrator windup)
add_block('simulink/Sources/Ramp',[mdl '/Vref_r']);
set_param([mdl '/Vref_r'],'slope',num2str(C.Vref/8e-3),'start','0','InitialOutput','0','Position',[740 600 770 630]);
add_block('simulink/Discontinuities/Saturation',[mdl '/Vref_s']);
set_param([mdl '/Vref_s'],'UpperLimit',num2str(C.Vref),'LowerLimit','0','Position',[800 600 830 630]);
add_block('simulink/Math Operations/Sum',[mdl '/Err']);
set_param([mdl '/Err'],'Inputs','+-','Position',[690 500 720 530]);
% Type-II core as a PI controller with anti-windup + output saturation
% (Gc = Kc(1+s/wz)/(s(1+s/wp)) ~ PI: Kp=Kc/wz, Ki=Kc; HF pole wp realised in LTspice).
Kp = C.Kc/C.wz_c;  Ki = C.Kc;
add_block('simulink/Discrete/Discrete PID Controller',[mdl '/PID']);
set_param([mdl '/PID'],'Controller','PI','TimeDomain','Discrete-time','SampleTime',num2str(Ts), ...
          'P',num2str(Kp),'I',num2str(Ki),'LimitOutput','on', ...
          'UpperSaturationLimit',num2str(0.65*C.Vramp),'LowerSaturationLimit','0', ...
          'AntiWindupMode','clamping','Position',[540 498 600 540]);   % Dmax=0.65 (stay below gain peak)
% HF pole of the Type-II compensator (1/(1+s/wp)) -> attenuates the ~1.9 kHz resonance
Hlpf = c2d(tf(1,[1/C.wp_c 1]), Ts, 'tustin');
add_block('simulink/Discrete/Discrete Transfer Fcn',[mdl '/LPF']);
set_param([mdl '/LPF'],'Numerator',mat2str(Hlpf.Numerator{1},8), ...
          'Denominator',mat2str(Hlpf.Denominator{1},8),'SampleTime',num2str(Ts),'Position',[630 498 690 540]);
add_block('simulink/Sources/Repeating Sequence',[mdl '/Saw']);
set_param([mdl '/Saw'],'rep_seq_t',['[0 ' num2str(P.Tsw) ']'],'rep_seq_y',['[0 ' num2str(C.Vramp) ']'],'Position',[460 575 490 605]);
add_block('simulink/Logic and Bit Operations/Relational Operator',[mdl '/Cmp']);
set_param([mdl '/Cmp'],'Operator','>=','Position',[420 515 450 555]);

add_line(mdl,'Vsense/1','H/1','autorouting','on');
add_line(mdl,'H/1','Err/2','autorouting','on');
add_line(mdl,'Vref_r/1','Vref_s/1','autorouting','on');
add_line(mdl,'Vref_s/1','Err/1','autorouting','on');
add_line(mdl,'Err/1','PID/1','autorouting','on');
add_line(mdl,'PID/1','LPF/1','autorouting','on');
add_line(mdl,'LPF/1','Cmp/1','autorouting','on');
add_line(mdl,'Saw/1','Cmp/2','autorouting','on');
add_line(mdl,'Cmp/1','SW/1','autorouting','on');

% log control voltage
add_block('simulink/Sinks/To Workspace',[mdl '/tw_Vc']);
set_param([mdl '/tw_Vc'],'VariableName','Vc_ts','SaveFormat','Timeseries','Position',[630 440 680 460]);
add_line(mdl,'LPF/1','tw_Vc/1','autorouting','on');

set_param(mdl,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
              'FixedStep',num2str(Ts),'StopTime',num2str(Tend));
save_system(mdl, fullfile(thisdir,[mdl '.slx']));

%% Simulate ------------------------------------------------------------------
fprintf('CLOSED LOOP: simulating %s (input step %g->%g V at %g ms)...\n',mdl,Vin0,Vin1,Vstep_t*1e3);
out = sim(mdl);

%% Post-process --------------------------------------------------------------
[tv,Vo]=sig(out,'Vout_ts'); [~,Vi]=sig(out,'Vin_ts'); [~,Vc]=sig(out,'Vc_ts');
preb  = tv>(Vstep_t-2e-3) & tv<Vstep_t;       % just before the step
postb = tv>(Tend-2e-3);                        % end (after recovery)
Vo_pre=mean(Vo(preb)); Vo_post=mean(Vo(postb));
ln=repmat('-',1,64);
fprintf('\n%s\n  CLOSED-LOOP RESULTS\n%s\n',ln,ln);
fprintf('  Before step (Vin=%g V): Vout = %.2f V\n',Vin0,Vo_pre);
fprintf('  After  step (Vin=%g V): Vout = %.2f V  (regulated to 200 V)\n',Vin1,Vo_post);
fprintf('  Control voltage Vc: %.3f -> %.3f V (duty %.3f -> %.3f)\n', ...
        mean(Vc(preb)),mean(Vc(postb)),mean(Vc(preb))/C.Vramp,mean(Vc(postb))/C.Vramp);
fprintf('%s\n',ln);

%% Figure --------------------------------------------------------------------
figdir=fullfile(projroot,'report','figures'); if ~exist(figdir,'dir'), mkdir(figdir); end
f=figure('Visible','off','Position',[100 100 760 400]);
yyaxis left;  plot(tv*1e3,Vo,'LineWidth',1); ylabel('V_{out} (V)'); ylim([0 230]); hold on; yline(200,'--');
yyaxis right; plot(tv*1e3,Vi,'LineWidth',1); ylabel('V_{in} (V)'); ylim([0 45]);
xlabel('Time (ms)'); grid on;
title('Closed-loop regulation: V_{out} holds 200 V through a 34\rightarrow30 V input step');
exportgraphics(f,fullfile(figdir,'sim_closedloop.png'),'Resolution',150); close(f);
fprintf('Figure saved.\n');

function [t,d]=sig(out,var), ts=out.(var); t=ts.Time; d=squeeze(ts.Data); end
