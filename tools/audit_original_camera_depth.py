#!/usr/bin/env python3
"""Validate viewing direction against the user's privately extracted UCMs.

Usage: python tools/audit_original_camera_depth.py PRIVATE/data/models
Reads user-owned game assets. No proprietary mesh data is included in repo.
"""
import argparse
import struct
from pathlib import Path


def z_bounds_and_normal(path):
    payload = path.read_bytes()
    if payload[:4] != b"UCM1" or len(payload) < 92:
        raise ValueError(f"Invalid original UCM: {path}")
    groups, faces, per_group, _records = struct.unpack_from("<4I", payload, 72)
    count = groups * per_group
    offset = 92 + faces * 12
    if count < 1 or count > 100_000 or offset + count * 32 > len(payload):
        raise ValueError(f"Invalid original vertex table: {path}")
    zs, normals = [], []
    for index in range(count):
        base = offset + index * 32
        zs.append(struct.unpack_from("<f", payload, base + 8)[0])
        normals.append(struct.unpack_from("<f", payload, base + 20)[0])
    return min(zs), max(zs), sum(normals) / count


def check(models):
    wall = z_bounds_and_normal(models / "wall.ucm")
    ball = z_bounds_and_normal(models / "ball.ucm")
    board = z_bounds_and_normal(models / "startscreen_chalkboard_board.ucm")
    note = z_bounds_and_normal(models / "startscreen_note.ucm")
    # The first original level puts its tennis ball at z=0.03751. The
    # background has no z offset: wall is BEHIND objects when viewed -Z.
    original_ball_center = 0.03751 + (ball[0] + ball[1]) / 2
    if not (wall[0] > original_ball_center and wall[2] < -0.8):
        raise AssertionError("Level 1 camera must view UCM geometry from -Z")
    # The paper note lies in front of the chalkboard (negative z).
    if not (board[0] > note[1] and board[2] < -0.8 and note[2] < -0.8):
        raise AssertionError("Original startscreen camera must view from -Z")
    print("PASS: Original level 1 wall lies behind its objects from -Z")
    print("PASS: Original startscreen note lies in front of board from -Z")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("models", type=Path)
    check(parser.parse_args().models)
