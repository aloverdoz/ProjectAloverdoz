"""Build collision and conveyor wall masks from survey_hulls.tscn output."""
import argparse
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[2]


def read_surfaces(path):
    data = path.read_bytes()
    offset = 0
    surfaces = []
    while offset < len(data):
        vertex_count, index_count = struct.unpack_from("<II", data, offset)
        offset += 8
        vertices = np.frombuffer(data, "<f4", vertex_count * 3, offset).reshape(-1, 3)
        offset += vertex_count * 12
        indices = np.frombuffer(data, "<u4", index_count, offset) if index_count else np.arange(vertex_count)
        offset += index_count * 4
        if len(indices):
            surfaces.append(vertices[indices].reshape(-1, 3, 3))
    return surfaces


def rasterize(surfaces, levels, lower, pixel, width, height):
    mask = Image.new("1", (width, height))
    draw = ImageDraw.Draw(mask)
    for triangles in surfaces:
        ymin = triangles[:, :, 1].min(1)
        ymax = triangles[:, :, 1].max(1)
        for level in levels:
            group = triangles[(ymin < level) & (ymax >= level)]
            if not len(group):
                continue
            following = np.roll(group, -1, axis=1)
            crosses = (group[:, :, 1] < level) != (following[:, :, 1] < level)
            start, end = group[crosses], following[crosses]
            fraction = (level - start[:, 1]) / (end[:, 1] - start[:, 1])
            points = (start + fraction[:, None] * (end - start))[:, [0, 2]]
            segments = ((points - lower[[0, 2]]) / pixel + .5).reshape(-1, 2, 2)
            for row in range(height):
                y = row + .5
                edges = segments[(segments[:, 0, 1] < y) != (segments[:, 1, 1] < y)]
                if len(edges):
                    fraction = (y - edges[:, 0, 1]) / (edges[:, 1, 1] - edges[:, 0, 1])
                    hits = np.sort(edges[:, 0, 0] + fraction * (edges[:, 1, 0] - edges[:, 0, 0]))
                    for left, right in zip(hits[::2], hits[1::2]):
                        draw.line((round(left), row, round(right), row), fill=1)
            for segment in segments:
                draw.line(tuple(map(tuple, segment)), fill=1)
    return ["".join("1" if value else "0" for value in row) for row in np.asarray(mask)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("survey_directory", type=Path)
    args = parser.parse_args()
    buildings = json.loads((PROJECT / "core/buildings.json").read_text())
    models = json.loads((PROJECT / "core/models.json").read_text())
    result = {}
    for key, building in buildings.items():
        surfaces = read_surfaces(args.survey_directory / (key + ".bin"))
        if not surfaces:
            continue
        vertices = np.concatenate(surfaces).reshape(-1, 3)
        lower, upper = vertices.min(0), vertices.max(0)
        pixel = max(.045, float(max((upper - lower)[[0, 2]])) / 72)
        width, height = np.ceil((upper - lower)[[0, 2]] / pixel).astype(int) + 2
        masks = []
        for levels, limit in [([.38, .76, 1.2, 1.56], .75), ([.18, .35, .55, .73], .65)]:
            heights = [min(level, lower[1] + (upper[1] - lower[1]) * limit) for level in levels]
            masks.append(rasterize(surfaces, heights, lower, pixel, width, height))
        scale = models[building["model"]].get("scale", 1)
        result[key] = [float(lower[0] - .5 * pixel), float(lower[2] - .5 * pixel), pixel, scale, *masks]
    (PROJECT / "catalog/footprints.json").write_text(json.dumps(result, separators=(",", ":")))


if __name__ == "__main__":
    main()
