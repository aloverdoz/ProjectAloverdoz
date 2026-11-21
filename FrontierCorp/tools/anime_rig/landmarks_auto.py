"""Guess rig landmarks for a T-pose character (game coords from anime_prep.py: x fwd, y up, z lateral, feet at y=0)."""
import numpy as np, json, sys, math
V = np.load(sys.argv[1])["v"].astype(np.float64); x, y, z = V.T
H = y.max(); az = np.abs(z)
# body centre (front/back) from the legs
leg = (y > 0.25 * H) & (y < 0.4 * H)
cx = float(np.median(x[leg]))
front = x > cx - 0.07                        # wings, capes and long hair hang behind
# arms: lateral slices well away from the body
span = float(np.percentile(az[front & (y > 0.5 * H)], 99.8))
mid = (x > cx - 0.04) & (az > 0.45 * span) & (az < 0.7 * span) & (y > 0.5 * H)
if mid.sum() < 200:      # arms behind the leg line (big belly pushes the legs forward)
    mid = (az > 0.45 * span) & (az < 0.7 * span) & (y > 0.5 * H)
    front = np.ones_like(front)
arm_y = float(np.median(y[mid])); arm_x = float(np.median(x[mid]))
rad = np.hypot(y - arm_y, x - arm_x)
near = (rad < 0.12) & (az > 0.45 * span) & (az < 0.7 * span)
arm_r = float(np.percentile(rad[near], 92)) + 0.025
on_arm = rad < arm_r + 0.03
tip = float(np.percentile(az[on_arm & front & (az > 0.5 * span)], 99.5))
# torso half-width under the armpits (arms are horizontal, so this band is torso only)
band = (x > cx - 0.02) & (y > arm_y - 0.17 * H / 1.72) & (y < arm_y - 0.08 * H / 1.72) & (az < 0.6 * span)
w = float(np.percentile(az[band], 97))
sh = max(0.12, min(0.25, w + 0.01))
wrist = tip - 0.12 * H
elbow = sh + 0.53 * (wrist - sh)
# hips / legs
hj = 0.523 * H; kn = 0.30 * H
lz = float(np.median(az[(y > 0.33 * H) & (y < 0.38 * H)]))
hz = float(np.median(az[(y > 0.43 * H) & (y < 0.48 * H)]))
belly = float(np.percentile(az[front & (y > 0.55 * H) & (y < arm_y - 0.15)], 97))
# hang the arms just clear of the belly/hips
need = (belly + arm_r * 0.7 - sh) / max(0.15, wrist - sh)
out = math.degrees(math.asin(max(0.0, min(0.7, need))))
out = max(12.0, min(40.0, out))
L = {"shoulder": {"x": round(arm_x, 4), "y": round(arm_y, 4), "z": round(sh, 4)}, "elbow_z": round(elbow, 4), "wrist_z": round(wrist, 4),
     "arm_r": round(arm_r, 4), "arm_out_deg": round(out, 1),
     "hips_y": round(hj + 0.05, 4), "torso_y": round(hj + 0.12, 4), "neck_y": round(arm_y + 0.025 * H, 4),
     "hip_joint": {"x": round(cx, 4), "y": round(hj, 4), "z": round(max(0.06, min(0.14, max(lz, hz))), 4)},
     "knee": round(kn, 4), "knee_x": round(float(np.median(x[(y > kn - 0.03) & (y < kn + 0.03)])), 4), "knee_z": round(max(0.04, lz), 4),
     "hair_x": round(cx - 0.09, 4), "cx": round(cx, 4), "wings": bool(((az > 0.3) & (rad > arm_r + 0.12) & (x < arm_x)).sum() > 0.03 * len(x)), "H": round(float(H), 3), "span": round(span, 3), "belly": round(belly, 3)}
json.dump(L, open(sys.argv[2], "w"), indent=1)
print("LM", json.dumps(L))
