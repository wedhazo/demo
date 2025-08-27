# Environment-Specific Configuration Setup

This project now supports environment-specific configurations for dev, test, prod, and k8s-local environments.

## 📁 Configuration Files Created

The following configuration files have been created in `src/main/resources/properties/`:

- `application-common.yaml` - Common settings shared across all environments
- `application-dev.yaml` - Development environment settings
- `application-test.yaml` - Test environment settings  
- `application-prod.yaml` - Production environment settings
- `application-k8s-local.yaml` - Kubernetes local environment settings

## 🔧 How to Run in Different Environments

### In Anypoint Studio

1. **Right-click your project** → Run As → Run Configurations...
2. **Select your Mule Application**
3. **Arguments tab** → VM arguments, add:
   ```
   -Dmule.env=dev
   ```
   (Replace `dev` with `test`, `prod`, or `k8s-local` as needed)

4. **Environment tab** → Add environment variable:
   - Name: `DB_PASSWORD`
   - Value: `beriha@123KB!` (or your actual password)

### From Command Line

```bash
# Development
mvn mule:run -Dmule.env=dev -DDB_PASSWORD=your_password

# Test
mvn mule:run -Dmule.env=test -DDB_PASSWORD=your_password

# Production  
mvn mule:run -Dmule.env=prod -DDB_PASSWORD=your_password
```

## 🚀 Kubernetes Deployment

A sample Kubernetes configuration has been created in `k8s-config.yaml`. To use it:

1. **Encode your password**:
   ```bash
   echo -n "your_password" | base64
   ```

2. **Update the secret** in `k8s-config.yaml` with the base64 encoded password

3. **Apply the configuration**:
   ```bash
   kubectl apply -f k8s-config.yaml
   ```

## 🔒 Security Notes

- Database passwords are **never stored in configuration files**
- Use environment variables (`${env:DB_PASSWORD}`) or runtime properties (`${db.password}`)
- For production, consider using Mule Secure Configuration Properties with encrypted values

## 📋 Environment Settings

| Environment | Database Host | SSL Mode | User |
|-------------|---------------|----------|------|
| dev | localhost | disable | postgres |
| test | test-db.internal | require | ft_reader |
| prod | prod-db.internal | require | ft_app |
| k8s-local | postgres.default.svc.cluster.local | require | postgres |

## ✅ Quick Verification

After setting up, you can verify the configuration works by:

1. Setting the environment (`-Dmule.env=dev`)
2. Setting the password (`DB_PASSWORD=your_password`)
3. Running the application
4. Testing the endpoint: `http://localhost:8081/kb`

The database connection should resolve the placeholders correctly and connect to the appropriate environment-specific database.
