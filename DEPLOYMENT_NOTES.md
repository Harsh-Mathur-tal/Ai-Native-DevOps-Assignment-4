# Deployment Notes

## Important Configuration Notes

### JWT Secret Configuration

The JWT secret must match between the microservice and Kong for token validation to work correctly.

**Current Configuration:**
- User Service: Uses `JWT_SECRET` environment variable (default: "your-secret-key-change-in-production")
- Kong: Uses the same secret for JWT validation (configured in kong.yaml)

**To Change:**
1. Update `helm/user-service/values.yaml`:
   ```yaml
   env:
     JWT_SECRET: "your-new-secret-key"
   ```

2. Update Kong configuration if using custom JWT validation (currently using Kong's built-in JWT plugin which validates signature format)

### Custom Lua Plugin

**Note:** Kong OSS in DB-less mode (declarative config) has limitations with custom Lua plugins. The plugin code is included in the ConfigMap, but Kong needs to load it properly.

**Options:**
1. **Use Kong Enterprise** (has better plugin support)
2. **Build Custom Kong Image** with plugins baked in
3. **Use Kong Plugin Server** (for external plugins)

For this assignment, the custom Lua plugin code is provided and can be integrated by:
- Building a custom Kong Docker image that includes the plugin
- Or using Kong's plugin loading mechanism if available

**Current Implementation:**
- Plugin code is in `kong/plugins/custom-lua-plugin.lua`
- Schema is in `kong/plugins/schema.lua`
- ConfigMap includes both files
- Kong environment variable `KONG_LUA_PACKAGE_PATH` is set to `/kong/plugins/?.lua;;`

### Database Persistence

SQLite database is stored in a PersistentVolumeClaim. To reset the database:

```bash
# Delete the PVC (will lose all data)
kubectl delete pvc user-service-data -n api-platform

# Redeploy user-service
helm upgrade --install user-service ./helm/user-service -n api-platform
```

### Kong Service Type

For Minikube, Kong service is configured as `NodePort` to allow external access. For production, use `LoadBalancer` or `Ingress`.

### Default Credentials

**Default Admin User:**
- Username: `admin`
- Password: `admin123`

**Change in production!**

### Rate Limiting

Current configuration:
- 10 requests per minute per IP
- 100 requests per hour per IP

To adjust, update `helm/kong/values.yaml`:
```yaml
kongConfig:
  rateLimiting:
    minute: 20  # Change as needed
    hour: 200   # Change as needed
```

### IP Whitelisting

Default allows all IPs (`0.0.0.0/0`). For production, restrict to specific CIDR ranges:

```yaml
kongConfig:
  ipWhitelist:
    allow:
      - "192.168.1.0/24"
      - "10.0.0.0/8"
```

### Troubleshooting

**Kong not loading custom plugins:**
- Check Kong logs: `kubectl logs deployment/kong -n api-platform`
- Verify ConfigMap: `kubectl get configmap kong-plugins -n api-platform -o yaml`
- Check environment variables: `kubectl exec deployment/kong -n api-platform -- env | grep KONG`

**JWT validation failing:**
- Ensure JWT secret matches between services
- Check token expiration (default: 24 hours)
- Verify token format: `Authorization: Bearer <token>`

**Rate limiting not working:**
- Check Kong plugin configuration
- Verify IP is being detected correctly
- Check Kong logs for rate limit events

**Database issues:**
- Check PVC status: `kubectl get pvc -n api-platform`
- Verify volume mount: `kubectl describe pod <pod-name> -n api-platform`
- Check database file: `kubectl exec deployment/user-service -n api-platform -- ls -la /app/data/`
