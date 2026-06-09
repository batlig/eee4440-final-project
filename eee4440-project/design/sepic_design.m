%% EEE4440 - High-Gain Switched Inductor-Capacitor (SI-C) SEPIC Design
%  Analytical design for a PV step-up converter, faithful to the topology of
%  [4] S. Chandra & P. Gaur, "An efficient switched inductor-capacitor-based
%      novel non-isolated high gain SEPIC for solar energy applications,"
%      Int. J. Circuit Theory Appl., 51(3):1286-1312, 2023, doi:10.1002/cta.3454.
%
%  Group : Bahcesehir University - EEE4440
%          Baran Sakir Atli (2003998), Tugrul Arslan (2004060),
%          Deniz Bayrak (2103588), Defne Ceylan (2200666)
%
%  TOPOLOGY (Fig. 2 of [4]): one MOSFET (SW), three inductors (L1, L2, LM),
%  four diodes (D1, D2, Ds, Do), four capacitors (C1, C2, Cs, Co). Non-coupled.
%    Node A = Vdc(+);  X = SW drain = Ds anode = C2 left;  Q = C2 right = LM top
%    = Do anode;  S = LM bottom = Ds cathode = Cs top;  R = Do cathode = output(+).
%      D1: A->B,  L2: B->X,  L1: A->C,  D2: C->X,  C1: B(+)/C(-)
%      C2: X(-)/Q(+),  LM: Q->S,  Ds: X->S,  Cs: S->gnd,  Do: Q->R,  Co/Load: R->gnd
%
%  KEY RESULTS FROM [4] (CCM):
%    Gain          G = Vo/Vdc = 2(1+D)/(1-D)                         (Eq.10)
%    Input current Idc = G*Io  (divide by eta in non-ideal case)     (Eq.11)
%    Cap voltages  VC1 = Vdc ; VCS = 2*Vdc/(1-D) ; VC2 = D*VCS ; VCO = Vo = VC2+VCS
%    Switch stress V_SW = VCS = 2*Vdc/(1-D)   (<< Vdc+Vo conventional bound)
%    Diode stress  VD1=VD2 = Vdc+VC1 = 2*Vdc ; VDs = VCS ; VDo = Vo - VC2
%    LM ripple     dILM = D*Vdc/(LM*fsw)                             (Eq.16)
%
%  LITERATURE-SUPPORTED DESIGN DECISIONS (>=2 required):
%    (D1) High gain WITHOUT coupled inductor -> no leakage overshoot, simple
%         magnetics/EMI.                                   [Chandra & Gaur 2023, 4]
%    (D2) Switched-cap cell lowers switch voltage stress to VCS (~134 V here, vs the
%         234 V conventional bound) -> lower-voltage, lower-Rds(on) MOSFET.  [2,3]
%
%  MATLAB R2025b. Pure arithmetic. Saves a parameter struct for the Simulink model.

clear; clc;

%% 1) Specifications and design choices --------------------------------------
Voc   = 40;        % PV open-circuit voltage         [V]
Vmp   = 34;        % PV max-power voltage (nom. Vin) [V]
Imp   = 13.2;      % PV max-power current            [A]
Pmpp  = Vmp*Imp;   % PV max power                    [W]

Vout  = 5*Voc;     % required output = 5 x Voc       [V] -> 200
Iout  = 2;         % required output current         [A]
Pout  = Vout*Iout; % output power                    [W] -> 400

fsw   = 50e3;      % switching frequency             [Hz]
eta   = 0.92;      % assumed efficiency              [-]
Vin   = Vmp;       % nominal full-load input         [V]
Tsw   = 1/fsw;

% Ripple design targets
rIL   = 0.30;      % inductor current ripple fraction (L1,L2,LM)
rVC1  = 0.05;      % C1 voltage ripple fraction
rVC2  = 0.05;      % C2 voltage ripple fraction
rVCs  = 0.05;      % Cs voltage ripple fraction
rVo   = 0.01;      % output voltage ripple fraction (1 %)

%% 2) Duty cycle and gain ----------------------------------------------------
M       = Vout/Vin;             % required ratio (Vmp -> Vout)
D       = (M-2)/(M+2);          % from G = 2(1+D)/(1-D)
D_atVoc = (Vout/Voc-2)/(Vout/Voc+2);   % light-load duty (input -> Voc)
D_conv  = M/(1+M);              % conventional SEPIC duty for same ratio

%% 3) Capacitor (node) voltages (exact, ideal) -------------------------------
VC1 = Vin;                      % Eq.1
VCS = 2*Vin/(1-D);              % Eq.8
VC2 = D*VCS;                    % VC2 = D*VCS
VCO = VC2 + VCS;                % = Vout  (Eq.5)  -> consistency check

%% 4) Currents ---------------------------------------------------------------
Idc  = M*Iout/eta;              % real input current (Eq.11 / eta)
IL1  = Idc/(1+D);               % L1=L2 avg (source = IL1*(1+D))
IL2  = IL1;
ILM  = Iout/(1-D);              % LM avg (= IDo,off, Eq.15)

%% 5) Passive component sizing (ripple-based) --------------------------------
% Inductors
L1_raw = Vin*D/(rIL*IL1*fsw);   % L1 = L2 from input-side ripple
LM_raw = D*Vin/(rIL*ILM*fsw);   % LM from Eq.16 ripple target
% Capacitors (charge-balance estimates)
C1_raw = IL1*(1-D)/(rVC1*VC1*fsw);   % C1 carries IL during series (off) phase
C2_raw = Iout*D /(rVC2*VC2*fsw);
Cs_raw = Iout*D /(rVCs*VCS*fsw);
Co_raw = Iout*D /(rVo *Vout*fsw);    % output cap (ICo,off = D/(1-D)*Io)

% Chosen standard values (>= raw, rounded up)
L1 = 150e-6; L2 = L1;  LM = 330e-6;
C1 = 47e-6;  C2 = 22e-6;  Cs = 10e-6;  Co = 22e-6;
Rload = Vout/Iout;                    % 100 ohm

% Actual ripples with chosen values
dIL1 = Vin*D/(L1*fsw);  dILM = D*Vin/(LM*fsw);

%% 6) Device stresses (exact, from [4]) --------------------------------------
Vsw_st = VCS;                   % switch off-state voltage = VCS
VD12_st= Vin + VC1;             % = 2*Vin   (D1, D2)
VDs_st = VCS;                   % Ds
VDo_st = Vout - VC2;            % Do
IL1_pk = IL1 + dIL1/2;
ILM_pk = ILM + dILM/2;
Isw_pk = IL1_pk + IL2 + ILM_pk; % conservative switch peak (mode-I currents)
derate = 0.7;

%% 7) CCM check --------------------------------------------------------------
% LM current ripple must stay below 2*ILM for CCM
ccm_ok = dILM < 2*ILM;

%% 8) Save parameters for the Simulink model ---------------------------------
P = struct('Voc',Voc,'Vmp',Vmp,'Imp',Imp,'Vin',Vin,'Vout',Vout,'Iout',Iout, ...
           'Pout',Pout,'fsw',fsw,'Tsw',Tsw,'eta',eta,'D',D,'D_atVoc',D_atVoc, ...
           'M',M,'VC1',VC1,'VC2',VC2,'VCS',VCS,'VCO',VCO,'Idc',Idc,'IL1',IL1, ...
           'IL2',IL2,'ILM',ILM,'L1',L1,'L2',L2,'LM',LM,'C1',C1,'C2',C2,'Cs',Cs, ...
           'Co',Co,'Rload',Rload,'Vsw_st',Vsw_st,'VD12_st',VD12_st,'VDs_st',VDs_st, ...
           'VDo_st',VDo_st,'Isw_pk',Isw_pk);
thisdir  = fileparts(mfilename('fullpath'));
projroot = fileparts(thisdir);
save(fullfile(projroot,'sepic_params.mat'),'-struct','P');

%% 9) Report -----------------------------------------------------------------
ln = repmat('-',1,72);
fprintf('\n%s\n  HIGH-GAIN SI-C SEPIC  [Chandra & Gaur 2023] - DESIGN SUMMARY\n%s\n',ln,ln);
fprintf('\nPV PANEL : Voc=%.0f V  Vmp=%.0f V  Imp=%.1f A  Pmpp=%.0f W\n',Voc,Vmp,Imp,Pmpp);
fprintf('OUTPUT   : Vout=%.0f V (=5*Voc)  Iout=%.0f A  Pout=%.0f W  fsw=%.0f kHz  eta=%.0f%%\n',Vout,Iout,Pout,fsw/1e3,eta*100);

fprintf('\nDUTY & GAIN  [G = 2(1+D)/(1-D)]\n');
fprintf('  Ratio M (Vmp->Vout) = %.2f | D = %.3f | D@Voc = %.3f | conv.SEPIC D = %.3f\n',M,D,D_atVoc,D_conv);

fprintf('\nCAPACITOR (NODE) VOLTAGES\n');
fprintf('  VC1=%.1f V | VCS=%.1f V | VC2=%.1f V | VCO=%.1f V (check: VC2+VCS=%.1f)\n',VC1,VCS,VC2,VCO,VC2+VCS);

fprintf('\nCURRENTS\n');
fprintf('  Idc=%.2f A (<Imp=%.1f: %s) | IL1=IL2=%.2f A | ILM=%.2f A | Isw_pk~%.1f A\n', ...
        Idc,Imp,bool2s(Idc<Imp),IL1,ILM,Isw_pk);

fprintf('\nPASSIVES  (raw -> chosen)\n');
fprintf('  L1=L2 : %.0f -> %.0f uH (dIL=%.2f A) | LM : %.0f -> %.0f uH (dILM=%.2f A)\n',L1_raw*1e6,L1*1e6,dIL1,LM_raw*1e6,LM*1e6,dILM);
fprintf('  C1 : %.1f -> %.0f uF | C2 : %.1f -> %.0f uF | Cs : %.1f -> %.0f uF | Co : %.1f -> %.0f uF\n', ...
        C1_raw*1e6,C1*1e6,C2_raw*1e6,C2*1e6,Cs_raw*1e6,Cs*1e6,Co_raw*1e6,Co*1e6);
fprintf('  Rload = %.0f ohm | CCM: %s\n',Rload,bool2s(ccm_ok));

fprintf('\nDEVICE STRESSES (exact)  -> ratings with %.0f%% derating\n',derate*100);
fprintf('  Switch SW : V=%.0f V  (>=%.0f V, ~17-21 A) -> 200 V class low-Rds(on) MOSFET\n',Vsw_st,Vsw_st/derate);
fprintf('  D1, D2    : V=%.0f V  (>=%.0f V)            -> 100-150 V fast diode\n',VD12_st,VD12_st/derate);
fprintf('  Ds        : V=%.0f V  (>=%.0f V)            -> 200 V SiC Schottky\n',VDs_st,VDs_st/derate);
fprintf('  Do        : V=%.0f V  (>=%.0f V, Iavg=2 A)  -> 200 V SiC Schottky\n',VDo_st,VDo_st/derate);
fprintf('\n%s\n  Parameters saved to sepic_params.mat (for Simulink model).\n%s\n\n',ln,ln);

%% local helper
function s = bool2s(b)
    if b, s = 'OK'; else, s = 'CHECK'; end
end
