"""Weights + arms-down pose for a T-pose character mesh (game coords, see anime_prep.py) -> raw buffers for Godot."""
import numpy as np, json, sys, math
src, out = sys.argv[1], sys.argv[2]
L = json.load(open(sys.argv[3]))          # landmarks
d = np.load(src); V = d["v"].copy(); N = d["n"].copy(); UV = d["uv"]; I = d["i"]
x, y, z = V.T
NAMES = ["hips", "leg_l", "leg_r", "shin_l", "shin_r", "torso", "head", "arm_l", "arm_r", "fore_l", "fore_r", "hand_r"]
bi = {n: i for i, n in enumerate(NAMES)}
W = np.zeros((len(V), len(NAMES)), np.float32)
ss = lambda a, b, t: np.clip((t - a) / (b - a), 0, 1) ** 2 * (3 - 2 * np.clip((t - a) / (b - a), 0, 1))
S = L["shoulder"]; E = L["elbow_z"]; Wr = L["wrist_z"]
az = np.abs(z)
# ---- arms (T-pose along ±z at height S.y)
rad = np.hypot(y - S["y"], x - S["x"])
far = (az > S["z"] + 0.05) & (np.abs(y - S["y"]) < 0.22)   # T-pose: anything far out at shoulder height is arm (sleeves, gloves)
if L.get("wings"):
    far &= x > L.get("cx", 0.0) - 0.08
in_arm = ((rad < L["arm_r"]) | far) & (az > S["z"] - 0.04)
a_w = ss(S["z"] - 0.035, S["z"] + 0.03, az) * in_arm
for side, sg in (("l", 1), ("r", -1)):
    m = (np.sign(z) == sg) & (a_w > 0)
    t_e = ss(E - 0.03, E + 0.03, az); t_w = ss(Wr - 0.02, Wr + 0.02, az)
    hand = t_w if side == "r" else 0 * t_w
    fore = t_e - hand
    arm = 1 - t_e
    for nm, wv in (("arm_" + side, arm), ("fore_" + side, fore), ("hand_r", hand)):
        if nm == "hand_r" and side == "l":
            continue
        W[m, bi[nm]] += (a_w * wv)[m]
body = 1 - a_w
# ---- body: head / torso / hips / legs by height
Hp, Hj, Kn, Nk, To = L["hips_y"], L["hip_joint"], L["knee"], L["neck_y"], L["torso_y"]
head = ss(Nk - 0.02, Nk + 0.03, y) * (1 - ss(0.15, 0.19, az))   # wings and wide things above the neck stay on the torso
torso = ss(To - 0.04, To + 0.08, y) * (1 - head)
low = 1 - head - torso                       # hips + legs
hair_back = (x < L["hair_x"]) & (y > Kn)     # long hair behind: stays with hips/torso
legness = ss(Hj["y"] + 0.07, Hj["y"] - 0.12, y) * ss(0.005, 0.035, az) * (~hair_back)
hips = low * (1 - legness)
legs = low * legness
shin = ss(Kn + 0.03, Kn - 0.03, y)
for side, sg in (("l", 1), ("r", -1)):
    m = np.sign(z) == sg
    W[m, bi["leg_" + side]] += (body * legs * (1 - shin))[m]
    W[m, bi["shin_" + side]] += (body * legs * shin)[m]
W[:, bi["hips"]] += body * hips
W[:, bi["torso"]] += body * torso
W[:, bi["head"]] += body * head
W /= W.sum(1, keepdims=True)
# ---- pose: arms down (rotate about the forward axis at the shoulder), blended by arm weight
ang = math.radians(90 - L["arm_out_deg"])
piv = {}
for side, sg in (("l", 1), ("r", -1)):
    th = sg * ang
    w = W[:, bi["arm_" + side]] + W[:, bi["fore_" + side]] + (W[:, bi["hand_r"]] if side == "r" else 0)
    m = w > 0
    t = th * w[m]
    c, s_ = np.cos(t), np.sin(t)
    py, pz = V[m, 1] - S["y"], V[m, 2] - sg * S["z"]
    V[m, 1] = S["y"] + py * c - pz * s_; V[m, 2] = sg * S["z"] + py * s_ + pz * c
    ny, nz = N[m, 1].copy(), N[m, 2].copy()
    N[m, 1] = ny * c - nz * s_; N[m, 2] = ny * s_ + nz * c
    rot = lambda dz: [0.0, -dz * math.cos(math.radians(L["arm_out_deg"])), sg * dz * math.sin(math.radians(L["arm_out_deg"]))]
    piv["fore_" + side] = rot(E - S["z"])
    if side == "r":
        piv["hand_r"] = rot(Wr - E)
# ---- bones (parent-relative, as the game wants)
HJ = Hj
bones = {"hips": [0, Hp, 0], "torso": [0, To - Hp, 0], "head": [0, Nk - To, 0],
         "arm_l": [S["x"], S["y"] - To, S["z"]], "arm_r": [S["x"], S["y"] - To, -S["z"]],
         "leg_l": [HJ["x"], HJ["y"] - Hp, HJ["z"]], "leg_r": [HJ["x"], HJ["y"] - Hp, -HJ["z"]],
         "shin_l": [L["knee_x"] - HJ["x"], Kn - HJ["y"], L["knee_z"] - HJ["z"]],
         "shin_r": [L["knee_x"] - HJ["x"], Kn - HJ["y"], -(L["knee_z"] - HJ["z"])],
         "gun": [0, -0.07, 0], "muzzle": [0.058, -0.125, 0]}
bones.update(piv)
bones = {k: [round(float(c), 4) for c in v] for k, v in bones.items()}
# ---- top 4 influences
idx = np.argsort(-W, 1)[:, :4].astype(np.int32)
wt = np.take_along_axis(W, idx, 1); wt /= wt.sum(1, keepdims=True)
for nm, arr in (("v", V), ("n", N), ("uv", UV)):
    arr.astype("<f4").tofile(f"{out}/{nm}.bin")
I.astype("<i4").tofile(f"{out}/i.bin"); idx.astype("<i4").tofile(f"{out}/b.bin"); wt.astype("<f4").tofile(f"{out}/w.bin")
json.dump({"bones": bones, "names": NAMES, "verts": len(V), "tris": len(I) // 3}, open(f"{out}/rig.json", "w"), indent=1)
print("RIG", len(V), "verts", json.dumps(bones))
