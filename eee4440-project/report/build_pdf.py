#!/usr/bin/env python3
"""Convert EEE4440_final_report.md -> styled HTML with a professional cover page
   (BAU logo + faculty/department/course/title/group/instructor/date), a page break
   before the References, and a compact references block that fits one page.
   Then print to PDF with Microsoft Edge headless (see command in the README/below)."""
import markdown, pathlib

D = pathlib.Path(__file__).resolve().parent
md_text = (D / "EEE4440_final_report.md").read_text(encoding="utf-8")

# ---- split: drop the simple in-markdown header (cover replaces it) ----------
body = md_text[md_text.index("## Abstract"):]
ref_marker = "## References"
main_md, refs_md = body.split(ref_marker, 1)
refs_md = ref_marker + refs_md

EXT = ["tables", "fenced_code", "sane_lists", "attr_list"]
main_html = markdown.markdown(main_md, extensions=EXT)
refs_html = markdown.markdown(refs_md, extensions=EXT)

TITLE = ("Design and Analysis of a High-Gain Switched Inductor-Capacitor "
         "SEPIC Converter for Photovoltaic Applications")
MEMBERS = [("Baran Şakir Atlı", "2003998"), ("Tuğrul Arslan", "2004060"),
           ("Deniz Bayrak", "2103588"), ("Defne Ceylan", "2200666")]
members_html = "".join(f"<div class='member'>{n} &mdash; {i}</div>" for n, i in MEMBERS)

cover = f"""
<section class="cover">
  <img class="logo" src="figures/bau_logo.png" alt="BAU logo">
  <div class="univ">Bahçeşehir University</div>
  <div class="fac">Faculty of Engineering and Natural Sciences</div>
  <div class="dept">Department of Electrical and Electronics Engineering</div>
  <div class="course">EEE4440 &mdash; Power Electronics in Energy Systems</div>
  <div class="rsub">Final Project Report</div>
  <div class="title">{TITLE}</div>
  <div class="block">
    <div class="sec-h">Group Members</div>
    {members_html}
  </div>
  <div class="block">
    <div class="sec-h">Course Instructor</div>
    <div class="member">Nezihe Küçük Yıldıran</div>
    <div class="instr-title">Dr. Öğr. Üyesi</div>
  </div>
  <div class="date">June 2026</div>
</section>
"""

CSS = """
@page { size: A4; margin: 17mm 16mm; }
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', Calibri, Arial, sans-serif; font-size: 10.4pt;
       line-height: 1.42; color: #141414; }
/* ---------- cover page ---------- */
.cover { text-align: center; font-family: Georgia, 'Times New Roman', serif;
         padding-top: 6mm; }
.cover .logo { width: 150px; height: auto; margin: 0 auto 13mm; display: block; }
.cover .univ { font-size: 23pt; font-weight: bold; margin-bottom: 3mm; }
.cover .fac  { font-size: 13.5pt; }
.cover .dept { font-size: 13.5pt; margin-bottom: 13mm; }
.cover .course { font-size: 13.5pt; font-weight: bold; margin-bottom: 12mm; }
.cover .rsub { font-size: 12pt; font-style: italic; color: #555; margin-bottom: 3mm; }
.cover .title { font-size: 18.5pt; font-weight: bold; line-height: 1.32;
                margin: 0 6mm 15mm; }
.cover .block { margin-bottom: 11mm; }
.cover .sec-h { font-size: 13pt; font-weight: bold; margin-bottom: 3mm; }
.cover .member { font-size: 12pt; line-height: 1.7; }
.cover .instr-title { font-size: 11pt; font-style: italic; color: #444; }
.cover .date { font-size: 12pt; margin-top: 6mm; }
/* ---------- body ---------- */
h1 { font-size: 18pt; text-align: center; margin: 0 0 4pt; }
h2 { font-size: 13.5pt; border-bottom: 1.5px solid #2a4d7a; color: #1d3a5f;
     padding-bottom: 2pt; margin: 16pt 0 6pt;
     page-break-before: always; break-before: page; }
h3 { font-size: 11.5pt; color: #2a4d7a; margin: 11pt 0 4pt; }
p  { margin: 5pt 0; text-align: justify; }
table { border-collapse: collapse; width: 100%; margin: 7pt 0; font-size: 9.6pt; }
th, td { border: 1px solid #b9bfc7; padding: 3.5pt 6pt; text-align: left; vertical-align: top; }
th { background: #eef2f7; }
tr:nth-child(even) td { background: #f7f9fb; }
img { max-width: 88%; display: block; margin: 8pt auto 2pt; }
code { font-family: Consolas, monospace; background: #f0f2f4; padding: 0 3px;
       border-radius: 3px; font-size: 9.4pt; }
blockquote { border-left: 3px solid #2a4d7a; margin: 7pt 0; padding: 2pt 10pt;
             background: #f5f7fa; }
hr { border: 0; border-top: 1px solid #cbd2da; margin: 12pt 0; }
em { font-style: italic; }
h2, h3 { page-break-after: avoid; }
table, img, blockquote { page-break-inside: avoid; }
/* ---------- references on their own final page, compact ---------- */
.references { font-size: 9pt; }   /* page break comes from the h2 rule */
.references h2 { margin-top: 0; }
.references p { margin: 4pt 0; text-align: left; }
"""

html = (
    "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
    f"<style>{CSS}</style></head><body>"
    f"{cover}{main_html}<div class='references'>{refs_html}</div>"
    "</body></html>"
)
out = D / "EEE4440_final_report.html"
out.write_text(html, encoding="utf-8")
print("HTML written:", out)

# To make the PDF (Microsoft Edge headless):
#   msedge --headless --disable-gpu --no-pdf-header-footer
#          --print-to-pdf="EEE4440_final_report.pdf" "EEE4440_final_report.html"
