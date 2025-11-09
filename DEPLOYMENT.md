# Meteoride Deployment Guide

This guide covers deploying Meteoride MVP to production.

## Prerequisites

- Docker and Docker Compose
- Kubernetes cluster (local or cloud)
- kubectl configured
- WeatherAPI key from [weatherapi.com](https://www.weatherapi.com/)

## Local Development

### Backend

1. Install Rust from [rustup.rs](https://rustup.rs/)

2. Start Redis:
```bash
docker run -d -p 6379:6379 redis:7-alpine
```

3. Configure environment:
```bash
cd backend
cp .env.example .env
# Edit .env and add your WEATHER_API_KEY
```

4. Run backend:
```bash
cargo run
```

Backend will be available at `http://localhost:8080`

### Mobile App

1. Install Flutter from [flutter.dev](https://flutter.dev/)

2. Get dependencies:
```bash
cd mobile
flutter pub get
```

3. Update backend URL in `lib/services/weather_service.dart` if needed

4. Run on device/emulator:
```bash
flutter run
```

### Using Docker Compose

```bash
# Set your API key
export WEATHER_API_KEY=your_key_here

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Kubernetes Deployment

### 1. Prepare Secrets

Edit `backend/k8s/secret.yaml` and replace the base64-encoded API key:

```bash
echo -n "your-weatherapi-key" | base64
```

Update the `WEATHER_API_KEY` value in `secret.yaml`.

### 2. Deploy

Using the deployment script:

```bash
./scripts/deploy.sh
```

Or manually:

```bash
kubectl apply -f backend/k8s/configmap.yaml
kubectl apply -f backend/k8s/secret.yaml
kubectl apply -f backend/k8s/redis.yaml
kubectl apply -f backend/k8s/deployment.yaml
kubectl apply -f backend/k8s/hpa.yaml
```

### 3. Verify Deployment

```bash
# Check pods
kubectl get pods

# Check services
kubectl get services

# View logs
kubectl logs -l app=meteoride-backend

# Port forward to test
kubectl port-forward svc/meteoride-backend 8080:80
```

Test the API:
```bash
curl "http://localhost:8080/health"
curl "http://localhost:8080/v1/ride-safety?lat=52.52&lon=13.405&vehicle=bike"
```

### 4. Expose Service

For production, create an Ingress or LoadBalancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: meteoride-backend-external
spec:
  type: LoadBalancer
  selector:
    app: meteoride-backend
  ports:
  - port: 80
    targetPort: 8080
```

## CI/CD

GitHub Actions workflows are configured for:

- **Backend CI/CD** (`.github/workflows/backend.yml`):
  - Runs tests on every push/PR
  - Builds and pushes Docker image on main branch
  - Includes clippy and formatting checks

- **Mobile CI/CD** (`.github/workflows/mobile.yml`):
  - Runs Flutter analyze and tests
  - Builds Android APK and iOS IPA on main branch
  - Uploads artifacts

### Setup GitHub Secrets

For Docker image publishing, ensure GitHub Packages is enabled.

For deployment to Kubernetes, add these secrets to your GitHub repository:

- `KUBE_CONFIG`: Base64-encoded kubeconfig file
- `WEATHER_API_KEY`: Your WeatherAPI key

## Monitoring

### Health Checks

Backend includes health endpoint:
```bash
curl http://your-backend-url/health
```

### Logs

View backend logs:
```bash
kubectl logs -f deployment/meteoride-backend
```

View Redis logs:
```bash
kubectl logs -f deployment/meteoride-redis
```

### Metrics

The HorizontalPodAutoscaler monitors:
- CPU usage (target: 70%)
- Memory usage (target: 80%)

View HPA status:
```bash
kubectl get hpa
```

## Scaling

### Manual Scaling

```bash
kubectl scale deployment meteoride-backend --replicas=5
```

### Auto-scaling

HPA is configured to scale between 2-10 replicas based on CPU and memory.

## Backup and Recovery

### Redis Data

For production, consider:
- Redis persistence (RDB/AOF)
- Redis backups to object storage
- Redis replication for high availability

### Configuration Backup

Store all K8s manifests in version control (already done).

## Security Best Practices

1. **API Keys**: Never commit API keys. Use Kubernetes Secrets.
2. **Network Policies**: Implement network policies to restrict pod communication.
3. **RBAC**: Configure proper Role-Based Access Control.
4. **TLS**: Use TLS/HTTPS for all external communication.
5. **Image Scanning**: Scan Docker images for vulnerabilities.

## Cost Optimization

1. **Caching**: Aggressive Redis caching reduces API calls (TTL: 15min)
2. **Geohashing**: Groups nearby locations to same cache key
3. **Resource Limits**: Conservative CPU/memory limits
4. **Auto-scaling**: Scales down during low traffic

## Troubleshooting

### Backend won't start

Check environment variables:
```bash
kubectl describe pod -l app=meteoride-backend
```

### Can't connect to Redis

Verify Redis is running:
```bash
kubectl get pods -l app=meteoride-redis
kubectl logs -l app=meteoride-redis
```

### WeatherAPI errors

- Verify API key is correct
- Check API quota/limits
- Review backend logs for specific errors

### High latency

- Check Redis cache hit rate in logs
- Verify network latency to WeatherAPI
- Consider increasing replicas

## Updates and Rollbacks

### Update Backend

```bash
# Update image in deployment.yaml
kubectl set image deployment/meteoride-backend backend=new-image:tag

# Or edit deployment
kubectl edit deployment meteoride-backend
```

### Rollback

```bash
kubectl rollout undo deployment/meteoride-backend
```

## Production Checklist

- [ ] API keys configured as Secrets
- [ ] Resource limits set appropriately
- [ ] Health checks configured
- [ ] Monitoring and alerting set up
- [ ] Backups configured
- [ ] TLS/HTTPS enabled
- [ ] Network policies applied
- [ ] RBAC configured
- [ ] Logging aggregation set up
- [ ] Cost monitoring enabled

## Support

For issues or questions, please open an issue on GitHub.
