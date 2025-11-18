import pandas as pd
from pathlib import Path
from functools import reduce

DATA_DIR = Path(".")  # change if your CSVs live elsewhere

# ---------- Helpers ----------

def parse_apple_date(s: str):
    """
    Apple Export.csv 'Date' looks like either:
      '2025-11-16 00:00:46 - 2025-11-16 00:01:46'
      '2025-11-16 00:07:48'
    This pulls the first timestamp and parses it.
    """
    if pd.isna(s):
        return pd.NaT
    s = str(s).strip()
    if " - " in s:
        s = s.split(" - ")[0].strip()
    return pd.to_datetime(s, errors="coerce")

# ---------- Concept2 (logbook export) ----------

def load_concept2_daily(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)

    # Parse datetime and date
    df["DateTime"] = pd.to_datetime(df["Date"])
    df["date"] = df["DateTime"].dt.date

    # Aggregate per day
    daily = (
        df.groupby("date")
        .agg(
            c2_workouts=("Log ID", "count"),
            c2_distance_m=("Work Distance", "sum"),
            c2_work_time_s=("Work Time (Seconds)", "sum"),
            c2_avg_watts=("Avg Watts", "mean"),
            c2_avg_hr=("Avg Heart Rate", "mean"),
            c2_total_cal=("Total Cal", "sum"),
        )
        .reset_index()
    )

    return daily

# ---------- WHOOP: Workouts ----------

def load_whoop_workouts_daily(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)

    df["Workout start time"] = pd.to_datetime(df["Workout start time"])
    df["date"] = df["Workout start time"].dt.date

    daily = (
        df.groupby("date")
        .agg(
            whoop_workouts=("Workout start time", "count"),
            whoop_duration_min=("Duration (min)", "sum"),
            whoop_activity_strain=("Activity Strain", "sum"),
            whoop_energy_cal=("Energy burned (cal)", "sum"),
            whoop_avg_hr=("Average HR (bpm)", "mean"),
            whoop_max_hr=("Max HR (bpm)", "max"),
        )
        .reset_index()
    )

    return daily

# ---------- WHOOP: Physiological Cycles (recovery / day strain) ----------

def load_whoop_cycles_daily(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)

    df["Cycle start time"] = pd.to_datetime(df["Cycle start time"])
    df["date"] = df["Cycle start time"].dt.date

    daily = (
        df.groupby("date")
        .agg(
            whoop_recovery_pct=("Recovery score %", "mean"),
            whoop_rhr_bpm=("Resting heart rate (bpm)", "mean"),
            whoop_hrv_ms=("Heart rate variability (ms)", "mean"),
            whoop_skin_temp_c=("Skin temp (celsius)", "mean"),
            whoop_blood_oxygen_pct=("Blood oxygen %", "mean"),
            whoop_day_strain=("Day Strain", "mean"),
            whoop_day_energy_cal=("Energy burned (cal)", "mean"),
            whoop_sleep_performance_pct=("Sleep performance %", "mean"),
            whoop_sleep_efficiency_pct=("Sleep efficiency %", "mean"),
        )
        .reset_index()
    )

    return daily

# ---------- WHOOP: Sleeps ----------

def load_whoop_sleeps_daily(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)

    # Use wake date as the "day" the sleep belongs to
    df["Wake onset"] = pd.to_datetime(df["Wake onset"])
    df["date"] = df["Wake onset"].dt.date

    daily = (
        df.groupby("date")
        .agg(
            whoop_asleep_min=("Asleep duration (min)", "sum"),
            whoop_in_bed_min=("In bed duration (min)", "sum"),
            whoop_light_sleep_min=("Light sleep duration (min)", "sum"),
            whoop_deep_sleep_min=("Deep (SWS) duration (min)", "sum"),
            whoop_rem_sleep_min=("REM duration (min)", "sum"),
            whoop_awake_min=("Awake duration (min)", "sum"),
            whoop_sleep_need_min=("Sleep need (min)", "mean"),
            whoop_sleep_debt_min=("Sleep debt (min)", "mean"),
        )
        .reset_index()
    )

    return daily

# ---------- Apple Health: Export.csv (Health Auto Export) ----------

def load_apple_health_daily(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)

    # Parse Date column (ranges or single timestamps)
    df["DateTime"] = df["Date"].apply(parse_apple_date)
    df = df.dropna(subset=["DateTime"]).copy()
    df["date"] = df["DateTime"].dt.date

    # Decide aggregation strategy per column
    value_cols = [c for c in df.columns if c not in ["Date", "DateTime", "date"]]

    agg_funcs = {}
    for col in value_cols:
        col_lower = col.lower()
        # Heuristic: durations / time-like fields -> sum, others -> mean
        if (
            "time " in col_lower
            or " duration" in col_lower
            or "(hr)" in col_lower
            or "(min)" in col_lower
        ):
            agg_funcs[col] = "sum"
        else:
            agg_funcs[col] = "mean"

    daily = df.groupby("date").agg(agg_funcs).reset_index()

    # Prefix columns so it's obvious what came from Apple Health
    rename_map = {col: f"apple_{col}" for col in value_cols}
    daily = daily.rename(columns=rename_map)

    return daily

# ---------- Main merge ----------

def main():
    c2_daily = load_concept2_daily(DATA_DIR / "concept2-season-2026-2.csv")
    workouts_daily = load_whoop_workouts_daily(DATA_DIR / "workouts.csv")
    cycles_daily = load_whoop_cycles_daily(DATA_DIR / "physiological_cycles.csv")
    sleeps_daily = load_whoop_sleeps_daily(DATA_DIR / "sleeps.csv")
    apple_daily = load_apple_health_daily(DATA_DIR / "Export.csv")

    dfs = [c2_daily, workouts_daily, cycles_daily, sleeps_daily, apple_daily]

    # Outer-join everything on date
    master = reduce(
        lambda left, right: pd.merge(left, right, on="date", how="outer"), dfs
    )

    master = master.sort_values("date").reset_index(drop=True)

    out_path = DATA_DIR / "master_daily.csv"
    master.to_csv(out_path, index=False)

    print(f"Saved {len(master)} rows to {out_path}")

if __name__ == "__main__":
    main()