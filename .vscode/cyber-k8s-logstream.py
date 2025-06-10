#!/usr/bin/env python3

import sys
import time
import re
import shutil
import argparse
import os
import json
import yaml
from art import text2art, art, FONT_NAMES
import random
import difflib
import subprocess

# ANSI color codes
COLORS = [
    "\033[95m",  # Magenta
    "\033[94m",  # Blue
    "\033[96m",  # Cyan
    "\033[92m",  # Green
    "\033[93m",  # Yellow
    "\033[91m",  # Red
    "\033[0m",   # Reset
    "\033[1m",   # Bold
    "\033[4m",   # Underline
    "\033[37m",  # Light Gray (for highlight)
    "\033[36m",  # Light Cyan (for highlight)
    "\033[32m",  # Light Green (for highlight)
    "\033[33m",  # Light Yellow (for highlight)
    "\033[35m",  # Light Magenta (for highlight)
    "\033[31m",  # Light Red (for highlight)
]

RESET = "\033[0m"
CLEAR_SCREEN = "\033[2J\033[H"

SECTION_HEADER = re.compile(r"^---\s(.*)\s---$")

def colorize(text, color_code):
    return f"{color_code}{text}{RESET}"

def print_centered_typewriter(text, color=None, delay=0.01):
    width = shutil.get_terminal_size((80, 20)).columns
    for line in text.splitlines():
        line_stripped = line.rstrip("\n")
        pad = max(0, (width - len(line_stripped)) // 2)
        out = " " * pad + (colorize(line_stripped, color) if color else line_stripped)
        typewriter_line(out, color=None, delay=delay)
        sys.stdout.write("\n")
        sys.stdout.flush()

def typewriter_line(line, color=None, delay=0.01, highlight_mask=None, highlight_color=None):
    runs = re.findall(r'\S+| +', line)
    idx = 0
    for run in runs:
        if run.isspace():
            sys.stdout.write(run)
            sys.stdout.flush()
            time.sleep(delay)
            idx += len(run)
        else:
            for i, c in enumerate(run):
                if highlight_mask and idx < len(highlight_mask) and highlight_mask[idx]:
                    # Use a lighter version of the main color for highlight
                    if highlight_color:
                        sys.stdout.write(colorize(c, highlight_color))
                    elif color == COLORS[3]:  # Cyan
                        sys.stdout.write(colorize(c, COLORS[6]))  # Green as lighter for cyan
                    elif color == COLORS[2]:  # Blue
                        sys.stdout.write(colorize(c, COLORS[7]))  # Yellow as lighter for blue
                    elif color == COLORS[4]:  # Green
                        sys.stdout.write(colorize(c, COLORS[8]))  # Magenta as lighter for green
                    elif color == COLORS[5]:  # Yellow
                        sys.stdout.write(colorize(c, COLORS[9]))  # Red as lighter for yellow
                    elif color == COLORS[1]:  # Magenta
                        sys.stdout.write(colorize(c, COLORS[3]))  # Cyan as lighter for magenta
                    else:
                        sys.stdout.write(colorize(c, COLORS[7]))  # Default to Yellow
                else:
                    sys.stdout.write(colorize(c, color) if color else c)
                sys.stdout.flush()
                time.sleep(delay)
                idx += 1

def print_typewriter(line, color=None, delay=0.01, highlight_mask=None, highlight_color=None):
    typewriter_line(line, color=color, delay=delay, highlight_mask=highlight_mask, highlight_color=highlight_color)
    sys.stdout.write("\n")
    sys.stdout.flush()

def load_font_knowledge(path=".vscode/entities.json"):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    font_map = {}
    for ent in data.get("entities", []):
        if ent.get("entityType") == "figlet_font":
            font_map[ent["name"].replace(".flf", "").lower()] = ent["observations"][0] if ent.get("observations") else ""
    return font_map

def load_scene_config(path=".vscode/cyber-k8s-scene-config.yaml"):
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    scenes = data.get("scenes", [])
    global_drawing = data.get("global", {}).get("drawing_duration", 4.0)
    global_pause = data.get("global", {}).get("pause_duration", 2.0)
    return scenes, global_drawing, global_pause

def diff_lines(old, new):
    sm = difflib.SequenceMatcher(None, old, new)
    result = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            for i in range(j1, j2):
                result.append((new[i], None))
        elif tag == "replace" or tag == "insert":
            for i in range(j1, j2):
                mask = [True] * len(new[i])
                result.append((new[i], mask))
        elif tag == "delete":
            continue
    return result

def split_sections(batch):
    sections = []
    current_section = None
    current_lines = []
    for line in batch:
        m = SECTION_HEADER.match(line)
        if m:
            if current_section is not None:
                sections.append((current_section, current_lines))
            current_section = m.group(1).strip()
            current_lines = [line]
        else:
            if current_section is None:
                current_section = "Unknown Section"
                current_lines = []
            current_lines.append(line)
    if current_section is not None:
        sections.append((current_section, current_lines))
    return sections

def run_commands(commands):
    output_sections = []
    for cmd in commands:
        try:
            proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            out, _ = proc.communicate(timeout=10)
            lines = out.splitlines()
            output_sections.append((cmd, lines))
        except Exception as e:
            output_sections.append((cmd, [f"[ERROR] {cmd}: {e}"]))
    return output_sections

def count_timed_units(lines):
    total = 0
    for line in lines:
        runs = re.findall(r'\S+| +', line)
        for run in runs:
            if run.isspace():
                total += 1
            else:
                total += len(run)
    return total

def main():
    parser = argparse.ArgumentParser(
        description="""
Cyber K8s Log Stream - Funky Mode
Uses .vscode/entities.json (font knowledge) and .vscode/cyber-k8s-scene-config.yaml (scene config) to drive the display.
"""
    )
    parser.add_argument("logfile", nargs="?", default="/tmp/colima-k8s-persistent.log",
                        help="Path to log file to stream (default: /tmp/colima-k8s-persistent.log). Use '-' for stdin.")
    parser.add_argument("--cmd", type=str, default=None,
                        help="Shell command to run and stream its output (overrides logfile).")
    args = parser.parse_args()

    color_cycle = [COLORS[1], COLORS[2], COLORS[3], COLORS[4], COLORS[5], COLORS[0]]
    color_idx = [0]

    # Load font knowledge and scene config
    font_knowledge = load_font_knowledge()
    allowed_fonts = set(font_knowledge.keys())
    scenes, global_drawing, global_pause = load_scene_config()

    last_sections = {}

    def get_scene_font(scene):
        font = scene.get("font", None)
        if font and font.lower() in allowed_fonts:
            return font.lower()
        for font_name, desc in font_knowledge.items():
            if font_name in scene["name"].lower():
                return font_name
        return next(iter(allowed_fonts)) if allowed_fonts else "block"

    def stream_scene(scene):
        sys.stdout.write(CLEAR_SCREEN)
        sys.stdout.flush()
        font = get_scene_font(scene)
        figlet_text = scene["name"]
        drawing_duration = scene.get("drawing_duration", global_drawing)
        pause_duration = scene.get("pause_duration", global_pause)
        header_lines = text2art(figlet_text, font=font).splitlines()
        header_time = min(drawing_duration * 0.25, 2.0)
        header_units = count_timed_units(header_lines)
        header_delay = header_time / max(header_units, 1)
        for line in header_lines:
            typewriter_line(line, color=color_cycle[color_idx[0] % len(color_cycle)], delay=header_delay)
            sys.stdout.write("\n")
            sys.stdout.flush()
        color_idx[0] += 1
        if "message" in scene:
            msg = scene["message"]
            msg_lines = msg.splitlines()
            data_time = drawing_duration - header_time
            msg_units = count_timed_units(msg_lines)
            if msg_units == 0:
                time.sleep(data_time)
            else:
                msg_delay = data_time / msg_units
                for line in msg_lines:
                    print_typewriter(line, color=COLORS[3], delay=msg_delay)
            time.sleep(pause_duration)
            return
        output_sections = run_commands(scene.get("commands", []))
        data_time = drawing_duration - header_time
        flat_lines = []
        for cmd, lines in output_sections:
            flat_lines.append((cmd, None))
            for line in lines:
                flat_lines.append((cmd, line))
        # Calculate highlight mask for changed lines
        total_units = 0
        highlight_map = {}
        for cmd, lines in output_sections:
            prev_lines = last_sections.get(cmd, [])
            diffed = diff_lines(prev_lines, lines)
            for i, (line, mask) in enumerate(diffed):
                if mask:
                    highlight_map[(cmd, line)] = True
        for cmd, line in flat_lines:
            if line is None:
                total_units += 1
            else:
                runs = re.findall(r'\S+| +', line)
                for run in runs:
                    if run.isspace():
                        total_units += 1
                    else:
                        total_units += len(run)
        if total_units == 0:
            time.sleep(data_time)
        else:
            delay_per_unit = data_time / total_units
            line_idx = 0
            for cmd, lines in output_sections:
                sys.stdout.write("\n")
                sys.stdout.write(colorize(f"$ {cmd}", COLORS[2]) + "\n")
                sys.stdout.flush()
                prev_lines = last_sections.get(cmd, [])
                diffed = diff_lines(prev_lines, lines)
                for line, mask in diffed:
                    highlight = highlight_map.get((cmd, line), False)
                    if highlight:
                        print_typewriter(line, color=COLORS[3], delay=delay_per_unit, highlight_mask=[True]*len(line), highlight_color=COLORS[6])
                    else:
                        print_typewriter(line, color=COLORS[3], delay=delay_per_unit)
                    line_idx += 1
            while line_idx < len(flat_lines):
                time.sleep(delay_per_unit)
                line_idx += 1
            for cmd, lines in output_sections:
                last_sections[cmd] = lines.copy()
        time.sleep(pause_duration)

    def stream_lines(line_iter, scenes=scenes):
        while True:
            for scene in scenes:
                stream_scene(scene)

    if args.cmd:
        proc = subprocess.Popen(args.cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        stream_lines(proc.stdout)
        return

    stream_lines([], scenes=scenes)

if __name__ == "__main__":
    main()