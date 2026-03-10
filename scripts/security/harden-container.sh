#!/bin/bash
# MI-SOAR-NGFW Container Security Hardening
# Applies security best practices to Docker containers

set -euo pipefail

# Configuration
LOG_FILE="/var/log/mi-soar-ngfw/security-hardening.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

check_docker_permissions() {
    log "Checking Docker permissions..."
    if docker ps > /dev/null 2>&1; then
        log_success "Docker permissions are properly configured"
    else
        log_error "Unable to run Docker commands. Add user to docker group: sudo usermod -aG docker \$USER"
        exit 1
    fi
}

harden_docker_daemon() {
    log "Hardening Docker daemon configuration..."

    # Backup existing configuration
    if [[ -f /etc/docker/daemon.json ]]; then
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d)
    fi

    # Apply security-hardened configuration
    sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "userns-remap": "default",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "icc": false,
  "experimental": false,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    },
    "nproc": {
      "Name": "nproc",
      "Hard": 1024,
      "Soft": 512
    }
  }
}
EOF

    sudo systemctl restart docker
    log_success "Docker daemon security configuration applied"
}

apply_seccomp_profile() {
    log "Applying seccomp security profile..."

    # Create custom seccomp profile
    sudo tee /etc/docker/seccomp/mi-soar-ngfw-profile.json > /dev/null << EOF
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_X32"
  ],
  "syscalls": [
    {
      "names": [
        "accept",
        "accept4",
        "access",
        "alarm",
        "bind",
        "brk",
        "capget",
        "capset",
        "chdir",
        "chmod",
        "chown",
        "chown32",
        "clock_gettime",
        "clone",
        "close",
        "connect",
        "copy_file_range",
        "creat",
        "dup",
        "dup2",
        "dup3",
        "epoll_create",
        "epoll_create1",
        "epoll_ctl",
        "epoll_pwait",
        "epoll_wait",
        "eventfd",
        "eventfd2",
        "execve",
        "execveat",
        "exit",
        "exit_group",
        "faccessat",
        "fadvise64",
        "fallocate",
        "fanotify_init",
        "fanotify_mark",
        "fchdir",
        "fchmod",
        "fchmodat",
        "fchown",
        "fchown32",
        "fchownat",
        "fcntl",
        "fcntl64",
        "fdatasync",
        "fgetxattr",
        "flistxattr",
        "flock",
        "fork",
        "fremovexattr",
        "fsetxattr",
        "fstat",
        "fstat64",
        "fstatat64",
        "fstatfs",
        "fstatfs64",
        "fsync",
        "ftruncate",
        "ftruncate64",
        "futex",
        "futimesat",
        "getcpu",
        "getcwd",
        "getdents",
        "getdents64",
        "getegid",
        "getegid32",
        "geteuid",
        "geteuid32",
        "getgid",
        "getgid32",
        "getgroups",
        "getgroups32",
        "getitimer",
        "getpeername",
        "getpgid",
        "getpgrp",
        "getpid",
        "getppid",
        "getpriority",
        "getrandom",
        "getresgid",
        "getresgid32",
        "getresuid",
        "getresuid32",
        "getrlimit",
        "getrobustlist",
        "getrusage",
        "getsid",
        "getsockname",
        "getsockopt",
        "gettid",
        "gettimeofday",
        "getuid",
        "getuid32",
        "getxattr",
        "inotify_add_watch",
        "inotify_init",
        "inotify_init1",
        "inotify_rm_watch",
        "ioctl",
        "ioprio_get",
        "ioprio_set",
        "ipc",
        "kill",
        "lchown",
        "lchown32",
        "lgetxattr",
        "link",
        "linkat",
        "listen",
        "listxattr",
        "llistxattr",
        "lremovexattr",
        "lseek",
        "lsetxattr",
        "lstat",
        "lstat64",
        "madvise",
        "memfd_create",
        "mincore",
        "mkdir",
        "mkdirat",
        "mknod",
        "mknodat",
        "mlock",
        "mlock2",
        "mlockall",
        "mmap",
        "mmap2",
        "mprotect",
        "mq_getsetattr",
        "mq_notify",
        "mq_open",
        "mq_timedreceive",
        "mq_timedsend",
        "mq_unlink",
        "mremap",
        "msgctl",
        "msgget",
        "msgrcv",
        "msgsnd",
        "msync",
        "munlock",
        "munlockall",
        "munmap",
        "nanosleep",
        "newfstatat",
        "_newselect",
        "open",
        "openat",
        "pause",
        "pipe",
        "pipe2",
        "poll",
        "ppoll",
        "prctl",
        "pread64",
        "preadv",
        "preadv2",
        "prlimit64",
        "pselect6",
        "pwrite64",
        "pwritev",
        "pwritev2",
        "read",
        "readahead",
        "readlink",
        "readlinkat",
        "readv",
        "recv",
        "recvfrom",
        "recvmmsg",
        "recvmsg",
        "remap_file_pages",
        "removexattr",
        "rename",
        "renameat",
        "renameat2",
        "restart_syscall",
        "rmdir",
        "rt_sigaction",
        "rt_sigpending",
        "rt_sigprocmask",
        "rt_sigqueueinfo",
        "rt_sigreturn",
        "rt_sigsuspend",
        "rt_sigtimedwait",
        "rt_tgsigqueueinfo",
        "sched_getaffinity",
        "sched_getattr",
        "sched_getparam",
        "sched_get_priority_max",
        "sched_get_priority_min",
        "sched_getscheduler",
        "sched_rr_get_interval",
        "sched_setaffinity",
        "sched_setattr",
        "sched_setparam",
        "sched_setscheduler",
        "sched_yield",
        "seccomp",
        "select",
        "semctl",
        "semget",
        "semop",
        "semtimedop",
        "send",
        "sendfile",
        "sendfile64",
        "sendmmsg",
        "sendmsg",
        "sendto",
        "setfsgid",
        "setfsgid32",
        "setfsuid",
        "setfsuid32",
        "setgid",
        "setgid32",
        "setgroups",
        "setgroups32",
        "setitimer",
        "setpgid",
        "setpriority",
        "setregid",
        "setregid32",
        "setresgid",
        "setresgid32",
        "setresuid",
        "setresuid32",
        "setreuid",
        "setreuid32",
        "setrlimit",
        "setsid",
        "setsockopt",
        "set_tid_address",
        "setuid",
        "setuid32",
        "setxattr",
        "shmat",
        "shmctl",
        "shmdt",
        "shmget",
        "shutdown",
        "sigaltstack",
        "signalfd",
        "signalfd4",
        "sigreturn",
        "socket",
        "socketcall",
        "socketpair",
        "splice",
        "stat",
        "stat64",
        "statfs",
        "statfs64",
        "statx",
        "symlink",
        "symlinkat",
        "sync",
        "sync_file_range",
        "sysinfo",
        "tee",
        "tgkill",
        "time",
        "timer_create",
        "timer_delete",
        "timer_getoverrun",
        "timer_gettime",
        "timer_settime",
        "timerfd_create",
        "timerfd_gettime",
        "timerfd_settime",
        "times",
        "tkill",
        "truncate",
        "truncate64",
        "ugetrlimit",
        "umask",
        "uname",
        "unlink",
        "unlinkat",
        "utime",
        "utimensat",
        "utimes",
        "vfork",
        "vmsplice",
        "wait4",
        "waitid",
        "waitpid",
        "write",
        "writev"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

    log_success "Custom seccomp profile created"
}

harden_containers() {
    log "Applying security hardening to MI-SOAR-NGFW containers..."

    # Stop all containers
    docker-compose down

    # Update docker-compose.yml with security enhancements
    log "Updating Docker Compose configuration with security settings..."

    # Create a backup
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d)

    # Note: In a real implementation, we would programmatically update the YAML
    # For now, we'll create a hardened version
    cat > docker-compose.hardened.yml << 'EOF'
# Security-hardened version of docker-compose.yml
# Generated by harden-container.sh

x-security-defaults: &security-defaults
  read_only: true
  security_opt:
    - no-new-privileges:true
    - seccomp:/etc/docker/seccomp/mi-soar-ngfw-profile.json
  cap_drop:
    - ALL
  tmpfs:
    - /tmp
    - /run
    - /var/tmp
  pids_limit: 100
  mem_limit: 1g
  cpus: '1.0'

version: '3.8'

services:
  suricata:
    <<: *security-defaults
    cap_add:
      - NET_RAW
      - NET_ADMIN
      - SYS_NICE
    read_only: false  # Suricata needs to write logs
    volumes:
      - ./storage/logs/suricata:/var/log/suricata

  wireguard:
    <<: *security-defaults
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    read_only: false  # WireGuard needs to write configs
    volumes:
      - ./configs/wireguard:/config

  # Other services with similar patterns...
EOF

    log_warning "Created docker-compose.hardened.yml with security enhancements"
    log_warning "Review and merge changes into your main docker-compose.yml"
}

scan_vulnerabilities() {
    log "Scanning containers for vulnerabilities..."

    if command -v trivy &> /dev/null; then
        # Scan all images
        for service in suricata wireguard wazuh n8n traefik; do
            log "Scanning $service image..."
            trivy image $(docker-compose config | grep "image:" | grep "$service" | awk '{print $2}') || true
        done
    else
        log_warning "Trivy not installed. Install with: sudo apt install trivy"
    fi
}

check_runtime_security() {
    log "Checking runtime security..."

    # Check for running containers as root
    log "Checking for containers running as root..."
    docker ps --format "table {{.Names}}\t{{.ID}}\t{{.Status}}" | while read line; do
        container=$(echo $line | awk '{print $1}')
        if [[ "$container" != "NAMES" ]]; then
            user=$(docker exec "$container" whoami 2>/dev/null || echo "unknown")
            if [[ "$user" == "root" ]]; then
                log_warning "Container $container is running as root"
            fi
        fi
    done

    # Check for exposed ports
    log "Checking for exposed ports..."
    docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -v "NAMES" | while read line; do
        container=$(echo $line | awk '{print $1}')
        ports=$(echo $line | awk '{for(i=2;i<=NF;i++) printf $i" "}')
        if [[ "$ports" != *"->"* ]]; then
            log_success "Container $container has no exposed ports"
        else
            log_warning "Container $container has exposed ports: $ports"
        fi
    done
}

main() {
    log "Starting MI-SOAR-NGFW container security hardening"

    # Check prerequisites
    check_root
    check_docker_permissions

    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"

    # Execute hardening steps
    harden_docker_daemon
    apply_seccomp_profile
    harden_containers
    scan_vulnerabilities
    check_runtime_security

    log_success "Security hardening completed"
    log "Review the generated files and logs:"
    log "  - $LOG_FILE"
    log "  - docker-compose.hardened.yml"
    log "  - /etc/docker/seccomp/mi-soar-ngfw-profile.json"
    log ""
    log "Next steps:"
    log "1. Review docker-compose.hardened.yml and merge changes"
    log "2. Restart containers: docker-compose up -d"
    log "3. Run health checks: ./scripts/monitoring/health-checks.sh"
    log "4. Schedule regular security scans"
}

# Run main function
main "$@"