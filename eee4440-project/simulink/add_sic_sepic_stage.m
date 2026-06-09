function nodes = add_sic_sepic_stage(mdl, P, Dop, Ts, extPWM)
%ADD_SIC_SEPIC_STAGE  Build the high-gain SI-C SEPIC power stage into model MDL.
%  Faithful to Chandra & Gaur (2023), doi:10.1002/cta.3454, Fig. 2.
%  Builds: converter (1 MOSFET, 3 inductors, 4 diodes, 4 capacitors),
%  PWM gate drive, input/output/Vcs/Vsw/Vin measurements and To-Workspace logs.
%  The SOURCE is NOT added here -> connect source(+) to node 'Vp', source(-)
%  to node 'g' in the caller. Returns the node-anchor map (containers.Map).
%
%  Nodes: A=src(+); B; C; X=SW drain=Ds anode=C2 left; Q=C2 right=LM top=Do
%  anode; S=LM bottom=Ds cathode=Cs top; R=output(+); g=ground.
%
%  extPWM (optional, default false): when true the internal open-loop Pulse
%  Generator is omitted so the caller can drive the MOSFET gate ('SW/1') from
%  an external closed-loop PWM (sawtooth + comparator).

if nargin<5, extPWM=false; end
nodes = containers.Map('KeyType','char','ValueType','double');

% --- measurements at the input (source current + input voltage)
Iin = addmeas(mdl,'Imeas_in','I',[120 200 150 230]);
attach(mdl,nodes,'Vp',Iin.LConn(1)); attach(mdl,nodes,'A',Iin.RConn(1));
Vin = addmeas(mdl,'Vmeas_in','V',[120 120 150 150]);
attach(mdl,nodes,'A',Vin.LConn(1)); attach(mdl,nodes,'g',Vin.LConn(2));

% --- switched inductor-capacitor cell:  A-D1-B-L2-X ; A-L1-C-D2-X ; C1: B-C
D1 = adddio(mdl,'D1',[210 120 240 150]);
L2 = addrlc(mdl,'L2','L',P.L2,[290 120 330 150]);
L1 = addrlc(mdl,'L1','L',P.L1,[210 230 250 260]);
D2 = adddio(mdl,'D2',[290 230 320 260]);
C1 = addrlc(mdl,'C1','C',P.C1,[255 170 295 210]);
attach(mdl,nodes,'A',D1.LConn(1)); attach(mdl,nodes,'B',D1.RConn(1));
attach(mdl,nodes,'B',L2.LConn(1)); attach(mdl,nodes,'X',L2.RConn(1));
attach(mdl,nodes,'A',L1.LConn(1)); attach(mdl,nodes,'C',L1.RConn(1));
attach(mdl,nodes,'C',D2.LConn(1)); attach(mdl,nodes,'X',D2.RConn(1));
attach(mdl,nodes,'B',C1.LConn(1)); attach(mdl,nodes,'C',C1.RConn(1));

% --- SEPIC core + output
SW = addmos(mdl,'SW',[430 320 480 380]);
set_param([mdl '/SW'],'Ron','0.02');          % realistic 200 V MOSFET Rds(on)
Ds = adddio(mdl,'Ds',[480 250 510 280]);
C2 = addrlc(mdl,'C2','C',P.C2,[480 120 520 150]);
LM = addrlc(mdl,'LM','L',P.LM,[570 170 610 210]);
Cs = addrlc(mdl,'Cs','C',P.Cs,[570 285 610 325]);
Do = adddio(mdl,'Do',[630 120 660 150]);
Co = addrlc(mdl,'Co','C',P.Co,[710 170 750 210]);
Io = addmeas(mdl,'Imeas_out','I',[710 120 740 150]);
RL = addrlc(mdl,'Rload','R',P.Rload,[790 170 830 210]);
attach(mdl,nodes,'X',SW.LConn(1)); attach(mdl,nodes,'g',SW.RConn(1));
attach(mdl,nodes,'X',Ds.LConn(1)); attach(mdl,nodes,'S',Ds.RConn(1));
attach(mdl,nodes,'X',C2.LConn(1)); attach(mdl,nodes,'Q',C2.RConn(1));
attach(mdl,nodes,'Q',LM.LConn(1)); attach(mdl,nodes,'S',LM.RConn(1));
attach(mdl,nodes,'S',Cs.LConn(1)); attach(mdl,nodes,'g',Cs.RConn(1));
attach(mdl,nodes,'Q',Do.LConn(1)); attach(mdl,nodes,'R',Do.RConn(1));
attach(mdl,nodes,'R',Co.LConn(1)); attach(mdl,nodes,'g',Co.RConn(1));
attach(mdl,nodes,'R',Io.LConn(1)); attach(mdl,nodes,'R2',Io.RConn(1));
attach(mdl,nodes,'R2',RL.LConn(1)); attach(mdl,nodes,'g',RL.RConn(1));

% --- output / node voltage measurements (parallel)
Vo  = addmeas(mdl,'Vmeas_out','V',[770 320 800 350]);
Vcs = addmeas(mdl,'Vmeas_cs','V',[630 330 660 360]);
Vsw = addmeas(mdl,'Vmeas_sw','V',[430 430 460 460]);
attach(mdl,nodes,'R',Vo.LConn(1));  attach(mdl,nodes,'g',Vo.LConn(2));
attach(mdl,nodes,'S',Vcs.LConn(1)); attach(mdl,nodes,'g',Vcs.LConn(2));
attach(mdl,nodes,'X',Vsw.LConn(1)); attach(mdl,nodes,'g',Vsw.LConn(2));

% --- PWM gate drive (open-loop Pulse Generator) unless external PWM requested
if ~extPWM
    pwm = [mdl '/PWM']; add_block('simulink/Sources/Pulse Generator', pwm);
    set_param(pwm,'Position',[300 340 340 380]);
    nper = round(P.Tsw/Ts); on_steps = round(Dop*nper); Deff = on_steps/nper;
    set_param(pwm,'PulseType','Time based','Period',num2str(nper*Ts), ...
                  'PulseWidth',num2str(Deff*100),'Amplitude','1','PhaseDelay','0');
    add_line(mdl,'PWM/1','SW/1','autorouting','on');
end

% --- signal logging
tw(mdl,'tw_Vout','Vout_ts',[860 320 910 350], Vo.Outport(1));
tw(mdl,'tw_Iout','Iout_ts',[770 120 820 150], Io.Outport(1));
tw(mdl,'tw_Iin', 'Iin_ts', [170 200 220 230], Iin.Outport(1));
tw(mdl,'tw_Vin', 'Vin_ts', [170 120 220 150], Vin.Outport(1));
tw(mdl,'tw_Vcs', 'Vcs_ts', [710 330 760 360], Vcs.Outport(1));
tw(mdl,'tw_Vsw', 'Vsw_ts', [510 430 560 460], Vsw.Outport(1));
end

%% ===================== local helper functions =============================
function attach(mdl,nodes,node,ph)
    if isKey(nodes,node), add_line(mdl, ph, nodes(node), 'autorouting','on');
    else, nodes(node) = ph; end
end
function ph = addrlc(mdl,name,type,val,pos)
    b=[mdl '/' name]; add_block('powerlib/Elements/Series RLC Branch',b);
    switch type
        case 'L', set_param(b,'BranchType','L','Inductance',num2str(val));
        case 'C', set_param(b,'BranchType','RC','Capacitance',num2str(val),'Resistance','0.03');
        case 'R', set_param(b,'BranchType','R','Resistance',num2str(val));
    end
    set_param(b,'Position',pos); ph=get_param(b,'PortHandles');
end
function ph = adddio(mdl,name,pos)
    b=[mdl '/' name]; add_block('powerlib/Power Electronics/Diode',b);
    set_param(b,'Position',pos); ph=get_param(b,'PortHandles');
end
function ph = addmos(mdl,name,pos)
    b=[mdl '/' name]; add_block('powerlib/Power Electronics/Mosfet',b);
    set_param(b,'Position',pos); ph=get_param(b,'PortHandles');
end
function ph = addmeas(mdl,name,kind,pos)
    if kind=='V', src='powerlib/Measurements/Voltage Measurement';
    else,         src='powerlib/Measurements/Current Measurement'; end
    b=[mdl '/' name]; add_block(src,b);
    set_param(b,'Position',pos); ph=get_param(b,'PortHandles');
end
function tw(mdl,name,var,pos,srcport)
    b=[mdl '/' name]; add_block('simulink/Sinks/To Workspace',b);
    set_param(b,'VariableName',var,'SaveFormat','Timeseries','Position',pos);
    ph=get_param(b,'PortHandles'); add_line(mdl, srcport, ph.Inport(1),'autorouting','on');
end
