import paramiko
import time
import os
import sys

# Configuration
SFTP_HOST = 'miamipanel.tlsservers.com'
SFTP_PORT = 2022
SFTP_USER = 'synarxis.24a47892'
SFTP_PASS = 'YOUR_PANEL_PASSWORD' # User will need to change this

REMOTE_LOG_PATH = '/storage/t6/logs/games_mp.log'
LOCAL_LOG_PATH = '/home/iw4madmin/games_mp.log'

POLL_INTERVAL = 2.0  # seconds

def sync_log():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    last_size = 0

    while True:
        try:
            print(f"Connecting to {SFTP_HOST}:{SFTP_PORT} as {SFTP_USER}...")
            client.connect(SFTP_HOST, port=SFTP_PORT, username=SFTP_USER, password=SFTP_PASS, timeout=10)
            sftp = client.open_sftp()
            print("Connected successfully. Monitoring log file...")

            # Ensure local file exists
            if not os.path.exists(LOCAL_LOG_PATH):
                with open(LOCAL_LOG_PATH, 'w') as f:
                    pass

            while True:
                try:
                    stat = sftp.stat(REMOTE_LOG_PATH)
                    current_size = stat.st_size

                    if current_size < last_size:
                        # File was rotated/cleared
                        last_size = 0
                    
                    if current_size > last_size:
                        # New data available!
                        with sftp.file(REMOTE_LOG_PATH, 'r') as remote_file:
                            remote_file.seek(last_size)
                            new_data = remote_file.read(current_size - last_size)
                            
                        if new_data:
                            with open(LOCAL_LOG_PATH, 'ab') as local_file:
                                local_file.write(new_data)
                            last_size = current_size

                    time.sleep(POLL_INTERVAL)
                except FileNotFoundError:
                    # Log file doesn't exist yet on the server
                    time.sleep(POLL_INTERVAL)
                except IOError as e:
                    print(f"SFTP IO Error: {e}")
                    break # Break inner loop to reconnect

        except Exception as e:
            print(f"Connection error: {e}. Retrying in 5 seconds...")
            time.sleep(5)
        finally:
            try:
                client.close()
            except:
                pass

if __name__ == '__main__':
    if SFTP_PASS == 'YOUR_PANEL_PASSWORD':
        print("Please edit this script and set your SFTP_PASS!")
        sys.exit(1)
    
    sync_log()
