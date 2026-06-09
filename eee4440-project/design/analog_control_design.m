%% EEE4440 - Analog voltage-mode controller design for the SI-C SEPIC
%  Designs a Type-II compensator for output-voltage regulation and produces the
%  real RC component values used in the LTspice analog control circuit.
%
%  Plant model (control-to-output, dominant behaviour of the high-gain SI-C SEPIC):
%     - DC gain     Gdo = dVout/dD = Vin*4/(1-D)^2     (from G=2(1+D)/(1-D))
%     - output pole wp1 = 1/(R*Co)
%     - RHP zero    wz  = R*(1-D)^2/LM   (boost-derived; limits achievable fc)
%  Modulator: sawtooth PWM, gain Gm = 1/Vramp.  Sensor: divider H = Vref/Vout.
%  Compensator: Type-II  Gc(s) = Kc (1 + s/wz_c) / [ s (1 + s/wp_c) ]  (K-factor).
%
%  MATLAB R2025b + Control System Toolbox.

clear; clc; close all;
thisdir  = fileparts(mfilename('fullpath'));
projroot = fileparts(thisdir);
P = load(fullfile(projroot,'sepic_params.mat'));

%% Operating point & plant ---------------------------------------------------
Vin=P.Vin; Vout=P.Vout; D=P.D; R=P.Rload; Co=P.Co; LM=P.LM;
Gdo = Vin*4/(1-D)^2;            % control-to-output DC gain [V per unit duty]
wp1 = 1/(R*Co);                % dominant output pole [rad/s]
wz  = R*(1-D)^2/LM;            % RHP zero [rad/s]
s   = tf('s');
Gvd = Gdo*(1 - s/wz)/(1 + s/wp1);

%% Modulator + sensor --------------------------------------------------------
Vramp = 2.5;  Gm = 1/Vramp;     % PWM ramp 2.5 Vpp (SG3525-class)
Vref  = 2.5;  H  = Vref/Vout;   % feedback divider scales 200 V -> 2.5 V
Gp = Gvd*Gm*H;                  % uncompensated loop gain (no compensator)

%% Type-II compensator via K-factor ------------------------------------------
fc = 1e3;  wc = 2*pi*fc;  PM = 60;          % crossover: above the 72 Hz output pole,
                                            % below the 12 kHz RHP zero / SC resonances
[mag,ph] = bode(Gp,wc); mag=squeeze(mag); ph=squeeze(ph);
boost = PM - 90 - ph;                       % required phase boost [deg]
K  = tand(45 + boost/2);
wz_c = wc/K;  wp_c = wc*K;
GcShape = (1+1i*wc/wz_c)/((1i*wc)*(1+1i*wc/wp_c));
Kc = 1/(mag*abs(GcShape));                  % set |T(wc)| = 1
Gc = Kc*(1+s/wz_c)/(s*(1+s/wp_c));
T  = Gp*Gc;                                 % compensated loop gain

[GMt,PMt,wcg,wcp] = margin(T);

%% Map compensator to op-amp Type-II RC network ------------------------------
% Feedback divider (Vout -> 2.5 V) followed by a unity-gain buffer, so the
% compensator input resistor R1 is independent and small -> practical passives.
Rbot = 10e3;
Rtop = Rbot*(Vout/Vref - 1);                % sensing divider top resistor
R1   = 10e3;                                % EA input resistor (after buffer)
% Type-II op-amp:  wz_c=1/(Rf*Cf); St=Cf+Cp=1/(R1*Kc); wp_c=(Cf+Cp)/(Rf*Cf*Cp)
St = 1/(R1*Kc);
Cp = St*wz_c/wp_c;
Cf = St - Cp;
Rf = 1/(wz_c*Cf);

%% Report --------------------------------------------------------------------
ln=repmat('-',1,66);
fprintf('\n%s\n  ANALOG VOLTAGE-MODE CONTROL DESIGN (Type-II)\n%s\n',ln,ln);
fprintf('PLANT  Gdo=%.0f V/dty | f_pole=%.1f Hz | f_RHPzero=%.0f Hz\n',Gdo,wp1/2/pi,wz/2/pi);
fprintf('MODULATOR Vramp=%.1f V (Gm=%.3f) | SENSOR H=%.4f (Vref=%.1f V)\n',Vramp,Gm,H,Vref);
boost_disp = mod(boost+180,360)-180;        % normalise for display
fprintf('\nTARGET fc=%.0f Hz, PM=%.0f deg -> phase boost=%.1f deg, K=%.2f\n',fc,PM,boost_disp,K);
fprintf('COMPENSATOR  fz_c=%.0f Hz | fp_c=%.0f Hz | Kc=%.3e\n',wz_c/2/pi,wp_c/2/pi,Kc);
fprintf('ACHIEVED loop: crossover=%.0f Hz | PM=%.1f deg | GM=%.1f dB\n',wcp/2/pi,PMt,20*log10(GMt));
fprintf('\nCOMPONENT VALUES (sensing divider + buffer + op-amp Type-II, Vref=2.5 V)\n');
fprintf('  Sensing : Rtop=%.0f kohm , Rbot=%.0f kohm (gives %.2f V at Vout=200 V) + unity buffer\n',Rtop/1e3,Rbot/1e3,Vref);
fprintf('  Comp.   : R1=%.0f kohm , Rf=%.1f kohm , Cf=%.2f nF , Cp=%.0f pF\n',R1/1e3,Rf/1e3,Cf*1e9,Cp*1e12);
fprintf('%s\n',ln);

% save compensator params for the closed-loop Simulink check
ctrl = struct('Vramp',Vramp,'Vref',Vref,'H',H,'fc',fc,'PM',PMt,'GM_dB',20*log10(GMt), ...
              'wz_c',wz_c,'wp_c',wp_c,'Kc',Kc,'Rtop',Rtop,'Rbot',Rbot,'Rf',Rf,'Cf',Cf,'Cp',Cp, ...
              'num',Gc.Numerator{1},'den',Gc.Denominator{1});
save(fullfile(projroot,'ctrl_params.mat'),'-struct','ctrl');

%% Bode of loop gain ---------------------------------------------------------
figdir=fullfile(projroot,'report','figures'); if ~exist(figdir,'dir'), mkdir(figdir); end
f=figure('Visible','off','Position',[100 100 720 540]);
margin(T); grid on;
title(sprintf('Loop gain  T(s)  (fc=%.0f Hz, PM=%.0f deg)',wcp/2/pi,PMt));
exportgraphics(f,fullfile(figdir,'ctrl_loop_bode.png'),'Resolution',150); close(f);
fprintf('Bode figure saved. ctrl_params.mat written.\n');
