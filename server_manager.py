#!/usr/bin/env python3
"""
EriUI Server Manager
====================
Manages all eriui backend services:
- ComfyUI (port 8199)
- OneTrainer Web UI (port 8100)
- CORS Server (port 8899) - only for web mode
- Flutter App (desktop or web)

Usage:
  python server_manager.py              # Interactive menu
  python server_manager.py start        # Start desktop mode (ComfyUI + OneTrainer + Flutter)
  python server_manager.py start --web  # Start web mode (adds CORS server, uses Chrome)
  python server_manager.py stop         # Stop all services
  python server_manager.py status       # Show status of all services
  python server_manager.py restart      # Restart all services
  python server_manager.py logs <name>  # View logs for a service
"""

import os
import sys
import time
import signal
import socket
import subprocess
import json
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, List

# Configuration
ERIUI_DIR = Path(__file__).parent.resolve()
COMFYUI_DIR = ERIUI_DIR / "comfyui" / "ComfyUI"
ONETRAINER_DIR = Path("/home/alex/OneTrainer")
FLUTTER_APP_DIR = ERIUI_DIR / "flutter_app"
FLUTTER_BIN = Path("/home/alex/flutter/bin/flutter")
PID_DIR = ERIUI_DIR / ".pids"
LOG_DIR = Path("/tmp/eriui_logs")

# Service definitions
@dataclass
class Service:
    name: str
    port: int
    start_cmd: List[str]
    cwd: Path
    env_setup: Optional[str] = None  # e.g., "source venv/bin/activate"
    pid_file: Optional[Path] = None
    log_file: Optional[Path] = None
    optional: bool = False  # If True, not started by default with "start all"
    description: str = ""

    def __post_init__(self):
        self.pid_file = PID_DIR / f"{self.name}.pid"
        self.log_file = LOG_DIR / f"{self.name}.log"


SERVICES = {
    "comfyui": Service(
        name="comfyui",
        port=8199,
        start_cmd=["python", "main.py", "--port", "8199", "--listen", "0.0.0.0"],
        cwd=COMFYUI_DIR,
        env_setup="source venv/bin/activate",
    ),
    "onetrainer": Service(
        name="onetrainer",
        port=8100,
        start_cmd=["python", "-m", "web_ui.run", "--port", "8100"],
        cwd=ONETRAINER_DIR,
        env_setup="source venv/bin/activate",
    ),
    "cors": Service(
        name="cors",
        port=8899,
        start_cmd=["python3", "cors_server.py"],
        cwd=ERIUI_DIR,
        optional=True,
        description="Only needed for web mode",
    ),
    "flutter": Service(
        name="flutter",
        port=0,  # Flutter doesn't bind a specific port we manage
        start_cmd=[str(FLUTTER_BIN), "run", "-d", "linux"],
        cwd=FLUTTER_APP_DIR,
    ),
    "flutter-web": Service(
        name="flutter-web",
        port=0,
        start_cmd=[str(FLUTTER_BIN), "run", "-d", "chrome", "--web-port", "8080"],
        cwd=FLUTTER_APP_DIR,
        optional=True,
        description="Web mode (use instead of flutter)",
    ),
}


class Colors:
    """ANSI color codes for terminal output"""
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"
    WHITE = "\033[97m"
    BOLD = "\033[1m"
    RESET = "\033[0m"


def colored(text: str, color: str) -> str:
    return f"{color}{text}{Colors.RESET}"


def print_header():
    """Print the server manager header"""
    print()
    print(colored("=" * 50, Colors.CYAN))
    print(colored("       EriUI Server Manager", Colors.BOLD + Colors.CYAN))
    print(colored("=" * 50, Colors.CYAN))
    print()


def ensure_dirs():
    """Ensure PID and log directories exist"""
    PID_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)


def is_port_in_use(port: int) -> bool:
    """Check if a port is in use"""
    if port == 0:
        return False
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0


def get_pid_from_file(service: Service) -> Optional[int]:
    """Get PID from pid file"""
    if service.pid_file and service.pid_file.exists():
        try:
            return int(service.pid_file.read_text().strip())
        except (ValueError, IOError):
            return None
    return None


def is_process_running(pid: int) -> bool:
    """Check if a process with given PID is running"""
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def get_service_status(service: Service) -> dict:
    """Get the status of a service"""
    pid = get_pid_from_file(service)
    pid_running = pid is not None and is_process_running(pid)
    port_active = is_port_in_use(service.port) if service.port > 0 else None

    # Determine overall status
    if pid_running and (port_active or service.port == 0):
        status = "running"
    elif port_active:
        status = "running (external)"  # Port is active but not our PID
    elif pid_running:
        status = "starting"  # PID exists but port not ready
    else:
        status = "stopped"

    return {
        "name": service.name,
        "status": status,
        "pid": pid,
        "port": service.port if service.port > 0 else None,
        "port_active": port_active,
    }


def print_status_table():
    """Print status of all services in a table format"""
    print(colored("Service Status:", Colors.BOLD))
    print("-" * 70)
    print(f"{'Service':<15} {'Status':<20} {'PID':<10} {'Port':<10} {'Note':<15}")
    print("-" * 70)

    for name, service in SERVICES.items():
        status = get_service_status(service)

        # Color code the status
        if status["status"] == "running":
            status_str = colored("RUNNING", Colors.GREEN)
        elif status["status"] == "running (external)":
            status_str = colored("RUNNING (ext)", Colors.YELLOW)
        elif status["status"] == "starting":
            status_str = colored("STARTING", Colors.YELLOW)
        else:
            status_str = colored("STOPPED", Colors.RED)

        pid_str = str(status["pid"]) if status["pid"] else "-"
        port_str = str(status["port"]) if status["port"] else "-"
        note_str = "(optional)" if service.optional else ""

        print(f"{name:<15} {status_str:<29} {pid_str:<10} {port_str:<10} {note_str:<15}")

    print("-" * 70)
    print()


def start_service(service: Service, wait_for_port: bool = True) -> bool:
    """Start a single service"""
    status = get_service_status(service)

    if status["status"] in ["running", "running (external)"]:
        print(colored(f"  {service.name}: Already running", Colors.YELLOW))
        return True

    print(colored(f"  Starting {service.name}...", Colors.CYAN), end=" ", flush=True)

    # Check if directory exists
    if not service.cwd.exists():
        print(colored(f"FAILED (directory not found: {service.cwd})", Colors.RED))
        return False

    # Build the command
    if service.env_setup:
        cmd = f"cd {service.cwd} && . {service.cwd}/venv/bin/activate && {' '.join(service.start_cmd)}"
        shell = True
    else:
        cmd = service.start_cmd
        shell = False

    try:
        # Open log file
        log_file = open(service.log_file, "w")

        if shell:
            proc = subprocess.Popen(
                cmd,
                shell=True,
                cwd=service.cwd,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                preexec_fn=os.setsid,
            )
        else:
            proc = subprocess.Popen(
                cmd,
                cwd=service.cwd,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                preexec_fn=os.setsid,
            )

        # Save PID
        service.pid_file.write_text(str(proc.pid))

        # Wait for port to be ready (if applicable)
        if wait_for_port and service.port > 0:
            for _ in range(30):  # Wait up to 30 seconds
                time.sleep(1)
                if is_port_in_use(service.port):
                    print(colored("OK", Colors.GREEN))
                    return True
                # Check if process died
                if proc.poll() is not None:
                    print(colored("FAILED (process exited)", Colors.RED))
                    return False
            print(colored("TIMEOUT", Colors.YELLOW))
            return True  # Process is running but port not ready yet
        else:
            time.sleep(1)  # Brief wait for Flutter
            if proc.poll() is None:
                print(colored("OK", Colors.GREEN))
                return True
            else:
                print(colored("FAILED", Colors.RED))
                return False

    except Exception as e:
        print(colored(f"FAILED ({e})", Colors.RED))
        return False


def stop_service(service: Service) -> bool:
    """Stop a single service"""
    status = get_service_status(service)

    if status["status"] == "stopped":
        print(colored(f"  {service.name}: Already stopped", Colors.YELLOW))
        return True

    print(colored(f"  Stopping {service.name}...", Colors.CYAN), end=" ", flush=True)

    pid = status["pid"]
    if pid:
        try:
            # Kill the process group
            os.killpg(os.getpgid(pid), signal.SIGTERM)
            time.sleep(1)

            # Force kill if still running
            if is_process_running(pid):
                os.killpg(os.getpgid(pid), signal.SIGKILL)
                time.sleep(0.5)

            # Clean up PID file
            if service.pid_file.exists():
                service.pid_file.unlink()

            print(colored("OK", Colors.GREEN))
            return True
        except ProcessLookupError:
            # Process already gone
            if service.pid_file.exists():
                service.pid_file.unlink()
            print(colored("OK (already gone)", Colors.GREEN))
            return True
        except Exception as e:
            print(colored(f"FAILED ({e})", Colors.RED))
            return False
    else:
        print(colored("FAILED (no PID)", Colors.RED))
        return False


def start_all(web_mode: bool = False):
    """Start all services in order

    Args:
        web_mode: If True, starts CORS server and flutter-web instead of flutter desktop
    """
    mode_str = "WEB" if web_mode else "DESKTOP"
    print(colored(f"\nStarting all services ({mode_str} mode)...\n", Colors.BOLD))
    ensure_dirs()

    if web_mode:
        # Web mode: cors + comfyui + onetrainer + flutter-web
        order = ["cors", "comfyui", "onetrainer", "flutter-web"]
    else:
        # Desktop mode: comfyui + onetrainer + flutter (no CORS needed)
        order = ["comfyui", "onetrainer", "flutter"]

    for name in order:
        if name in SERVICES:
            start_service(SERVICES[name])

    print()
    print_status_table()


def stop_all():
    """Stop all services (both desktop and web)"""
    print(colored("\nStopping all services...\n", Colors.BOLD))

    # Stop in reverse order (includes both flutter variants)
    order = ["flutter", "flutter-web", "onetrainer", "comfyui", "cors"]

    for name in order:
        if name in SERVICES:
            status = get_service_status(SERVICES[name])
            if status["status"] != "stopped":
                stop_service(SERVICES[name])

    # Also clean up any lock files
    lock_file = Path("/home/alex/Documents/eriui_storage.lock")
    if lock_file.exists():
        lock_file.unlink()
        print(colored("  Cleaned up storage lock file", Colors.CYAN))

    print()
    print_status_table()


def restart_all(web_mode: bool = False):
    """Restart all services"""
    stop_all()
    time.sleep(2)
    start_all(web_mode=web_mode)


def show_logs(service_name: str, lines: int = 50):
    """Show recent logs for a service"""
    if service_name not in SERVICES:
        print(colored(f"Unknown service: {service_name}", Colors.RED))
        return

    service = SERVICES[service_name]
    if service.log_file and service.log_file.exists():
        print(colored(f"\nLast {lines} lines of {service_name} logs:\n", Colors.BOLD))
        print("-" * 60)
        try:
            with open(service.log_file, "r") as f:
                log_lines = f.readlines()
                for line in log_lines[-lines:]:
                    print(line.rstrip())
        except Exception as e:
            print(colored(f"Error reading logs: {e}", Colors.RED))
        print("-" * 60)
    else:
        print(colored(f"No logs found for {service_name}", Colors.YELLOW))


def interactive_menu():
    """Show interactive menu"""
    while True:
        print_header()
        print_status_table()

        print("Commands:")
        print(colored("  1", Colors.CYAN) + " - Start all services")
        print(colored("  2", Colors.CYAN) + " - Stop all services")
        print(colored("  3", Colors.CYAN) + " - Restart all services")
        print(colored("  4", Colors.CYAN) + " - Start individual service")
        print(colored("  5", Colors.CYAN) + " - Stop individual service")
        print(colored("  6", Colors.CYAN) + " - View logs")
        print(colored("  7", Colors.CYAN) + " - Refresh status")
        print(colored("  q", Colors.CYAN) + " - Quit")
        print()

        choice = input(colored("Enter choice: ", Colors.BOLD)).strip().lower()

        if choice == "1":
            start_all()
            input("\nPress Enter to continue...")
        elif choice == "2":
            stop_all()
            input("\nPress Enter to continue...")
        elif choice == "3":
            restart_all()
            input("\nPress Enter to continue...")
        elif choice == "4":
            print("\nServices:", ", ".join(SERVICES.keys()))
            name = input("Enter service name: ").strip()
            if name in SERVICES:
                ensure_dirs()
                start_service(SERVICES[name])
            else:
                print(colored(f"Unknown service: {name}", Colors.RED))
            input("\nPress Enter to continue...")
        elif choice == "5":
            print("\nServices:", ", ".join(SERVICES.keys()))
            name = input("Enter service name: ").strip()
            if name in SERVICES:
                stop_service(SERVICES[name])
            else:
                print(colored(f"Unknown service: {name}", Colors.RED))
            input("\nPress Enter to continue...")
        elif choice == "6":
            print("\nServices:", ", ".join(SERVICES.keys()))
            name = input("Enter service name: ").strip()
            show_logs(name)
            input("\nPress Enter to continue...")
        elif choice == "7":
            continue  # Just refresh
        elif choice == "q":
            print(colored("\nGoodbye!\n", Colors.CYAN))
            break
        else:
            print(colored("Invalid choice", Colors.RED))
            time.sleep(1)


def main():
    """Main entry point"""
    ensure_dirs()

    if len(sys.argv) > 1:
        cmd = sys.argv[1].lower()
        web_mode = "--web" in sys.argv or "-w" in sys.argv

        if cmd == "start":
            start_all(web_mode=web_mode)
        elif cmd == "stop":
            stop_all()
        elif cmd == "restart":
            restart_all(web_mode=web_mode)
        elif cmd == "status":
            print_header()
            print_status_table()
        elif cmd == "logs" and len(sys.argv) > 2:
            show_logs(sys.argv[2])
        else:
            print(__doc__)
            print("\nFlags:")
            print("  --web, -w    Start in web mode (includes CORS server)")
    else:
        interactive_menu()


if __name__ == "__main__":
    main()
