#!/usr/bin/env python3
# File:        regress.py
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Runs every test over seeds and configurations and reports results and coverage. With --mutants, checks that each planted RTL bug is caught.

import argparse
import concurrent.futures as cf
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = ["fifo_smoke_test", "fifo_fill_drain_test", "fifo_glitch_test", "fifo_boundary_test",
         "fifo_flags_test", "fifo_clear_reset_test", "fifo_random_test"]
CONFIGS = {"C1": (8, 8), "C2": (32, 32), "C3": (1, 2), "C4": (8, 16), "C5": (8, 1)}
RTL = os.path.join(ROOT, "rtl", "socetlib_fifo.sv")
PORTS = ["CLK", "nRST", "WEN", "REN", "clear", "wdata", "full", "empty", "underrun", "overrun",
         "count", "rdata"]

def sh(cmd, **kw):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, **kw)

def build(config, mutant=None):
    bug = mutant[1:] if mutant else "0"
    r = sh(["make", "-s", "-C", ROOT, "build", "SIM=verilator", f"CONFIG={config}", f"BUG={bug}"])
    if r.returncode:
        print(r.stdout[-3000:])
        sys.exit(f"build failed: {config} {mutant or ''}")
    return os.path.join(ROOT, "build", f"verilator_{config}" + (f"_bug{bug}" if mutant else ""))

def run_one(bdir, test, seed):
    rdir = os.path.join(bdir, "runs", f"{test}_s{seed}")
    os.makedirs(rdir, exist_ok=True)
    cmd = [os.path.join(bdir, "obj", "Vtb"), f"+UVM_TESTNAME={test}", f"+verilator+seed+{seed}",
           "+UVM_VERBOSITY=UVM_LOW", "+verilator+coverage+file+coverage.dat"]
    try:
        r = sh(cmd, cwd=rdir, timeout=1800)
        log, rc = r.stdout, r.returncode
    except subprocess.TimeoutExpired:
        log, rc = "TIMEOUT", -1
    with open(os.path.join(rdir, "sim.log"), "w") as f:
        f.write(log)
    passed = "*** TEST PASSED ***" in log and rc == 0
    m = re.search(r"compares: (\d+)\s+mismatches: (\d+)", log)
    errs = re.findall(r"UVM_(?:ERROR|FATAL) \S+ @ \d+: \S+ \[(\w+)\] (.*)", log)
    if not errs and not passed:
        errs = [("CRASH", f"exit status {rc}: " + (log.strip().splitlines() or ["no output"])[-1])]
    return dict(test=test, seed=seed, passed=passed, compares=int(m.group(1)) if m else 0,
                ids=sorted({e[0] for e in errs}), first=(errs[0][1][:160] if errs else ""))

def run_matrix(bdir, seeds, jobs):
    jobs_list = [(t, s) for t in TESTS for s in range(1, seeds + 1)]
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        return list(ex.map(lambda ts: run_one(bdir, *ts), jobs_list))

def read_cov(path):
    pts = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"C '(.*)' (\d+)$", line.rstrip("\n"))
            if not m:
                continue
            kv = dict(p.split("\x02", 1) for p in m.group(1).split("\x01") if "\x02" in p)
            kv["count"] = int(m.group(2))
            pts.append(kv)
    return pts

def merge_cov(bdir):
    files = sorted(glob.glob(os.path.join(bdir, "runs", "*", "coverage.dat")))
    out = os.path.join(bdir, "merged.dat")
    r = sh(["verilator_coverage", "--write", out] + files)
    if r.returncode:
        sys.exit("verilator_coverage failed:\n" + r.stdout[-2000:])
    return read_cov(out)

def not_applicable(name, size, depth):
    if depth <= 2 and re.search(r"cg_ops\.(cp_occ\.MID$|occ_x_op\.MID_x_)", name):
        return True
    if depth == 1 and re.search(r"cg_clear\.(cp_occ\.MID$|clear_x_occ_x_op\.MID_x_)", name):
        return True
    if size == 1 and re.search(r"cg_data\.cp_wdata\.(H55|HAA)$", name):
        return True
    if size <= 2 and name.endswith("cg_data.cp_wdata.OTHER"):
        return True
    return False

def functional_report(pts, size, depth):
    lines, holes, total, hit = [], [], 0, 0
    groups = {}
    for p in pts:
        if p.get("t") != "covergroup":
            continue
        name = p["h"].replace("__vlAnonCG_", "")
        if not_applicable(name, size, depth):
            continue
        g = name.split(".")[0]
        groups.setdefault(g, [0, 0])
        groups[g][0] += 1
        total += 1
        if p["count"] > 0:
            groups[g][1] += 1
            hit += 1
        else:
            holes.append(name)
    wrap = [p for p in pts if p.get("t") == "user" and "fifo_sva" in p.get("f", "")]
    for g, (n, h) in sorted(groups.items()):
        lines.append(f"    {g:10s} {h:3d}/{n:<3d} bins hit")
    wrap_hits = sum(p["count"] for p in wrap)
    lines.append(f"    C_WRAP     {wrap_hits} hits (need >= 2)")
    ok = not holes and wrap_hits >= 2
    for name in holes:
        lines.append(f"    HOLE: {name}")
    lines.insert(0, f"  functional coverage: {hit}/{total} bins{'' if ok else '  <-- NOT CLOSED'}")
    return ok, lines

def unreachable(p, depth):
    # With one entry, not empty means full: these points cannot be hit at DEPTH = 1
    if depth != 1:
        return False
    if p.get("t") == "expr" and "empty==0" in p.get("o", "") and "full==0" in p.get("o", ""):
        return True
    src = open(RTL).read().split("\n")
    l = int(p.get("l") or 0)
    return p.get("t") in ("line", "branch") and p.get("o") == "else" and 0 < l <= len(src) and "else if (count == 0)" in src[l - 1]

def code_report(pts, depth):
    dut = [p for p in pts if p.get("f", "").endswith("socetlib_fifo.sv")]
    if not dut:
        return False, ["  DUT code coverage: NO DATA (build without --coverage-line/-toggle/-expr?)"]
    lines, ok = [], True
    for kind in ("line", "branch", "expr"):
        ps = [p for p in dut if p.get("t") == kind and not unreachable(p, depth)]
        miss = [p for p in ps if p["count"] == 0]
        lines.append(f"    {kind:7s} {len(ps) - len(miss):3d}/{len(ps):<3d}")
        for p in miss:
            lines.append(f"      miss: line {p.get('l')} {p.get('o', '')}")
        ok &= not miss
    tog = [p for p in dut if p.get("t") == "toggle" and p.get("o", "").split("[")[0].split(":")[0] in PORTS]
    tmiss = [p for p in tog if p["count"] == 0]
    lines.append(f"    toggle  {len(tog) - len(tmiss):3d}/{len(tog):<3d} (ports)")
    for p in tmiss:
        lines.append(f"      miss: {p.get('o')}")
    ok &= not tmiss
    lines.insert(0, f"  DUT code coverage (socetlib_fifo.sv){'' if ok else '  <-- holes'}")
    return ok, lines

def t19():
    out, ok = [], True
    for d in (6, 0):
        r = sh(["verilator", "--lint-only", "-Wno-ASCRANGE", "-Wno-WIDTH", "-Werror-USERERROR",
                f"-GDEPTH={d}", "--top-module", "socetlib_fifo", RTL])
        good = r.returncode != 0 and "DEPTH must be a power of 2" in r.stdout
        ok &= good
        out.append(f"  T19 DEPTH={d}: {'rejected at elaboration (pass)' if good else 'NOT rejected (fail)'}")
    return ok, out

def summarize(results):
    by_test = {}
    for r in results:
        by_test.setdefault(r["test"], []).append(r)
    lines = []
    for t in TESTS:
        rs = by_test.get(t, [])
        npass = sum(r["passed"] for r in rs)
        comp = sum(r["compares"] for r in rs)
        lines.append(f"    {t:24s} {npass}/{len(rs)} passed  {comp:8d} compares")
        for r in rs:
            if not r["passed"]:
                lines.append(f"      seed {r['seed']}: [{','.join(r['ids'])}] {r['first']}")
    return all(r["passed"] for r in results), lines

def regress(args):
    report, all_ok = [], True
    for c in args.configs:
        size, depth = CONFIGS[c]
        bdir = build(c)
        for d in glob.glob(os.path.join(bdir, "runs", "*")):
            sh(["rm", "-rf", d])
        res = run_matrix(bdir, args.seeds, args.jobs)
        ok_t, lt = summarize(res)
        pts = merge_cov(bdir)
        for f in glob.glob(os.path.join(bdir, "runs", "*", "coverage.dat")):
            os.remove(f)
        ok_f, lf = functional_report(pts, size, depth)
        ok_c, lc = code_report(pts, depth)
        report += [f"== {c}: SIZE={size} DEPTH={depth}, {args.seeds} seed(s) per test",
                   f"  tests{'' if ok_t else '  <-- FAILURES'}"] + lt + lf + lc + [""]
        all_ok &= ok_t and ok_f and ok_c
    ok19, l19 = t19()
    report += l19
    all_ok &= ok19
    report.append(f"\nREGRESSION {'PASSED' if all_ok else 'FAILED'}")
    return all_ok, report

def mutants(args):
    report, all_caught = [], True
    c = args.configs[0]
    base = build(c)
    res = run_matrix(base, args.seeds, args.jobs)
    ok, _ = summarize(res)
    report.append(f"baseline (unmodified RTL), {c}: {'all tests pass' if ok else 'FAILS -- fix this first'}")
    all_caught &= ok
    for sed in sorted(glob.glob(os.path.join(ROOT, "mutants", "M*.sed")), key=lambda p: int(re.sub(r"\D", "", os.path.basename(p)))):
        m = os.path.basename(sed)[:-4]
        desc = open(sed).readline().lstrip("# ").strip()
        bdir = build(c, m)
        res = run_matrix(bdir, args.seeds, args.jobs)
        failing = sorted({r["test"] for r in res if not r["passed"]})
        ids = sorted({i for r in res if not r["passed"] for i in r["ids"]})
        caught = bool(failing)
        all_caught &= caught
        report.append(f"\n{desc}\n  {'CAUGHT' if caught else 'MISSED'} by {len(failing)}/{len(TESTS)} tests: "
                      f"{', '.join(t.replace('fifo_', '').replace('_test', '') for t in failing) or '-'}"
                      f"\n  reported by: {', '.join(ids) or '-'}")
        first = next((r for r in res if not r["passed"]), None)
        if first:
            report.append(f"  first message: {first['first']}")
        sh(["rm", "-rf", os.path.join(bdir, "obj"), os.path.join(bdir, "runs")])
    report.append(f"\nMUTANTS {'ALL CAUGHT' if all_caught else 'NOT ALL CAUGHT'}")
    return all_caught, report

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--configs", nargs="+", default=["C1", "C2", "C3", "C4", "C5"])
    ap.add_argument("--seeds", type=int, default=5)
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--mutants", action="store_true")
    args = ap.parse_args()
    ok, report = (mutants if args.mutants else regress)(args)
    text = "\n".join(report)
    print(text)
    name = "mutants.txt" if args.mutants else "regress.txt"
    os.makedirs(os.path.join(ROOT, "results"), exist_ok=True)
    with open(os.path.join(ROOT, "results", name), "w") as f:
        f.write(text + "\n")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
