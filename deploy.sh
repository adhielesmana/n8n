#!/bin/bash

################################################################################
# n8n Docker Deployment Script
# Deploys n8n in Docker with PostgreSQL, Nginx reverse proxy, and Let's Encrypt SSL
################################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

################################################################################
# Configuration Variables
################################################################################

# Read from user input or use defaults
DOMAIN="${1:-n8n.example.com}"
N8N_CONTAINER_NAME="${2:-n8n}"
N8N_PORT="${3:-5678}"
DB_PASSWORD="${4:-$(openssl rand -base64 32)}"
N8N_ADMIN_EMAIL="${5:-admin@example.com}"
N8N_ENCRYPTION_KEY="${6:-$(openssl rand -base64 32)}"

# Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATA_DIR="${SCRIPT_DIR}/n8n-data"
DB_DIR="${SCRIPT_DIR}/postgres-data"
NGINX_CONFIG_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
CERTBOT_DIR="/etc/letsencrypt"

################################################################################
# Pre-flight Checks
################################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi

    # Check Docker installation
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    log_success "Docker is installed"

    # Check if Nginx is installed
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx is not installed. Please install Nginx first."
        exit 1
    fi
    log_success "Nginx is installed"

    # Check if Certbot is installed
    if ! command -v certbot &> /dev/null; then
        log_warning "Certbot is not installed. Installing Certbot for SSL..."
        apt-get update && apt-get install -y certbot python3-certbot-nginx
    fi
    log_success "Certbot is available"

    # Check if Docker daemon is running
    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    log_success "Docker daemon is running"
}

################################################################################
# Setup Directories and Permissions
################################################################################

setup_directories() {
    log_info "Setting up directories..."

    mkdir -p "$DATA_DIR"
    mkdir -p "$DB_DIR"

    chmod 755 "$DATA_DIR"
    chmod 755 "$DB_DIR"

    log_success "Directories created at $DATA_DIR and $DB_DIR"
}

################################################################################
# Setup PostgreSQL Database
################################################################################

setup_database() {
    log_info "Setting up PostgreSQL database..."

    # Check if PostgreSQL container is already running
    if docker ps | grep -q "n8n-postgres"; then
        log_info "PostgreSQL container already running"
        return 0
    fi

    # Create PostgreSQL container
    docker run \
        -d \
        --name n8n-postgres \
        --restart unless-stopped \
        -e POSTGRES_USER=n8n \
        -e POSTGRES_PASSWORD="$DB_PASSWORD" \
        -e POSTGRES_DB=n8n \
        -v "$DB_DIR:/var/lib/postgresql/data" \
        postgres:15-alpine

    log_success "PostgreSQL container started"

    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    sleep 10
}

################################################################################
# Deploy n8n Docker Container
################################################################################

deploy_n8n() {
    log_info "Deploying n8n container..."

    # Stop and remove existing container if running
    if docker ps -a | grep -q "$N8N_CONTAINER_NAME"; then
        log_info "Removing existing n8n container..."
        docker stop "$N8N_CONTAINER_NAME" 2>/dev/null || true
        docker rm "$N8N_CONTAINER_NAME" 2>/dev/null || true
    fi

    # Start n8n container
    docker run \
        -d \
        --name "$N8N_CONTAINER_NAME" \
        --restart unless-stopped \
        --link n8n-postgres \
        -p 127.0.0.1:${N8N_PORT}:5678 \
        -e DB_TYPE=postgresdb \
        -e DB_POSTGRESDB_HOST=n8n-postgres \
        -e DB_POSTGRESDB_PORT=5432 \
        -e DB_POSTGRESDB_DATABASE=n8n \
        -e DB_POSTGRESDB_USER=n8n \
        -e DB_POSTGRESDB_PASSWORD="$DB_PASSWORD" \
        -e N8N_PROTOCOL=https \
        -e N8N_HOST="$DOMAIN" \
        -e N8N_PORT=443 \
        -e N8N_EDITOR_BASE_URL="https://${DOMAIN}/" \
        -e N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY" \
        -e N8N_SECURE_COOKIE=true \
        -e WEBHOOK_URL="https://${DOMAIN}/webhook/" \
        -e EXECUTION_MODE=regular \
        -v "$DATA_DIR:/home/node/.n8n" \
        n8nio/n8n:latest

    log_success "n8n container started and listening on 127.0.0.1:${N8N_PORT}"

    # Wait for n8n to be ready
    log_info "Waiting for n8n to be ready..."
    sleep 15
}

################################################################################
# Configure Nginx Reverse Proxy
################################################################################

setup_nginx() {
    log_info "Configuring Nginx reverse proxy..."

    # Create Nginx configuration
    cat > "${NGINX_CONFIG_DIR}/n8n" << 'EOF'
# n8n Reverse Proxy Configuration
# Do not modify - auto-generated by deploy.sh

upstream n8n_backend {
    server 127.0.0.1:N8N_PORT;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name N8N_DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Main HTTPS server block
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name N8N_DOMAIN;

    # SSL certificates (to be configured by certbot)
    ssl_certificate /etc/letsencrypt/live/N8N_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/N8N_DOMAIN/privkey.pem;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Logging
    access_log /var/log/nginx/n8n_access.log;
    error_log /var/log/nginx/n8n_error.log;

    # Client upload size limit
    client_max_body_size 50M;

    # Proxy configuration
    location / {
        proxy_pass http://n8n_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "upgrade";
        proxy_set_header Upgrade $http_upgrade;
        proxy_http_version 1.1;

        # Timeouts for long-running processes
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        send_timeout 300;
    }

    # Webhook endpoint
    location /webhook/ {
        proxy_pass http://n8n_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
    }
}
EOF

    # Replace placeholders
    sed -i "s/N8N_DOMAIN/${DOMAIN}/g" "${NGINX_CONFIG_DIR}/n8n"
    sed -i "s/N8N_PORT/${N8N_PORT}/g" "${NGINX_CONFIG_DIR}/n8n"

    # Enable Nginx configuration
    if [ ! -L "${NGINX_ENABLED_DIR}/n8n" ]; then
        ln -s "${NGINX_CONFIG_DIR}/n8n" "${NGINX_ENABLED_DIR}/n8n"
    fi

    # Test Nginx configuration
    if ! nginx -t &> /dev/null; then
        log_error "Nginx configuration test failed"
        exit 1
    fi

    # Reload Nginx
    systemctl reload nginx

    log_success "Nginx reverse proxy configured"
}

################################################################################
# Setup SSL/TLS with Let's Encrypt
################################################################################

setup_ssl() {
    log_info "Setting up SSL/TLS with Let's Encrypt..."

    # Check if certificate already exists
    if [ -f "${CERTBOT_DIR}/live/${DOMAIN}/fullchain.pem" ]; then
        log_info "SSL certificate already exists for $DOMAIN"
        return 0
    fi

    # Create web root for certbot verification
    mkdir -p /var/www/certbot

    # Request certificate
    log_info "Requesting SSL certificate from Let's Encrypt..."
    certbot certonly \
        --webroot \
        -w /var/www/certbot \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --email "$N8N_ADMIN_EMAIL" \
        --no-eff-email

    if [ $? -eq 0 ]; then
        log_success "SSL certificate obtained successfully"

        # Reload Nginx with SSL enabled
        systemctl reload nginx
    else
        log_error "Failed to obtain SSL certificate"
        exit 1
    fi
}

################################################################################
# Setup Certificate Auto-Renewal
################################################################################

setup_cert_renewal() {
    log_info "Setting up automatic certificate renewal..."

    # Add certbot renewal to crontab if not already present
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        # Create a temporary crontab file
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --no-self-upgrade") | crontab -
        log_success "Automatic certificate renewal scheduled"
    else
        log_info "Certificate renewal already scheduled"
    fi
}

################################################################################
# Create Status and Management Script
################################################################################

create_management_script() {
    log_info "Creating management script..."

    cat > "${SCRIPT_DIR}/manage-n8n.sh" << 'MGMT_EOF'
#!/bin/bash

# n8n Management Script

case "$1" in
    status)
        echo "n8n Container Status:"
        docker ps -a | grep -E "n8n|postgres" || echo "No containers found"
        ;;
    logs)
        docker logs -f N8N_CONTAINER_NAME
        ;;
    restart)
        echo "Restarting n8n..."
        docker restart N8N_CONTAINER_NAME
        systemctl reload nginx
        echo "n8n restarted"
        ;;
    stop)
        echo "Stopping n8n..."
        docker stop N8N_CONTAINER_NAME
        echo "n8n stopped"
        ;;
    start)
        echo "Starting n8n..."
        docker start N8N_CONTAINER_NAME
        systemctl reload nginx
        echo "n8n started"
        ;;
    backup)
        echo "Backing up n8n data..."
        tar -czf "n8n-backup-$(date +%Y%m%d-%H%M%S).tar.gz" \
            n8n-data/ \
            postgres-data/ 2>/dev/null || true
        echo "Backup created"
        ;;
    *)
        echo "Usage: $0 {status|logs|restart|stop|start|backup}"
        exit 1
        ;;
esac
MGMT_EOF

    # Replace placeholder
    sed -i "s/N8N_CONTAINER_NAME/${N8N_CONTAINER_NAME}/g" "${SCRIPT_DIR}/manage-n8n.sh"

    chmod +x "${SCRIPT_DIR}/manage-n8n.sh"

    log_success "Management script created at ${SCRIPT_DIR}/manage-n8n.sh"
}

################################################################################
# Create Environment Info File
################################################################################

create_info_file() {
    log_info "Creating deployment info file..."

    cat > "${SCRIPT_DIR}/DEPLOYMENT_INFO.txt" << EOF
================================================================================
n8n Deployment Information
================================================================================

Deployment Date: $(date)
Domain: $DOMAIN
Container Name: $N8N_CONTAINER_NAME
N8N Port (Internal): $N8N_PORT

Database:
- Type: PostgreSQL
- Container: n8n-postgres
- User: n8n
- Password: (securely stored in Docker)

Data Locations:
- N8N Data: $DATA_DIR
- PostgreSQL Data: $DB_DIR

SSL/TLS:
- Provider: Let's Encrypt
- Certificate: /etc/letsencrypt/live/${DOMAIN}/
- Auto-renewal: Enabled (cron job)

Access:
- URL: https://${DOMAIN}
- Admin Email: $N8N_ADMIN_EMAIL

Management:
Run the following command for status and management:
  ${SCRIPT_DIR}/manage-n8n.sh {status|logs|restart|stop|start|backup}

View Logs:
  docker logs -f $N8N_CONTAINER_NAME

View Nginx Logs:
  tail -f /var/log/nginx/n8n_access.log
  tail -f /var/log/nginx/n8n_error.log

Backup:
  ${SCRIPT_DIR}/manage-n8n.sh backup

Firewall (if using ufw):
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw enable

================================================================================
EOF

    log_success "Deployment info saved to ${SCRIPT_DIR}/DEPLOYMENT_INFO.txt"
    cat "${SCRIPT_DIR}/DEPLOYMENT_INFO.txt"
}

################################################################################
# Main Deployment Flow
################################################################################

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║        n8n Docker Deployment with SSL/TLS Setup          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    log_info "Deployment Configuration:"
    echo "  Domain: $DOMAIN"
    echo "  Container: $N8N_CONTAINER_NAME"
    echo "  Port: $N8N_PORT"
    echo "  Admin Email: $N8N_ADMIN_EMAIL"
    echo ""

    # Run deployment steps
    check_prerequisites
    setup_directories
    setup_database
    deploy_n8n
    setup_nginx
    setup_ssl
    setup_cert_renewal
    create_management_script
    create_info_file

    echo ""
    log_success "✓ Deployment completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Visit https://${DOMAIN} in your browser"
    echo "  2. Complete the n8n setup wizard"
    echo "  3. Use '${SCRIPT_DIR}/manage-n8n.sh' for management"
    echo ""
    echo "For help and logs:"
    echo "  docker logs -f $N8N_CONTAINER_NAME"
    echo ""
}

# Handle script interruption
trap 'log_error "Deployment interrupted"; exit 1' INT TERM

# Run main deployment
main "$@"
