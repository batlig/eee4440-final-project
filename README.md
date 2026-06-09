# EEE4440 — High-Gain SI-C SEPIC Converter for PV Applications

Group project for **EEE4440 — Power Electronics in Energy Systems**, Bahçeşehir University.
Design, simulation and analog control of a **high-gain switched inductor–capacitor (SI-C)
SEPIC** DC–DC converter that boosts a single PV module (V_oc = 40 V) to a regulated
**200 V / 2 A (400 W)** DC bus.

The topology follows **S. Chandra & P. Gaur, *"An efficient switched inductor–capacitor-based
novel non-isolated high gain SEPIC for solar energy applications,"* Int. J. Circuit Theory
Appl., 51(3):1286–1312, 2023 (doi:10.1002/cta.3454)**, with static gain `M = 2(1+D)/(1−D)`.

**Group members:** Baran Şakir Atlığ (2003998), Tuğrul Arslan (2004060),
Deniz Bayrak (2103588), Defne Ceylan (2200666) · **Instructor:** Nezihe Küçük Yıldıran, Dr. Öğr. Üyesi

---

## Key results (verified in MATLAB R2025b)

| Quantity | Value |
|---|---|
| Output | 200 V / 2 A / 400 W, ripple 0.59 % |
| Duty cycle | D ≈ 0.49 (vs. 0.86 for a conventional SEPIC) |
| PV operation | 99.9 % of MPP (no explicit MPPT) |
| Switch voltage stress | 134 V = 2·V_in/(1−D)  (≈ 43 % below the 234 V conventional bound) |
| Efficiency (sim) | ≈ 90 % |
| Analog controller | voltage-mode Type-II, PM = 60°, GM = 21 dB, f_c = 1 kHz |

---

## Repository structure

```
eee4440-project/
├── README.md                     ← this file
├── design/
│   ├── sepic_design.m            Analytical design → writes sepic_params.mat
│   └── analog_control_design.m   Type-II compensator design → writes ctrl_params.mat + Bode
├── simulink/
│   ├── add_sic_sepic_stage.m     Shared power-stage builder (used by all cases)
│   ├── build_sepic_model.m       Case B: variable DC source  → sepic_sic_dc.slx
│   ├── build_sepic_pv.m          Case A: PV Array source     → sepic_sic_pv.slx
│   ├── build_sepic_closedloop.m  Closed-loop control check   → sepic_sic_cl.slx
│   ├── duty_adjustment_demo.m    Duty-cycle vs input-voltage sweep
│   └── *.slx                     Generated Simulink models
├── ltspice/
│   └── sepic_analog_control.cir  Analog controller netlist (open in LTspice)
├── report/
│   ├── EEE4440_final_report.md   Report source (Markdown)
│   ├── EEE4440_final_report.pdf  ← FINAL REPORT (18 pages)
│   ├── build_pdf.py              Markdown → styled HTML (cover, page breaks)
│   └── figures/                  All simulation & control figures (PNG) + BAU logo
├── sepic_params.mat              Design parameters (generated)
├── ctrl_params.mat               Controller parameters (generated)
└── (source docs) EEE4440_project_2526.pdf, EEE4440_Group_Report.pdf,
    2004060_2.pdf (Chandra & Gaur paper), BAU-Logolar.zip
```

---

## Requirements

- **MATLAB R2025b** with **Simulink**, **Simscape Electrical** (Specialized Power Systems)
  and **Control System Toolbox**.
- **Python 3** with the `markdown` package (`pip install markdown`) — only to rebuild the PDF.
- **Microsoft Edge** (used headless to print the HTML to PDF).
- **LTspice** — to open / run `ltspice/sepic_analog_control.cir`.

---

## How to reproduce

Run the MATLAB scripts in this order (each prints results and saves figures to
`report/figures/`):

1. **`design/sepic_design.m`** — analytical design; creates `sepic_params.mat`.
2. **`design/analog_control_design.m`** — controller design; creates `ctrl_params.mat`
   and the loop-gain Bode figure.
3. **`simulink/build_sepic_pv.m`** — Case A (PV source), ~200 V at 99.9 % MPP.
4. **`simulink/build_sepic_model.m`** — Case B (DC source): startup, ripple, switch-stress figures.
5. **`simulink/duty_adjustment_demo.m`** — duty-cycle adjustment across the input range.
6. **`simulink/build_sepic_closedloop.m`** — closed-loop input-step rejection
   (requires `sepic_params.mat` **and** `ctrl_params.mat`, i.e. run steps 1–2 first).

> Dependency: every model script loads `sepic_params.mat`, so run `sepic_design.m` first;
> `build_sepic_closedloop.m` additionally needs `ctrl_params.mat` from `analog_control_design.m`.

### Rebuild the report PDF

```bash
cd report
python build_pdf.py          # Markdown -> EEE4440_final_report.html (cover + per-section page breaks)
# then print to PDF with Edge headless (use the OLD --headless flag and absolute paths):
"C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless --disable-gpu \
  --no-pdf-header-footer \
  --print-to-pdf="<abs>/report/EEE4440_final_report.pdf" "<abs>/report/EEE4440_final_report.html"
```

### Analog control circuit

Open `ltspice/sepic_analog_control.cir` in LTspice (File ▸ Open) and **Run**. It contains the
output sensing divider, unity-gain buffer, Type-II error amplifier, 50 kHz sawtooth oscillator
and PWM comparator that generate the MOSFET gate signal.

---

## Deliverables (assignment mapping)

- **A. Final Report (PDF):** `report/EEE4440_final_report.pdf`
- **B. MATLAB/Simulink:** `simulink/*.slx` + `simulink/*.m` + `design/*.m`
- **C. Analog controller:** `ltspice/sepic_analog_control.cir`

---

## Notes

- The two **literature-supported design decisions**: (D1) high gain *without* a coupled
  inductor [Chandra & Gaur 2023] → simpler magnetics, no turn-off overshoot; (D2) the
  switched-capacitor cell lowers the switch voltage stress to `2·V_in/(1−D)` [Jayanthi 2025;
  Sumathy 2024] → a lower-voltage, lower-R_DS(on) MOSFET.
- The PDF is produced via Edge headless because no `pandoc`/LaTeX is installed; use the legacy
  `--headless` flag (the newer `--headless=new` did not emit a file in this environment).
- The closed-loop voltage-mode model shows a residual ~2 kHz ripple from the lightly-damped
  switched-capacitor resonances; the loop-gain Bode plot is the primary control validation.
  Active damping or current-mode control would remove the ripple (see report §6.3, §7).
