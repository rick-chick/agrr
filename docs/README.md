# AGRR - Rails 8 + SQLite + S3 + App Runner

**A modern, cost-effective Rails application with production-ready SQLite and AWS deployment**

PostgreSQL and Redis free! A Rails application that can handle production workloads with just SQLite and Docker.

## 🚀 Quick Start (2025 Recommended)

### Recommended Method 1: GitHub Codespaces ⭐ (Easiest)

```bash
# On GitHub repository page:
Code → Codespaces → Create codespace on main

# Automatically launches development environment in browser
# Immediately executable in terminal:
bundle exec rails test
rails server
```

**Benefits:**
- Zero installation required
- Accessible from any OS
- 60 hours free per month
- All dependencies automatically set up

### Recommended Method 2: Dev Containers (VS Code)

**Requirements:**
- Docker Desktop
- Visual Studio Code
- Dev Containers extension

**Steps:**
```
1. Open project in VSCode
2. F1 → "Dev Containers: Reopen in Container"
3. Container automatically builds and starts
```

### Recommended Method 3: Docker Compose

```bash
# Start server
docker-compose up

# Run tests
docker-compose exec web bundle exec rails test

# Console
docker-compose exec web rails console
```

## 📊 Technology Stack

### Framework & Language
- **Ruby 3.3.x** - Latest stable version
- **Rails 8.0.x** - Latest Rails framework

### Database & Storage
- **SQLite 3.x** - Used across all environments
- **Solid Queue** - SQLite-based background jobs
- **Solid Cache** - SQLite-based cache
- **Solid Cable** - SQLite-based Action Cable (WebSocket)
- **Active Storage + S3** - File storage

### Infrastructure
- **Docker** - Containerization
- **AWS App Runner** - Serverless deployment
- **Amazon S3** - File storage
- **Amazon EFS** - Persistent storage for SQLite

## 💰 Cost Efficiency

Compared to traditional PostgreSQL + Redis setup, achieves $30-80/month savings:
- **RDS PostgreSQL** → **SQLite**: $15-50/month savings
- **ElastiCache Redis** → **Solid Queue/Cache**: $15-30/month savings

Actual monthly cost: **$2.45-6.30**

## 🧪 Running Tests

### In Dev Containers / Codespaces

```bash
# Run all tests
bundle exec rails test

# Run specific test
bundle exec rails test test/controllers/api/v1/base_controller_test.rb

# Parallel execution (faster)
bundle exec rails test -j

# With coverage
COVERAGE=true bundle exec rails test
```

### Local (with Docker)

```bash
# Run tests
docker-compose exec web bundle exec rails test

# Or use script
chmod +x scripts/test-docker.sh
./scripts/test-docker.sh
```

### CI/CD (GitHub Actions)

```bash
# Automatically runs on push
git add .
git commit -m "Add tests"
git push origin main

# Check results in GitHub Actions tab
```

## 📁 Project Structure

```
.
├── .devcontainer/              # Dev Containers setup ⭐
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── README.md
├── .github/
│   └── workflows/
│       └── test.yml            # GitHub Actions CI/CD ⭐
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   └── models/
├── config/
│   ├── environments/
│   │   ├── development.rb
│   │   ├── test.rb
│   │   ├── aws_test.rb
│   │   └── production.rb
│   ├── database.yml            # SQLite configuration
│   └── storage.yml             # S3 configuration
├── docs/                       # Documentation ⭐
│   ├── README.ja.md            # Japanese documentation
│   ├── TEST_GUIDE.md           # Detailed test guide
│   └── AWS_DEPLOY.md           # AWS deployment guide
├── scripts/                    # Deployment scripts ⭐
│   ├── aws-deploy.sh           # AWS CLI deployment
│   └── setup-aws-resources.sh  # AWS resource setup
├── test/                       # Minitest tests ⭐
│   ├── controllers/
│   ├── integration/
│   ├── system/
│   └── test_helper.rb
├── docker-compose.yml          # Docker Compose configuration
├── Dockerfile                  # Development Dockerfile
├── Dockerfile.production       # Production Dockerfile
├── apprunner.yaml              # AWS App Runner configuration
├── apprunner-test.yaml         # AWS test environment configuration
└── README.ja.md                # This file (Japanese)
```

## 🏗 Environment Configuration

| Environment | Purpose | Database | File Storage | Recommended Access |
|-------------|---------|----------|--------------|-------------------|
| **development** | Local development | SQLite | Local disk | Dev Containers |
| **test** | Testing | SQLite | Temporary disk | GitHub Actions |
| **docker** | Docker development | SQLite | Docker Volume | docker-compose |
| **aws_test** | AWS testing | SQLite + EFS | S3 | App Runner |
| **production** | AWS production | SQLite + EFS | S3 | App Runner |

## 🌐 API Endpoints

### Health Check

```bash
GET /api/v1/health

# Response example
{
  "status": "ok",
  "timestamp": "2025-01-01T00:00:00Z",
  "environment": "development",
  "database_connected": true,
  "storage": "local"
}
```

### File Management

```
GET    /api/v1/files          # List files
GET    /api/v1/files/:id      # File details
POST   /api/v1/files          # Upload file
DELETE /api/v1/files/:id      # Delete file
```

## ☁️ AWS Deployment

### Required AWS Resources

1. **S3 Bucket** - For file storage
2. **App Runner Service** - Application execution
3. **EFS (Elastic File System)** - SQLite database persistence

### Deployment Steps

For detailed instructions, see **[AWS_DEPLOY.md](AWS_DEPLOY.md)**.

## 📚 Documentation

- **[README.ja.md](README.ja.md)** - Japanese documentation (detailed)
- **[TEST_GUIDE.md](TEST_GUIDE.md)** - Detailed test guide
- **[AWS_DEPLOY.md](AWS_DEPLOY.md)** - AWS CLI deployment guide
- **[.devcontainer/README.md](.devcontainer/README.md)** - Dev Containers guide

## 🔧 Troubleshooting

### Dev Containers won't start

```bash
# Check Docker Desktop is running
# Verify VSCode Dev Containers extension is installed
# F1 → "Dev Containers: Rebuild Container"
```

### Tests failing

```bash
# Reset database
rails db:reset

# Reinstall dependencies
bundle install

# Setup Solid Queue/Cache
rails solid_queue:install
rails solid_cache:install
rails db:migrate
```

### Docker Compose errors

```bash
# Remove containers and volumes, rebuild
docker-compose down -v
docker-compose build --no-cache
docker-compose up
```

## 💡 Best Practices

### Development Flow (2025 Recommended)

1. **Develop with GitHub Codespaces or Dev Containers** ⭐
   - Ensures environment consistency
   - No setup required
   
2. **Write tests before committing**
   ```bash
   bundle exec rails test
   ```

3. **Automatic CI/CD after push**
   - GitHub Actions automatically runs
   - Auto-deploy after tests pass (if configured)

### Why This Architecture?

1. **No MSYS2 required** - Avoids native build issues on Windows
2. **Environment consistency** - All developers use same container environment
3. **Cloud-native** - Develop anywhere with GitHub Codespaces
4. **CI/CD integration** - Automatic testing and deployment with GitHub Actions
5. **Cost efficiency** - SQLite-based, no external services required

## 🤝 Contributing

Pull requests welcome!

1. Fork the repository
2. Open with GitHub Codespaces (recommended)
3. Create feature branch
4. Write tests
5. Create Pull Request

## 📄 License

MIT License

---

**Experience modern Rails development in 2025!** 🚀

