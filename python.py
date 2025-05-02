import struct
import time

# The path to the wtmp file
WTMP_PATH = "/var/log/wtmp"

# Function to create a fake lastlog entry
def create_fake_entry(username, login_time):
    # wtmp format structure: [ut_user, ut_id, ut_line, ut_pid, ut_type, ut_time, ut_host, ut_exit]
    # ut_time is the login time in seconds since epoch (Unix time)
    ut_type = 7  # User login (UT_TYPE_LOGIN)
    ut_pid = 0
    ut_id = b" " * 4  # empty ut_id
    ut_line = b"pts/0"  # Terminal type, e.g., pts/0 for virtual terminals
    ut_host = b"localhost"  # Hostname, replace with real one if needed
    ut_exit = 0  # Exit status
    ut_user = username.encode('utf-8').ljust(32, b'\x00')  # 32-byte username
    ut_time = int(login_time)  # Login time in seconds since epoch

    # Struct format for the entry
    wtmp_format = "32s4s32sIIBI32sI"
    
    # Pack the entry
    packed_entry = struct.pack(wtmp_format, ut_user, ut_id, ut_line.encode('utf-8'), ut_pid, ut_type, ut_time, ut_host, ut_exit)

    return packed_entry

# Function to update wtmp
def update_wtmp(fake_entries):
    with open(WTMP_PATH, 'r+b') as f:
        # Go to the end of the file
        f.seek(0, 2)
        for entry in fake_entries:
            f.write(entry)

# Define your usernames and their fake last login timestamps
fake_logins = [
    ("user1", time.time() - 70 * 86400),  # 70 days ago
    ("user2", time.time() - 80 * 86400),  # 80 days ago
    ("user3", time.time() - 90 * 86400),  # 90 days ago
    ("user4", time.time() - 30 * 86400),  # 30 days ago
    ("user5", time.time() - 20 * 86400),  # 20 days ago
    ("user6", time.time() - 10 * 86400),  # 10 days ago
]

# Create fake entries
entries = [create_fake_entry(username, login_time) for username, login_time in fake_logins]

# Update wtmp with fake entries
update_wtmp(entries)

print("Fake lastlog entries have been added to wtmp.")
