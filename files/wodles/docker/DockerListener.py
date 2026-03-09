import os
import sys
import json
import time
import threading
import logging
from datetime import datetime

# Configure logging for the listener itself
LOG_DIR = "C:\\Program Files (x86)\\ossec-agent\\logs"
LOG_FILE = os.path.join(LOG_DIR, "docker_listener.log")
DOCKER_EVENTS_LOG = os.path.join(LOG_DIR, "docker_events.log")

# Ensure log directory exists
if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR)

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s [DockerListener] %(levelname)s: %(message)s'
)

try:
    import docker
except ImportError:
    logging.error("'docker' module not found. Install with 'pip install docker'.")
    sys.exit(1)

class WindowsDockerListener:
    def __init__(self):
        self.client = None
        self.log_threads = {}  # container_id -> thread
        self.stop_event = threading.Event()
        self.lock = threading.Lock()
        
        # Capture logs only if CAPTURE_DOCKER_LOGS is set to "True"
        self.capture_logs = os.environ.get("CAPTURE_DOCKER_LOGS", "False").lower() == "true"
        if self.capture_logs:
            logging.info("Container log streaming is ENABLED.")
        else:
            logging.info("Container log streaming is DISABLED (only events will be captured).")

    def connect(self):
        """Connect to Docker Engine using Named Pipes on Windows."""
        while not self.stop_event.is_set():
            try:
                # On Windows, docker.from_env() automatically picks up npipe:////./pipe/docker_engine
                self.client = docker.from_env()
                self.client.ping()
                logging.info("Successfully connected to Docker Engine.")
                return True
            except Exception as e:
                logging.warning(f"Waiting for Docker Engine... Error: {e}")
                time.sleep(5)
        return False

    def write_output(self, data, data_type="event"):
        """Write structured data to the log file for Wazuh with official prefix."""
        try:
            # Prepend Wazuh-Docker: prefix and nest under 'docker' key
            # This ensures JSON_Decoder produces fields like 'docker.status' exactly as rules expect
            # Ensure 'status' field is present for compatibility with Wazuh rules
            # Modern Docker APIs use 'Action', but many rules expect 'status'
            if 'Action' in data and 'status' not in data:
                data['status'] = data['Action']

            wazuh_payload = {
                'integration': 'docker',
                'docker': data
            }
            with open(DOCKER_EVENTS_LOG, "a", encoding="utf-8") as f:
                f.write(f"{json.dumps(wazuh_payload)}\n")
        except Exception as e:
            logging.error(f"Failed to write {data_type}: {e}")

    def stream_container_logs(self, container):
        """Thread function to stream logs from a specific container."""
        container_id = container.id[:12]
        container_name = container.name
        logging.info(f"Started log streaming for container {container_name} ({container_id})")
        
        try:
            for line in container.logs(stream=True, follow=True, timestamps=True):
                if self.stop_event.is_set():
                    break
                
                log_entry = {
                    'container_id': container_id,
                    'container_name': container_name,
                    'log': line.decode('utf-8').strip()
                }
                self.write_output(log_entry, data_type="log")
        except Exception as e:
            logging.error(f"Error streaming logs for {container_name}: {e}")
        finally:
            with self.lock:
                if container_id in self.log_threads:
                    del self.log_threads[container_id]
            logging.info(f"Stopped log streaming for container {container_name}")

    def start_log_thread(self, container):
        """Spawn a new thread for container log streaming if not already running."""
        with self.lock:
            if container.id[:12] not in self.log_threads:
                t = threading.Thread(target=self.stream_container_logs, args=(container,), daemon=True)
                self.log_threads[container.id[:12]] = t
                t.start()

    def sync_existing_containers(self):
        """Start log streaming for all currently running containers if enabled."""
        if not self.capture_logs:
            return
            
        try:
            running_containers = self.client.containers.list()
            for container in running_containers:
                self.start_log_thread(container)
        except Exception as e:
            logging.error(f"Failed to sync existing containers: {e}")

    def listen_events(self):
        """Main loop: Listen for Docker events and manage log threads."""
        while not self.stop_event.is_set():
            if not self.connect():
                break
                
            self.sync_existing_containers()
            
            try:
                logging.info("Starting event stream...")
                for event in self.client.events(decode=True):
                    if self.stop_event.is_set():
                        break
                    
                    # Record the event
                    self.write_output(event, data_type="event")
                    
                    if self.capture_logs:
                        status = event.get('status')
                        if status == 'start':
                            container_id = event.get('id')
                            try:
                                container = self.client.containers.get(container_id)
                                self.start_log_thread(container)
                            except Exception as e:
                                logging.error(f"Could not find container {container_id} for logging: {e}")
                            
            except Exception as e:
                logging.error(f"Main stream interrupted: {e}")
                time.sleep(2)

    def run(self):
        logging.info("Wazuh Docker Listener (Events + Logs) for Windows started.")
        self.listen_events()

if __name__ == "__main__":
    listener = WindowsDockerListener()
    try:
        listener.run()
    except KeyboardInterrupt:
        logging.info("Manual stop requested.")
        listener.stop_event.set()
        sys.exit(0)
    except Exception as e:
        logging.critical(f"Unhandled exception: {e}")
        sys.exit(1)
