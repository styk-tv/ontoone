#!/usr/bin/env python3

# ==============================================================================
# Cyber K8s Monitor - A Python Script for Stylized Kubernetes Status Display
# ==============================================================================
# This script uses the 'curses' library to create a dynamic, cyberpunk-themed
# terminal UI for monitoring Kubernetes cluster status. It intercepts output
# from an external Bash script (e.g., 'colima-k8s-persistent.sh') and presents
# it with real-time updates, character-by-character typing effects, and
# adaptive layout for various terminal sizes.
#
# Features:
# - Leverages Python's 'curses' library for robust terminal UI management.
# - Intercepts output from a specified external source script in a subprocess.
# - Parses output into distinct sections (Colima Status, Kube Info, Pods, etc.).
# - Dynamically creates and manages 'curses' windows for each section.
# - Implements a character-by-character "typing" effect with calculated delays
#   to distribute text streaming over the refresh interval.
# - Adapts the UI layout and complexity based on the current terminal dimensions.
# - Supports resizing: UI re-renders automatically when the terminal is resized.
# - Includes cyberpunk-themed colors, ASCII borders, and a blinking indicator.
# - Ensures graceful shutdown, restoring terminal to its original state.
#
# Usage:
# 1. Ensure Python 3 is installed.
# 2. Save this script as 'cyber-k8s-monitor-curses.py'.
# 3. Make it executable: 'chmod +x cyber-k8s-monitor-curses.py'.
# 4. Update your VSCode tasks.json to run this script.
# 5. Ensure SOURCE_SCRIPT_PATH points to your Kubernetes monitoring script.
#
# To exit: Press 'q' or Ctrl+C.
# ==============================================================================

import curses
import time
import subprocess
import os
import re
import select
import logging
import random
import sys # For sys.exit()

# Try to import 'art' library, provide instructions if not found
try:
    import art
except ImportError:
    print("The 'art' library is not installed.")
    print("Please install it using: pip install art")
    sys.exit(1)

# ==============================================================================
#                             Logging Setup
# ==============================================================================
LOG_FILE = "/tmp/cyber_k8s_monitor_debug.log"
logging.basicConfig(filename=LOG_FILE, level=logging.DEBUG,
                    format='%(asctime)s - %(levelname)s - %(message)s')
logging.info("Starting Cyber K8s Monitor Python script (curses version).")

# ==============================================================================
#                             Configuration
# ==============================================================================
# Base delay for character-by-character printing (seconds)
CHAR_PRINT_MIN_DELAY_SEC = 0.2 # Increased to 200ms
CHAR_PRINT_MAX_DELAY_SEC = 0.2 # Increased to 200ms

# Expected interval at which the source Kubernetes script produces new output
UPDATE_INTERVAL_SEC = 15
# Refresh rate for the curses display loop (how often to check for resize/input/blinker)
DISPLAY_REFRESH_RATE_SEC = 0.05 # 50ms, for smoother animation and resize handling

# Path to the original Kubernetes monitoring script (e.g., 'colima-k8s-persistent.sh')
SOURCE_SCRIPT_PATH = os.path.join(os.path.dirname(__file__), 'colima-k8s-persistent.sh')

# Minimum terminal dimensions for a legible display.
MIN_COLS = 40
MIN_LINES = 15

# Define how many sections to cycle through in the main data stream panel
SECTION_CYCLE_ORDER = [
    "Active Pods",
    "Service Status",
    "Kubernetes Nodes", # This will combine Nodes and Node Resource Usage
    "INGRESS Status",
    "Colima Status",
    "Kubernetes Cluster Info"
]
current_cycle_index = 0 # Index to track which section is currently displayed

# ==============================================================================
#                             Global State
# ==============================================================================
sections = {
    "Timestamp": "Initializing...",
    "Colima Status": "",
    "Kubernetes Cluster Info": "",
    "Kubernetes Nodes": "",
    "Node Resource Usage": "", # Will be combined into "Kubernetes Nodes" in display
    "INGRESS Status": "",
    "Active Pods": "",
    "Service Status": "",
    "Unknown Section": "" # Fallback for unparsed data
}
last_full_output = ""
source_process = None
temp_output_file = None
stdscr = None # Global for the main curses screen
main_content_win = None # Global for the main content window
last_drawn_section_title = None # To track which section was last drawn to the main content window

# ==============================================================================
#                             ASCII Art Definitions (using 'art' library)
# ==============================================================================
ART_TITLE_FONT = "invita" # Chosen font for a specific cyberpunk style
ASCII_TITLE_TEXT = "KUBEMON"

# ==============================================================================
#                             Core Functions
# ==============================================================================

def cleanup():
    """Restores terminal to normal state and cleans up subprocess/temp files."""
    global source_process, temp_output_file, stdscr
    logging.info("Starting cleanup process.")
    if source_process and source_process.poll() is None:
        try:
            logging.info("Terminating source subprocess.")
            source_process.terminate()
            source_process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            logging.warning("Source subprocess did not terminate gracefully, killing.")
            source_process.kill()
        except Exception as e:
            logging.error(f"Error during source process termination: {e}")

    if temp_output_file:
        try:
            logging.info(f"Closing and removing temporary file: {temp_output_file.name}")
            temp_output_file.close()
            if os.path.exists(temp_output_file.name):
                os.remove(temp_output_file.name)
        except Exception as e:
            logging.error(f"Error during temporary file cleanup: {e}")

    if stdscr:
        logging.info("Exiting curses mode.")
        try:
            curses.nocbreak()
            curses.echo()
            curses.endwin()
        except Exception as e:
            logging.error(f"Error during curses cleanup: {e}")
    
    logging.info("Cleanup complete.")
    print("Cyber K8s Monitor Shut Down.")

def parse_raw_output(raw_output: str):
    """Parses raw script output into sections dictionary."""
    global sections
    current_section_name = ""
    current_section_content = []

    # Initialize all sections to empty, except for initial timestamp placeholder
    initial_timestamp_placeholder = sections.get("Timestamp") if sections.get("Timestamp") == "Initializing..." else ""
    for key in sections:
        sections[key] = ""
    if initial_timestamp_placeholder:
        sections["Timestamp"] = initial_timestamp_placeholder

    lines = raw_output.splitlines()
    for line in lines:
        if re.match(r"^===\s.*===$", line):
            if current_section_name:
                sections[current_section_name] = "\n".join(current_section_content).strip()
            current_section_name = "Timestamp"
            sections[current_section_name] = line
            current_section_content = []
        elif re.match(r"^---\s.*---$", line):
            if current_section_name:
                sections[current_section_name] = "\n".join(current_section_content).strip()
            
            match = re.match(r"^---\s(.*)\s---$", line)
            if match:
                section_title_raw = match.group(1).strip()
                # Map raw section titles to our internal section keys
                if section_title_raw == "Colima Status": current_section_name = "Colima Status"
                elif section_title_raw == "Kubernetes Cluster Info": current_section_name = "Kubernetes Cluster Info"
                elif section_title_raw == "Kubernetes Nodes": current_section_name = "Kubernetes Nodes"
                elif section_title_raw == "Node Resource Usage": current_section_name = "Node Resource Usage"
                elif section_title_raw == "INGRESS Status": current_section_name = "INGRESS Status"
                elif section_title_raw == "Active Pods": current_section_name = "Active Pods"
                elif section_title_raw == "Service Status": current_section_name = "Service Status"
                else: current_section_name = "Unknown Section"
            else:
                current_section_name = "Unknown Section"
            current_section_content = []
        else:
            current_section_content.append(line)

    if current_section_name:
        sections[current_section_name] = "\n".join(current_section_content).strip()
    
    logging.debug(f"Parsed sections: {list(sections.keys())}")
    logging.debug(f"Colima Status content length: {len(sections.get('Colima Status', ''))}")
    logging.debug(f"Active Pods content length: {len(sections.get('Active Pods', ''))}")


def type_text_to_window(win, text, color_pair, delay_sec):
    """Prints text character by character to a curses window with a delay."""
    win.attron(color_pair)
    for char in text:
        try:
            win.addch(char)
            # win.noutrefresh() # Mark for update, but don't force screen redraw yet
            # curses.doupdate() # Perform all pending updates
            time.sleep(delay_sec)
        except curses.error:
            # Handle cases where addch tries to write outside window bounds
            break
    win.attroff(color_pair)

def draw_box(win, color_pair):
    """Draws a single-line ASCII border around a curses window."""
    try:
        win.attron(color_pair)
        win.box()
        win.attroff(color_pair)
    except curses.error:
        logging.warning(f"Could not draw box for window at {win.getbegyx()}, {win.getmaxyx()} due to curses error. Skipping box.")
        pass # Ignore error if window is too small for a box

def draw_section_content_matrix_style(win, title, content_key, color_title_pair, color_content_pair, color_highlight_pair, color_dim_pair):
    """
    Displays a section's content with matrix-like flow, key/value isolation,
    and adaptive word wrapping within a single main window.
    """
    win_height, win_width = win.getmaxyx()
    win.clear() # Clear the window content before drawing new data
    
    # Draw border for the main content window
    draw_box(win, color_title_pair)

    # Content area inside the box
    content_start_y = 1
    content_start_x = 1
    content_max_height = win_height - 2
    content_max_width = win_width - 2

    if content_max_height <= 0 or content_max_width <= 0:
        win.noutrefresh()
        curses.doupdate()
        return # No space for content

    display_content = sections.get(content_key, "").strip()
    if content_key == "Kubernetes Nodes": # Special combined section for display
        display_content = sections.get("Kubernetes Nodes", "").strip()
        if sections.get("Node Resource Usage", "").strip():
             display_content += "\n\n" + sections.get("Node Resource Usage", "").strip()


    # Apply a typing delay that ensures the content streams over the UPDATE_INTERVAL_SEC
    total_chars_in_display_area = 0
    
    # First, filter Colima INFO lines if applicable
    processed_lines_for_display = []
    if title == "Colima Status":
        for line in display_content.splitlines():
            if not re.match(r"^(INFO|time)=\[[0-9]{4}\].*$", line): # Filter INFO and time= lines from Colima status
                processed_lines_for_display.append(line.strip())
    else:
        processed_lines_for_display = [line.strip() for line in display_content.splitlines()]

    # Simulate word wrapping to get a more accurate count of characters that will be typed
    for line in processed_lines_for_display:
        current_segment = line
        while current_segment:
            if len(current_segment) <= content_max_width:
                total_chars_in_display_area += len(current_segment)
                break
            else:
                cut_point = content_max_width
                if ' ' in current_segment[:content_max_width]:
                    last_space = current_segment[:content_max_width].rfind(' ')
                    if last_space > 0:
                        cut_point = last_space
                total_chars_in_display_area += len(current_segment[:cut_point])
                current_segment = current_segment[cut_point:].lstrip()
    
    # Calculate delay per char
    if total_chars_in_display_area > 0:
        # Use the fixed typing delay as requested, instead of dynamically calculating
        actual_delay_per_char = random.uniform(CHAR_PRINT_MIN_DELAY_SEC, CHAR_PRINT_MAX_DELAY_SEC)
    else:
        actual_delay_per_char = CHAR_PRINT_MIN_DELAY_SEC # Fallback if no content

    logging.debug(f"Displaying '{title}'. Total chars: {total_chars_in_display_area}, Delay per char: {actual_delay_per_char:.4f}s")


    # Add section title prominently inside the box, top-left
    try:
        win.addstr(content_start_y, content_start_x, f"--- {title} ---", curses.A_BOLD | color_title_pair)
        win.clrtoeol()
        win.move(content_start_y + 2, content_start_x) # Start content after title and a blank line
    except curses.error:
        pass # Ignore if window too small for title

    current_content_row = content_start_y + 2 # Adjusted start row after title
    
    if not display_content.strip():
        try:
            win.addstr(current_content_row, content_start_x, "No data available...", curses.A_DIM | color_dim_pair)
        except curses.error:
            pass
        win.noutrefresh()
        curses.doupdate()
        return

    # Now, process lines for actual display with highlighting and wrapping
    for line in processed_lines_for_display:
        if current_content_row >= content_max_height:
            try:
                # Place ellipsis at the bottom-right of the content area
                win.addstr(win_height - 1, win_width - 4, "...", curses.A_BLINK | color_content_pair)
            except curses.error:
                pass
            break

        wrapped_lines = []
        remaining_line = line
        while remaining_line and len(wrapped_lines) + current_content_row < content_max_height:
            if len(remaining_line) <= content_max_width:
                wrapped_lines.append(remaining_line)
                remaining_line = ""
            else:
                cut_point = content_max_width
                if ' ' in remaining_line[:content_max_width]:
                    last_space = remaining_line[:content_max_width].rfind(' ')
                    if last_space > 0:
                        cut_point = last_space
                
                wrapped_lines.append(remaining_line[:cut_point])
                remaining_line = remaining_line[cut_point:].lstrip()

        for segment in wrapped_lines:
            if current_content_row >= content_max_height:
                break
            
            try:
                win.move(current_content_row, content_start_x)
                win.clrtoeol() # Clear prior content on this line

                # Dynamic highlighting and color application
                # Split by words to apply color selectively
                words = segment.split()
                
                for word_idx, word in enumerate(words):
                    current_word_color = color_content_pair # Default
                    
                    # Check for specific patterns/keywords
                    if word in ["Running", "Ready", "Terminating", "Error", "Pending", "CrashLoopBackOff", "Completed"]:
                        current_word_color = color_highlight_pair # Neon Green
                    elif re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$", word): # Basic IP regex
                        current_word_color = color_highlight_pair # Neon Green
                    elif re.match(r"^\d+m$", word) or re.match(r"^\d+Mi$", word) or word.endswith('%'): # CPU/Memory usage (e.g., 230m, 1466Mi, 2%)
                         current_word_color = color_highlight_pair # Neon Green
                    elif word in ["NAMESPACE", "NAME", "STATUS", "READY", "RESTARTS", "AGE", "IP", "NODE", "TYPE", "CLUSTER-IP", "EXTERNAL-IP", "PORT(S)", "HOSTS", "CLASS", "CPU(cores)", "CPU(%)", "MEMORY(bytes)", "MEMORY(%)", "CONTROL-PLANE", "VERSION"]: # Table headers
                        current_word_color = curses.A_BOLD | color_title_pair # Bold + Title Color
                    
                    # Attempt to print the word
                    # Check if the word and a trailing space will fit
                    if win.getyx()[1] + len(word) + (1 if word_idx < len(words) - 1 else 0) > content_max_width + content_start_x:
                        break # Stop if going beyond boundary

                    type_text_to_window(win, word, current_word_color, actual_delay_per_char)
                    
                    # Add space after the word, if it's not the last word
                    if word_idx < len(words) - 1:
                        type_text_to_window(win, " ", color_content_pair, actual_delay_per_char)
                
            except curses.error:
                pass # Ignore if out of bounds (e.g., window resized small while typing)

            current_content_row += 1
            win.noutrefresh()

    win.noutrefresh() # Mark for update

def draw_main_screen(stdscr):
    """
    Calculates layout, draws static header/footer, and triggers dynamic content
    drawing for the main data stream panel.
    This function is called frequently, but only the content panel is re-drawn
    with typing if data or cycle changes.
    """
    global sections, main_content_win, current_cycle_index, last_drawn_section_title

    # Clear the entire screen (only on initial draw or resize)
    # This prevents ghosting from previous dimensions when resizing
    max_y, max_x = stdscr.getmaxyx()
    if not hasattr(draw_main_screen, 'last_max_y') or \
       not hasattr(draw_main_screen, 'last_max_x') or \
       draw_main_screen.last_max_y != max_y or \
       draw_main_screen.last_max_x != max_x:
        stdscr.clear() # Only clear if dimensions changed
        draw_main_screen.last_max_y = max_y
        draw_main_screen.last_max_x = max_x
        logging.info(f"Screen cleared due to resize. New dimensions: {max_x}x{max_y}")
    
    curses.curs_set(0) # Hide cursor for less flicker
    stdscr.nodelay(True) # Ensure non-blocking getch for blinker

    logging.debug(f"Terminal dimensions: Y={max_y}, X={max_x}")

    # --- Initialize Color Pairs ---
    # curses.init_pair(id, foreground_color, background_color)
    # Default 8/16 colors
    curses.init_pair(1, curses.COLOR_WHITE, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_BLUE, curses.COLOR_BLACK)   
    curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK) # Orange (closest default)
    curses.init_pair(4, curses.COLOR_RED, curses.COLOR_BLACK)    
    curses.init_pair(5, curses.COLOR_GREEN, curses.COLOR_BLACK)  
    curses.init_pair(6, curses.COLOR_MAGENTA, curses.COLOR_BLACK) # Purple (closest default)

    # Try 256 colors if supported
    if curses.COLORS >= 256:
        try:
            curses.init_pair(2, 33, 0)  # Cyber Blue (e.g., #0087FF)
            curses.init_pair(3, 208, 0) # Cyber Orange (e.g., #FF8700)
            curses.init_pair(4, 196, 0) # Cyber Red (e.g., #FF0000)
            curses.init_pair(5, 47, 0)  # Neon Green (e.g., #00FF5F) - for status/highlight
            curses.init_pair(6, 129, 0) # Cyber Purple (e.g., #8700FF) - for dim/waiting
            # Add more distinctive colors for highlighting
            curses.init_pair(7, 226, 0) # Bright Yellow (e.g., for certain metrics)
            curses.init_pair(8, 201, 0) # Bright Pink (e.g., for specific alerts)
        except curses.error as e:
            logging.warning(f"Error initializing 256 colors, falling back to 8-colors: {e}")
            pass

    # Assign color pairs for use
    COLOR_DEFAULT_PAIR = curses.color_pair(1)
    COLOR_CYBER_BLUE_PAIR = curses.color_pair(2)
    COLOR_CYBER_ORANGE_PAIR = curses.color_pair(3)
    COLOR_CYBER_RED_PAIR = curses.color_pair(4)
    COLOR_CYBER_GREEN_HIGHLIGHT_PAIR = curses.color_pair(5) # For status, IP, usage
    COLOR_CYBER_PURPLE_DIM_PAIR = curses.color_pair(6) # For dim/placeholder
    COLOR_CYBER_YELLOW_HIGHLIGHT_PAIR = curses.color_pair(7)
    COLOR_CYBER_PINK_HIGHLIGHT_PAIR = curses.color_pair(8)


    # Display warning if terminal is too small
    header_offset = 0
    if max_x < MIN_COLS or max_y < MIN_LINES:
        warning_msg = f"Terminal too small! Min {MIN_COLS}x{MIN_LINES} required. Current: {max_x}x{max_y}. Content may be truncated."
        try:
            stdscr.addstr(0, 0, warning_msg, curses.A_REVERSE | COLOR_CYBER_RED_PAIR)
        except curses.error:
            pass
        header_offset = 1

    # --- Header Area (ASCII Title and Timestamp) ---
    # Generate ASCII art dynamically using the 'art' library
    ascii_title_lines = [line for line in art.text2art(ASCII_TITLE_TEXT, font=ART_TITLE_FONT).splitlines() if line.strip()]

    ascii_title_height = len(ascii_title_lines)
    header_pad = 2
    header_total_height = ascii_title_height + header_pad + header_offset
    footer_height = 3
    data_area_height = max_y - header_total_height - footer_height

    if data_area_height < 0:
        data_area_height = 0

    title_max_width = 0
    if ascii_title_lines:
        title_max_width = max(len(line) for line in ascii_title_lines)

    title_start_x = int((max_x - title_max_width) / 2)
    for i, line in enumerate(ascii_title_lines):
        try:
            stdscr.addstr(header_offset + i, title_start_x, line, curses.A_BOLD | COLOR_CYBER_BLUE_PAIR)
        except curses.error:
            pass

    # Display timestamp below the ASCII title
    import datetime
    last_update_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    timestamp_content = f"Last updated: {last_update_time}"
    timestamp_stripped = re.sub(r'\x1b\[[0-9;]*m', '', timestamp_content) # Strip ANSI for length calc
    timestamp_col = int((max_x - len(timestamp_stripped)) / 2)
    try:
        stdscr.addstr(header_offset + ascii_title_height + 1, timestamp_col, timestamp_content, COLOR_DEFAULT_PAIR)
    except curses.error:
        pass

    # --- Main Data Stream Panel ---
    main_panel_start_y = header_total_height + 1
    main_panel_height = data_area_height
    main_panel_width = max_x

    if main_panel_height <= 0 or main_panel_width <= 0:
        logging.warning("Main panel has zero or negative dimensions. Cannot draw content.")
        try:
            stdscr.addstr(main_panel_start_y, 0, "No space for content.", curses.A_REVERSE | COLOR_CYBER_RED_PAIR)
        except curses.error:
            pass
        return

    # Create or resize the main content window
    global main_content_win
    if main_content_win is None:
        main_content_win = curses.newwin(main_panel_height, main_panel_width, main_panel_start_y, 0)
    else:
        try:
            main_content_win.resize(main_panel_height, main_panel_width)
            main_content_win.mvwin(main_panel_start_y, 0)
        except curses.error as e:
            logging.error(f"Error resizing main_content_win: {e}. Attempting to recreate window.")
            main_content_win = curses.newwin(main_panel_height, main_panel_width, main_panel_start_y, 0)

    # Determine which section to display in the main panel based on current_cycle_index
    try:
        current_section_title = SECTION_CYCLE_ORDER[current_cycle_index % len(SECTION_CYCLE_ORDER)]
    except ZeroDivisionError:
        current_section_title = "No Data Configured"
        logging.error("SECTION_CYCLE_ORDER is empty!")
        
    # Only redraw/re-type the content if the section has changed OR the data has changed
    # (The main loop will set a flag if data has changed)
    # This prevents re-typing the same content over and over.
    if current_section_title != last_drawn_section_title or \
       getattr(draw_main_screen, 'force_content_redraw', False): # Check the force redraw flag from main loop
        
        logging.info(f"Redrawing main content window for: {current_section_title}")
        draw_section_content_matrix_style(
            main_content_win,
            current_section_title,
            current_section_title, # Content key is often same as title for simplicity
            COLOR_CYBER_BLUE_PAIR,
            COLOR_DEFAULT_PAIR,
            COLOR_CYBER_GREEN_HIGHLIGHT_PAIR,
            COLOR_CYBER_PURPLE_DIM_PAIR
        )
        last_drawn_section_title = current_section_title
        draw_main_screen.force_content_redraw = False # Reset flag after drawing

    # --- Footer Area ---
    footer_row = max_y - footer_height + 1
    footer_text = "[ Press 'q' to Exit | K8s Cyber Monitor v2.2 | Created by Gemini ]" # Updated version
    footer_col = int((max_x - len(footer_text)) / 2)
    try:
        stdscr.addstr(footer_row, footer_col, footer_text, curses.A_BOLD | COLOR_CYBER_RED_PAIR)
    except curses.error:
        pass

    # --- Animated Cursor/Indicator in the Footer ---
    indicator_char = ">"
    indicator_pos_row = max_y - 1
    indicator_pos_col = max_x - 3
    
    try:
        stdscr.addstr(indicator_pos_row, indicator_pos_col, indicator_char, curses.A_BOLD | curses.A_BLINK | COLOR_CYBER_GREEN_HIGHLIGHT_PAIR)
    except curses.error:
        pass

    stdscr.noutrefresh() # Mark main screen for update (only for static elements)
    curses.doupdate() # Perform all pending updates from all windows and main screen


def main(stdscr_instance):
    global stdscr, source_process, temp_output_file, last_full_output, current_cycle_index
    stdscr = stdscr_instance

    logging.info("Main function started.")

    stdscr.timeout(int(DISPLAY_REFRESH_RATE_SEC * 1000))
    curses.noecho()
    curses.cbreak()
    stdscr.keypad(True)
    curses.curs_set(1) # Make cursor visible (normal cursor)
    curses.start_color()
    
    # Initialize the force_content_redraw flag
    draw_main_screen.force_content_redraw = True 

    # Initial "Initializing..." message
    logging.info("Starting source script subprocess setup.")
    try:
        temp_output_file = open("/tmp/k8s_monitor_output.tmp", "w+", encoding='utf-8')
        logging.info(f"Source script path: {SOURCE_SCRIPT_PATH}")
        source_process = subprocess.Popen(
            [SOURCE_SCRIPT_PATH],
            stdout=temp_output_file,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1, # Line-buffered
            universal_newlines=True
        )
        logging.info(f"Source script PID: {source_process.pid}")
        
        # Display initial message using curses
        stdscr.addstr(0, 0, "Initializing Cyber Kube Monitor... Waiting for initial data.", curses.A_BOLD)
        stdscr.refresh()
        
        # Give the source script a more generous moment to start up
        time.sleep(10)
        logging.info("Initial sleep complete. Attempting first data read.")

    except FileNotFoundError:
        logging.error(f"Error: Source script '{SOURCE_SCRIPT_PATH}' not found.")
        stdscr.clear()
        stdscr.addstr(0, 0, f"Error: Source script '{SOURCE_SCRIPT_PATH}' not found. Exiting.", curses.A_REVERSE | curses.color_pair(4))
        stdscr.addstr(1, 0, "Please ensure 'colima-k8s-persistent.sh' exists and is executable.")
        stdscr.refresh()
        stdscr.getch()
        return
    except Exception as e:
        logging.error(f"Error starting source script subprocess: {e}", exc_info=True)
        stdscr.clear()
        stdscr.addstr(0, 0, f"Error starting source script: {e}. Exiting.", curses.A_REVERSE | curses.color_pair(4))
        stdscr.refresh()
        stdscr.getch()
        return

    last_cycle_change_time = time.time() # Tracks when the section in the main panel last changed

    running = True
    while running:
        char = stdscr.getch() # Non-blocking getch due to stdscr.timeout
        if char == ord('q'):
            logging.info("'q' pressed. Exiting main loop.")
            running = False
        elif char == curses.KEY_RESIZE:
            logging.info("Terminal resize event detected. Forcing full redraw.")
            # When resized, force a full redraw, including re-typing current content
            draw_main_screen.force_content_redraw = True 
            # draw_main_screen will be called later in the loop.

        current_time = time.time()

        # Check for new data from the source script (updates global 'sections' dict)
        temp_output_file.seek(0)
        current_full_output = temp_output_file.read()
        
        if current_full_output != last_full_output:
            logging.info("New data detected. Parsing and forcing content redraw.")
            last_full_output = current_full_output
            parse_raw_output(current_full_output)
            # When new data arrives, force re-typing of the current content
            draw_main_screen.force_content_redraw = True 

        # Cycle the displayed section only after UPDATE_INTERVAL_SEC has passed
        if current_time - last_cycle_change_time >= UPDATE_INTERVAL_SEC:
            current_cycle_index = (current_cycle_index + 1) % len(SECTION_CYCLE_ORDER)
            logging.info(f"Cycling to section: {SECTION_CYCLE_ORDER[current_cycle_index]}. Forcing content redraw.")
            last_cycle_change_time = current_time
            # When section cycles, force re-typing of the new content
            draw_main_screen.force_content_redraw = True 
        
        # Always call draw_main_screen. It will decide if the content panel needs re-typing.
        draw_main_screen(stdscr)
            
    logging.info("Main loop finished.")
    cleanup()

if __name__ == '__main__':
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        logging.info("KeyboardInterrupt (Ctrl+C) detected outside curses.wrapper.")
        pass
    except Exception as e:
        logging.critical(f"Unhandled exception outside curses.wrapper: {e}", exc_info=True)
        sys.exit(1)
    finally:
        if stdscr:
            cleanup()
        else:
            logging.info("Curses not initialized, performing basic cleanup.")
            if source_process and source_process.poll() is None:
                try: source_process.terminate()
                except: pass
            if temp_output_file and os.path.exists(temp_output_file.name):
                try: temp_output_file.close(); os.remove(temp_output_file.name)
                except: pass
