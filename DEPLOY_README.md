# n8n Docker Deployment Guide

This guide explains how to use the `deploy.sh` script to deploy n8n in Docker with PostgreSQL, Nginx reverse proxy, and Let's Encrypt SSL/TLS.

## Prerequisites

Before running the deployment script, ensure you have:

1. **Docker installed** - [Install Docker](https://docs.docker.com/install/)
2. **Nginx installed** - `sudo apt-get install nginx` (Ubuntu/Debian)
3. **A domain name** - pointing to your server's IP address
4. **Root or sudo access** - the script requires elevated privileges
5. **Open ports** - 80 (HTTP) and 443 (HTTPS) accessible from the internet

### Firewall Setup (UFW)

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

## Quick Start

### 1. Basic Deployment (Interactive)

```bash
sudo ./deploy.sh
```

The script will prompt you for configuration details or use defaults.

### 2. Custom Configuration

```bash
sudo ./deploy.sh [DOMAIN] [CONTAINER_NAME] [PORT] [DB_PASSWORD] [ADMIN_EMAIL]
```

**Example:**
```bash
sudo ./deploy.sh n8n.example.com n8n 5678 your-secure-password admin@example.com
```

**Parameters:**
- `DOMAIN` - Your domain name (e.g., `n8n.example.com`)
- `CONTAINER_NAME` - Docker container name (default: `n8n`)
- `PORT` - Internal n8n port (default: `5678`)
- `DB_PASSWORD` - PostgreSQL password (auto-generated if not provided)
- `ADMIN_EMAIL` - Email for Let's Encrypt notifications

## What the Script Does

1. **Pre-flight Checks**
   - Verifies Docker is installed and running
   - Checks Nginx installation
   - Installs Certbot if needed

2. **Directory Setup**
   - Creates data directories for n8n and PostgreSQL
   - Sets appropriate permissions

3. **PostgreSQL Database**
   - Launches PostgreSQL container
   - Configures database for n8n

4. **n8n Container**
   - Runs n8n with environment variables
   - Configures HTTPS and secure cookies
   - Connects to PostgreSQL

5. **Nginx Reverse Proxy**
   - Creates Nginx configuration for domain routing
   - Sets up HTTP → HTTPS redirect
   - Configures WebSocket support
   - Adds security headers

6. **SSL/TLS Setup**
   - Obtains free certificate from Let's Encrypt
   - Configures HTTPS on port 443
   - Sets up automatic renewal

7. **Management Script**
   - Creates `manage-n8n.sh` for easy container management
   - Includes status, logs, restart, backup commands

## After Deployment

### Access n8n

Open your browser and navigate to:
```
https://your-domain.com
```

You'll see the n8n setup wizard where you can create your admin account.

### Manage n8n

Use the management script created by the deployment:

```bash
# View status
./manage-n8n.sh status

# View logs
./manage-n8n.sh logs

# Restart n8n
./manage-n8n.sh restart

# Stop n8n
./manage-n8n.sh stop

# Start n8n
./manage-n8n.sh start

# Backup data
./manage-n8n.sh backup
```

### View Logs

```bash
# n8n logs
docker logs -f n8n

# PostgreSQL logs
docker logs -f n8n-postgres

# Nginx access logs
tail -f /var/log/nginx/n8n_access.log

# Nginx error logs
tail -f /var/log/nginx/n8n_error.log
```

## Configuration Details

### Environment Variables

The script sets these n8n environment variables:

```bash
DB_TYPE=postgresdb              # Database type
DB_POSTGRESDB_HOST=n8n-postgres # Database host
DB_POSTGRESDB_DATABASE=n8n      # Database name
N8N_PROTOCOL=https              # Use HTTPS
N8N_HOST=your-domain.com        # Domain name
N8N_SECURE_COOKIE=true          # Secure cookies only
WEBHOOK_URL=https://...         # Webhook endpoint
EXECUTION_MODE=regular          # Execution mode
```

### Nginx Configuration

The script creates `/etc/nginx/sites-available/n8n` with:

- SSL/TLS on port 443
- HTTP → HTTPS redirect on port 80
- Security headers (HSTS, X-Frame-Options, etc.)
- WebSocket support for real-time features
- 50MB upload size limit
- Long timeout for heavy workflows

### Data Persistence

Data is stored in directories relative to the script location:

```
./n8n-data/          # n8n workflows, credentials, settings
./postgres-data/     # PostgreSQL database files
```

These persist even if containers are restarted.

## Troubleshooting

### Certificate Issues

If Let's Encrypt validation fails:

```bash
# Check Nginx is running
sudo systemctl status nginx

# Verify domain DNS points to server IP
nslookup your-domain.com

# Check Nginx logs
sudo tail -f /var/log/nginx/n8n_error.log

# Manual certificate request
sudo certbot certonly --webroot -w /var/www/certbot -d your-domain.com
```

### n8n Container Won't Start

```bash
# View logs
docker logs n8n

# Check if port 5678 is available
sudo netstat -tlnp | grep 5678

# Check database connection
docker logs n8n-postgres
```

### Nginx Won't Reload

```bash
# Test configuration
sudo nginx -t

# View error logs
sudo tail -f /var/log/nginx/error.log

# Restart Nginx
sudo systemctl restart nginx
```

### Certificate Renewal Issues

```bash
# Check if certbot is installed
which certbot

# Manual renewal
sudo certbot renew

# Dry run (test without making changes)
sudo certbot renew --dry-run

# View renewal cron job
sudo crontab -l
```

## Updating n8n

To update n8n to the latest version:

```bash
# Pull latest image
docker pull n8n:latest

# Restart container
./manage-n8n.sh restart
```

## Backup and Restore

### Create Backup

```bash
# Manual backup
./manage-n8n.sh backup

# This creates a timestamped tar.gz file with all data
```

### Restore Backup

```bash
# Stop containers
docker stop n8n n8n-postgres

# Extract backup
tar -xzf n8n-backup-YYYYMMDD-HHMMSS.tar.gz

# Start containers
docker start n8n n8n-postgres
```

## Security Best Practices

1. **Use strong database password** - Provided during deployment
2. **Keep Docker updated** - `docker pull n8n:latest`
3. **Monitor SSL certificates** - Auto-renews but check `/var/log/letsencrypt`
4. **Regular backups** - Use `./manage-n8n.sh backup` weekly
5. **Firewall rules** - Only expose ports 80, 443, and 22
6. **Monitor logs** - Check error logs regularly

## Uninstall/Cleanup

To remove n8n completely:

```bash
# Stop and remove containers
docker stop n8n n8n-postgres
docker rm n8n n8n-postgres

# Remove data (WARNING: irreversible)
rm -rf n8n-data postgres-data

# Remove Nginx configuration
sudo rm /etc/nginx/sites-enabled/n8n /etc/nginx/sites-available/n8n
sudo systemctl reload nginx

# Remove SSL certificate (optional)
sudo certbot delete --cert-name your-domain.com
```

## Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Docker Hub](https://hub.docker.com/r/n8n/n8n)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## Support

For issues or questions:

1. Check the DEPLOYMENT_INFO.txt file created after deployment
2. Review logs: `docker logs -f n8n`
3. Visit [n8n Community](https://community.n8n.io/)
4. Check [n8n GitHub Issues](https://github.com/n8n-io/n8n/issues)
