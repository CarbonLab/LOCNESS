"""
LOCNESS Cruise Animation
Animates all platforms (RV Connecticut, Gliders, Drifters, LRAUV) on a
satellite basemap over a unified timeline.
Trails are colored by rhodamine concentration.
Produces two GIFs: a wide overview and a zoomed-in view.
"""

import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")  # non-interactive backend, must be set before pyplot import
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import matplotlib.colors as mcolors
from matplotlib.lines import Line2D
import cartopy.crs as ccrs
import cartopy.io.img_tiles as cimgt


class EsriOcean(cimgt.GoogleTiles):
    """ESRI World Ocean Base tile source."""
    def _image_url(self, tile):
        x, y, z = tile
        return (
            f"https://services.arcgisonline.com/arcgis/rest/services/"
            f"Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}"
        )


# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(SCRIPT_DIR, "data", "locness_animation.txt")
OUTPUT_WIDE = os.path.join(SCRIPT_DIR, "locness_animation_5FPS_72hourtrail.gif")
OUTPUT_ZOOM = os.path.join(SCRIPT_DIR, "locness_animation_zoom_5FPS_72hourtrail.gif")

# ── Config ─────────────────────────────────────────────────────────────────────
PAD_DEG = 0.35
FPS = 5
INTERVAL_MS = 1000 // FPS
TARGET_FRAMES = 200
TILE_ZOOM_WIDE = 8
TILE_ZOOM_ZOOM = 10
TRAIL_WINDOW_S = 3 * 24 * 3600  # trails disappear after 72 hours

# Zoomed extent (lat/lon bounds for the action area)
ZOOM_EXTENT = [-69.7666, -69.1362, 42.3707, 42.7212]

# Drifter data starts at this date (unix timestamp for 2025-08-13 00:00 UTC)
DRIFTER_START_TS = 1754956800.0

# Rhodamine colormap settings
RHODAMINE_CMAP = "YlOrRd"
RHODAMINE_VMIN = 0.0
RHODAMINE_VMAX = 5.0        # values above this clip to max color
RHODAMINE_GAMMA = 0.35      # <1 compresses low values, highlights highs
TRAIL_DOT_SIZE_WIDE = 12     # scatter dot size for wide view
TRAIL_DOT_SIZE_ZOOM = 24     # scatter dot size for zoomed view

# ── Theme colors ───────────────────────────────────────────────────────────────
GRID_COLOR = "#FFFFFF"
TEXT_COLOR = "#FFFFFF"
TITLE_COLOR = "#FFFFFF"

# ── Platform styles (current-position markers only) ────────────────────────────
SHIP_COLOR = "#00BFFF"
SHIP_MARKER = "s"
SHIP_SIZE = 12

GLIDER_COLORS = {
    "25720901": "#FFD700",
    "25706901": "#FF8C00",
    "25821001": "#FFEC8B",
}
GLIDER_MARKER = "^"
GLIDER_SIZE = 12

LRAUV_COLOR = "#FF4500"
LRAUV_MARKER = "s"
LRAUV_SIZE = 12

DRIFTER_PALETTE = [
    "#87CEEB", "#B0E0E6", "#ADD8E6", "#7EC8E3",
    "#5DADE2", "#48C9B0", "#76D7C4", "#A3E4D7",
]
DRIFTER_MARKER = "o"
DRIFTER_SIZE = 12


# ── Data helpers ───────────────────────────────────────────────────────────────

def load_all_data(path):
    df = pd.read_csv(path)
    df = df.dropna(subset=["unixTimestamp", "lat", "lon"])
    df["rhodamine"] = pd.to_numeric(df["rhodamine"], errors="coerce")
    df = df[(df["lat"] > 39) & (df["lat"] < 46) &
            (df["lon"] > -72) & (df["lon"] < -56)].copy()
    # Clamp negatives to 0, cap at VMAX (prevents sensor errors like 880K
    # from bleeding into neighboring frames during interpolation), fill NaN with 0
    df["rhodamine"] = df["rhodamine"].fillna(0.0).clip(lower=0.0, upper=RHODAMINE_VMAX)
    return df


def extract_tracks(df):
    tracks = {}
    for (platform, cruise), grp in df.groupby(["Platform", "Cruise"]):
        track = (
            grp.drop_duplicates(subset=["unixTimestamp"])
            .sort_values("unixTimestamp")
            .reset_index(drop=True)
        )
        if len(track) < 2:
            continue
        tracks[(platform, cruise)] = track
    return tracks


def interpolate_track(track_df, frame_times):
    """Interpolate lat, lon, and rhodamine onto frame_times."""
    ts = track_df["unixTimestamp"].values
    lat = np.interp(frame_times, ts, track_df["lat"].values,
                     left=np.nan, right=np.nan)
    lon = np.interp(frame_times, ts, track_df["lon"].values,
                     left=np.nan, right=np.nan)
    rho_raw = track_df["rhodamine"].values
    # Fill NaN rhodamine with 0 for interpolation, then mask later
    rho_filled = np.where(np.isnan(rho_raw), 0.0, rho_raw)
    rho = np.interp(frame_times, ts, rho_filled,
                     left=np.nan, right=np.nan)
    return lat, lon, rho


def compute_wide_extent(df):
    core = df[df["Platform"].isin(["Ship", "Glider", "LRAUV"])]
    lon_center = (core["lon"].min() + core["lon"].max()) / 2
    lat_center = (core["lat"].min() + core["lat"].max()) / 2
    lon_range = max(core["lon"].max() - core["lon"].min() + 2 * PAD_DEG, 2.0)
    lat_range = max(core["lat"].max() - core["lat"].min() + 2 * PAD_DEG, 1.5)
    return [
        lon_center - lon_range / 2, lon_center + lon_range / 2,
        lat_center - lat_range / 2, lat_center + lat_range / 2,
    ]


# ── Render one animation ──────────────────────────────────────────────────────

def render_animation(tracks, interp, frame_times, extent, tile_zoom,
                     output_path, title, dot_size=TRAIL_DOT_SIZE_WIDE):
    n_frames = len(frame_times)
    proj = ccrs.PlateCarree()
    satellite = EsriOcean()
    cmap = plt.get_cmap(RHODAMINE_CMAP)
    norm = mcolors.PowerNorm(gamma=RHODAMINE_GAMMA,
                             vmin=RHODAMINE_VMIN, vmax=RHODAMINE_VMAX)

    fig = plt.figure(figsize=(14, 8), facecolor="none")
    ax = fig.add_subplot(1, 1, 1, projection=satellite.crs)
    ax.set_extent(extent, crs=proj)
    ax.add_image(satellite, tile_zoom)

    gl = ax.gridlines(draw_labels=True, linewidth=0.3,
                      color=GRID_COLOR, alpha=0.3, linestyle="--")
    gl.top_labels = False
    gl.right_labels = False
    gl.xlabel_style = {"color": TEXT_COLOR, "fontsize": 8}
    gl.ylabel_style = {"color": TEXT_COLOR, "fontsize": 8}

    ax.set_title(title, color=TITLE_COLOR, fontsize=16,
                 fontweight="bold", pad=12)

    time_text = ax.text(
        0.02, 0.02, "", transform=ax.transAxes, color=TEXT_COLOR,
        fontsize=11, fontfamily="monospace", zorder=10,
        bbox=dict(boxstyle="round,pad=0.4", facecolor="black",
                  edgecolor="#444444", alpha=0.75),
    )

    # Colorbar for rhodamine
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
    sm.set_array([])
    cbar = fig.colorbar(sm, ax=ax, orientation="vertical", fraction=0.025,
                        pad=0.02, shrink=0.7)
    cbar.set_label("Rhodamine", color="black", fontsize=14, fontweight="bold")
    cbar.ax.yaxis.set_tick_params(color="black")
    plt.setp(cbar.ax.yaxis.get_ticklabels(), color="black", fontsize=12)

    # Classify tracks
    ship_keys = {k for k in tracks if k[0] == "Ship"}
    glider_keys = {k for k in tracks if k[0] == "Glider"}
    lrauv_keys = {k for k in tracks if k[0] == "LRAUV"}
    drifter_keys = sorted([k for k in tracks if k[0] == "Drifter"],
                          key=lambda k: k[1])

    artists = {}

    # For each track: a scatter for the colored trail + a plot for the marker
    for key in ship_keys:
        trail = ax.scatter([], [], s=dot_size, c=[], cmap=cmap, norm=norm,
                           edgecolors="none", transform=proj, zorder=7)
        marker, = ax.plot([], [], SHIP_MARKER, color=SHIP_COLOR,
                          markersize=SHIP_SIZE, markeredgecolor="white",
                          markeredgewidth=0.5, transform=proj, zorder=10)
        artists[key] = {"trail_scatter": trail, "marker": marker}

    for key in glider_keys:
        color = GLIDER_COLORS.get(key[1], "#FFD700")
        trail = ax.scatter([], [], s=dot_size, c=[], cmap=cmap, norm=norm,
                           edgecolors="none", transform=proj, zorder=4)
        marker, = ax.plot([], [], GLIDER_MARKER, color=color,
                          markersize=GLIDER_SIZE, markeredgecolor="white",
                          markeredgewidth=0.3, transform=proj, zorder=7)
        artists[key] = {"trail_scatter": trail, "marker": marker}

    for key in lrauv_keys:
        trail = ax.scatter([], [], s=dot_size, c=[], cmap=cmap, norm=norm,
                           edgecolors="none", transform=proj, zorder=4)
        marker, = ax.plot([], [], LRAUV_MARKER, color=LRAUV_COLOR,
                          markersize=LRAUV_SIZE, markeredgecolor="white",
                          markeredgewidth=0.3, transform=proj, zorder=7)
        artists[key] = {"trail_scatter": trail, "marker": marker}

    for i, key in enumerate(drifter_keys):
        color = DRIFTER_PALETTE[i % len(DRIFTER_PALETTE)]
        trail = ax.scatter([], [], s=dot_size * 0.5, c=[], cmap=cmap,
                           norm=norm, edgecolors="none", transform=proj, zorder=3)
        marker, = ax.plot([], [], DRIFTER_MARKER, color=color,
                          markersize=DRIFTER_SIZE, markeredgecolor="white",
                          markeredgewidth=0.2, transform=proj, zorder=6)
        artists[key] = {"trail_scatter": trail, "marker": marker}

    # Legend
    legend_handles = [
        Line2D([0], [0], marker=SHIP_MARKER, color="w",
               markerfacecolor=SHIP_COLOR, markersize=12, linestyle="None",
               label="RV Connecticut"),
        Line2D([0], [0], marker=GLIDER_MARKER, color="w",
               markerfacecolor="#FFD700", markersize=12, linestyle="None",
               label="Glider"),
        Line2D([0], [0], marker=LRAUV_MARKER, color="w",
               markerfacecolor=LRAUV_COLOR, markersize=12, linestyle="None",
               label="LRAUV"),
        Line2D([0], [0], marker=DRIFTER_MARKER, color="w",
               markerfacecolor="#87CEEB", markersize=10, linestyle="None",
               label="Drifter"),
    ]
    ax.legend(handles=legend_handles, loc="upper left",
              fontsize=13, facecolor="black", edgecolor="#444444",
              labelcolor=TEXT_COLOR, framealpha=0.75)

    def init():
        for art in artists.values():
            if "trail_scatter" in art:
                art["trail_scatter"].set_offsets(np.empty((0, 2)))
                art["trail_scatter"].set_array(np.array([]))
            if "marker" in art:
                art["marker"].set_data([], [])
        time_text.set_text("")
        return []

    def update(frame):
        ft = frame_times[frame]
        ts = pd.Timestamp(ft, unit="s", tz="UTC")
        time_text.set_text(f"  {ts:%Y-%m-%d  %H:%M} UTC  ")

        t_window_start = ft - TRAIL_WINDOW_S

        for key, art in artists.items():
            lats_i, lons_i, rho_i = interp[key]

            times_up_to = frame_times[:frame + 1]
            in_window = ((times_up_to >= t_window_start) &
                         ~np.isnan(lats_i[:frame + 1]))
            trail_lats = lats_i[:frame + 1][in_window]
            trail_lons = lons_i[:frame + 1][in_window]
            trail_rho = rho_i[:frame + 1][in_window]

            cur_lat = lats_i[frame]
            cur_lon = lons_i[frame]
            visible = not np.isnan(cur_lat)

            if "trail_scatter" in art:
                if len(trail_lons) > 0:
                    offsets = np.column_stack([trail_lons, trail_lats])
                    art["trail_scatter"].set_offsets(offsets)
                    art["trail_scatter"].set_array(trail_rho)
                else:
                    art["trail_scatter"].set_offsets(np.empty((0, 2)))
                    art["trail_scatter"].set_array(np.array([]))

            if "marker" in art:
                if visible:
                    art["marker"].set_data([cur_lon], [cur_lat])
                else:
                    art["marker"].set_data([], [])

        return []

    print(f"  Rendering {n_frames} frames...")
    anim = animation.FuncAnimation(
        fig, update, init_func=init,
        frames=n_frames, interval=INTERVAL_MS, blit=False,
    )

    print(f"  Saving to {output_path} ...")
    writer = animation.PillowWriter(fps=FPS)
    anim.save(output_path, writer=writer, dpi=120,
              savefig_kwargs={"facecolor": "none", "transparent": True})
    plt.close(fig)


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    print("Loading data...")
    df = load_all_data(DATA_PATH)
    df = df[~((df["Platform"] == "Drifter") &
              (df["unixTimestamp"] < DRIFTER_START_TS))]

    tracks = extract_tracks(df)

    ship_n = sum(1 for k in tracks if k[0] == "Ship")
    glider_n = sum(1 for k in tracks if k[0] == "Glider")
    lrauv_n = sum(1 for k in tracks if k[0] == "LRAUV")
    drifter_n = sum(1 for k in tracks if k[0] == "Drifter")
    print(f"  Ship: {ship_n}  Glider: {glider_n}  "
          f"LRAUV: {lrauv_n}  Drifter: {drifter_n}")

    all_ts = df["unixTimestamp"]
    t_min, t_max = all_ts.min(), all_ts.max()
    frame_times = np.linspace(t_min, t_max, TARGET_FRAMES)
    print(f"  Timeline: {pd.Timestamp(t_min, unit='s', tz='UTC'):%Y-%m-%d %H:%M} "
          f"-> {pd.Timestamp(t_max, unit='s', tz='UTC'):%Y-%m-%d %H:%M} UTC")
    print(f"  {TARGET_FRAMES} frames @ {FPS} fps = {TARGET_FRAMES / FPS:.1f}s")

    interp = {}
    for key, track in tracks.items():
        interp[key] = interpolate_track(track, frame_times)

    # ── Wide view ──────────────────────────────────────────────────────────────
    wide_extent = compute_wide_extent(df)
    print(f"\n[1/2] Wide view -> {OUTPUT_WIDE}")
    render_animation(tracks, interp, frame_times, wide_extent,
                     TILE_ZOOM_WIDE, OUTPUT_WIDE,
                     "LOCNESS Cruise - All Platforms")

    # ── Zoomed view ────────────────────────────────────────────────────────────
    print(f"\n[2/2] Zoomed view -> {OUTPUT_ZOOM}")
    render_animation(tracks, interp, frame_times, ZOOM_EXTENT,
                     TILE_ZOOM_ZOOM, OUTPUT_ZOOM,
                     "LOCNESS Cruise - Study Area",
                     dot_size=TRAIL_DOT_SIZE_ZOOM)

    print("\nAll done!")


if __name__ == "__main__":
    main()
